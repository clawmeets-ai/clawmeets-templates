#!/usr/bin/env bash
#
# project.sh - Project workflow management for clawmeets
#
# Usage:
#   ./scripts/project.sh <command>
#
# Commands:
#   restart   Stop and restart server + agent processes (preserves data)
#   reset     Stop all processes, clear all directories
#   init      Initialize directory structure
#   server    Start server in background
#   register  Register all agents from config
#   agents    Start all agents in background
#   setup     Create project and upload setup files
#   send      Post initial request to coordinator
#   console   Watch changelog events with console output
#   run       Execute project workflow (setup + send + console)
#   clear     Clear project files (keep registrations)
#   status    Show process status
#   stop-all  Stop server and all agent processes
#   stop-agents  Stop all agent processes (keep server running)
#   listen    Start user notification listener (with TTS)
#   delete    Delete a project by ID (requires USER_TOKEN env var)
#
# Configuration (priority: env var > project.json > default):
#   DATA_DIR / data_dir       Base data directory (default: .clawmeets_data)
#
# Environment Variables:
#   CLAWMEETS_SERVER_URL            Full server URL (e.g. https://clawmeets.ai)
#   CLAWMEETS_BIND_SERVER_PORT      Port for local server startup (default: 4567)
#   CLAWMEETS_HAS_ADMIN_CREDENTIAL  "true" = admin create (default), "false" = self-register
#   CLAWMEETS_USERNAME              Override username from project.json
#   CLAWMEETS_USER_EMAIL            Override email from project.json
#   CLAWMEETS_USER_PASSWORD         Override password from project.json
#   CLAWMEETS_INVITATION_CODE       Invitation code for self-registration
#   PROJECT_CONFIG  Project config file (default: project.json)
#   DEBUG           Set to "true" for verbose debugging output
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration (from environment or defaults)
# ---------------------------------------------------------------------------

# These may be overridden by load_config() from project.json
PROJECT_CONFIG="${PROJECT_CONFIG:-project.json}"
DEBUG="${DEBUG:-false}"

# ---------------------------------------------------------------------------
# Load configuration: env var > project.json > hardcoded default
# ---------------------------------------------------------------------------

load_config() {
    # Check for jq silently - will be properly checked later when needed
    if ! command -v jq &>/dev/null; then
        # jq not available, apply hardcoded defaults
        DATA_DIR="${DATA_DIR:-.clawmeets_data}"
        BIND_PORT="${CLAWMEETS_BIND_SERVER_PORT:-4567}"
        SERVER_URL="${CLAWMEETS_SERVER_URL:-http://localhost:${BIND_PORT}}"
    else
        # Load from project.json
        if [[ -f "$PROJECT_CONFIG" ]]; then
            [[ -z "${DATA_DIR:-}" ]] && DATA_DIR=$(jq -r '.data_dir // empty' "$PROJECT_CONFIG")
            [[ -z "${CLAWMEETS_BIND_SERVER_PORT:-}" ]] && \
                BIND_PORT=$(jq -r '.bind_server_port // empty' "$PROJECT_CONFIG")
            [[ -z "${CLAWMEETS_SERVER_URL:-}" ]] && \
                SERVER_URL=$(jq -r '.server_url // empty' "$PROJECT_CONFIG")
        fi

        # Apply defaults; CLAWMEETS_* env vars take highest precedence
        DATA_DIR="${DATA_DIR:-.clawmeets_data}"
        BIND_PORT="${CLAWMEETS_BIND_SERVER_PORT:-${BIND_PORT:-4567}}"
        SERVER_URL="${CLAWMEETS_SERVER_URL:-${SERVER_URL:-http://localhost:${BIND_PORT}}}"
    fi

    # Expand ~ to $HOME (jq/env values aren't shell-expanded)
    DATA_DIR="${DATA_DIR/#\~/$HOME}"

    # Derive subdirectories from DATA_DIR
    BUS_DIR="${DATA_DIR}/server"
    AGENTS_DIR="${DATA_DIR}/agents"
    USERS_DIR="${DATA_DIR}/users"
}

# Load configuration
load_config

# Project root for PYTHONPATH (relative to script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH:-}"

# ---------------------------------------------------------------------------
# Colors (ANSI escape codes) - defined once for all functions
# ---------------------------------------------------------------------------

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ---------------------------------------------------------------------------
# Core Utility Functions
# ---------------------------------------------------------------------------

die() {
    echo "Error: $*" >&2
    exit 1
}

require_jq() {
    command -v jq &>/dev/null || die "jq is required but not installed. Install with: brew install jq"
}

# ---------------------------------------------------------------------------
# Display Helpers
# ---------------------------------------------------------------------------

# Print info message with blue prefix
info() {
    echo -e "${BLUE}[Info]${NC} $*"
}

# Print setup message
setup_msg() {
    echo -e "${BLUE}[Setup]${NC} $*"
}

# Print sync message
sync_msg() {
    echo -e "${CYAN}[Sync]${NC} $*"
}

# ---------------------------------------------------------------------------
# Authentication Helpers
# ---------------------------------------------------------------------------

# Get admin password from project config
get_admin_password() {
    if [[ -f "$PROJECT_CONFIG" ]]; then
        jq -r '.admin_password // "clawmeets"' "$PROJECT_CONFIG"
    else
        echo "clawmeets"
    fi
}

# Get admin JWT token (requires server running)
get_admin_token() {
    local admin_password
    admin_password=$(get_admin_password)
    python -m clawmeets.cli user login admin "$admin_password" -s "$SERVER_URL" 2>/dev/null
}

# Get a field from the project user config, with env var override
# Usage: get_project_user_field "username"|"password"|"email"
get_project_user_field() {
    local field="$1"

    # Env var overrides take precedence
    case "$field" in
        username)
            [[ -n "${CLAWMEETS_USERNAME:-}" ]] && { echo "$CLAWMEETS_USERNAME"; return; }
            ;;
        password)
            [[ -n "${CLAWMEETS_USER_PASSWORD:-}" ]] && { echo "$CLAWMEETS_USER_PASSWORD"; return; }
            ;;
        email)
            [[ -n "${CLAWMEETS_USER_EMAIL:-}" ]] && { echo "$CLAWMEETS_USER_EMAIL"; return; }
            ;;
    esac

    # Read from project.json .user object
    if [[ -f "$PROJECT_CONFIG" ]] && command -v jq &>/dev/null; then
        local val
        # New format: .user is an object with username/password/email
        val=$(jq -r --arg f "$field" 'if (.user | type) == "object" then .user[$f] // empty else empty end' "$PROJECT_CONFIG" 2>/dev/null)
        if [[ -n "$val" ]]; then
            echo "$val"
            return
        fi
        # Backward compat: .user is a string (old format) → return as username
        if [[ "$field" == "username" ]]; then
            val=$(jq -r 'if (.user | type) == "string" then .user else empty end' "$PROJECT_CONFIG" 2>/dev/null)
            [[ -n "$val" ]] && { echo "$val"; return; }
        fi
        # Backward compat: check old .users[] array
        if [[ "$field" == "password" || "$field" == "email" ]]; then
            local username
            username=$(get_project_user_field "username")
            if [[ -n "$username" ]]; then
                val=$(jq -r --arg u "$username" --arg f "$field" '.users[]? | select(.username == $u) | .[$f] // empty' "$PROJECT_CONFIG" 2>/dev/null)
                [[ -n "$val" ]] && { echo "$val"; return; }
            fi
        fi
    fi
}

# Get user password from project config
get_user_password() {
    local user_name="$1"
    local password
    password=$(get_project_user_field "password")
    if [[ -z "$password" ]]; then
        get_admin_password
    else
        echo "$password"
    fi
}

# Check if server is running
require_server() {
    curl -s "${SERVER_URL}/agents" >/dev/null 2>&1 || \
        die "Server not running. Run 'project.sh server' first."
}

# ---------------------------------------------------------------------------
# Process Management
# ---------------------------------------------------------------------------

pid_is_alive() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

stop_process() {
    local pid_file="$1"
    local label="$2"

    [[ -f "$pid_file" ]] || return 0

    local pid
    pid=$(cat "$pid_file")

    if pid_is_alive "$pid"; then
        kill -TERM "$pid" 2>/dev/null || true
        # Wait briefly for process to terminate
        local i
        for i in {1..10}; do
            sleep 0.2
            pid_is_alive "$pid" || break
        done
        echo "Stopped $label (PID $pid)"
    fi

    rm -f "$pid_file"
}

# ---------------------------------------------------------------------------
# Agent Directory Helpers
# ---------------------------------------------------------------------------

# Build the prefixed agent name: {username}-{agent_name}
# Username serves as a namespace (hyphens disallowed in usernames).
prefixed_agent_name() {
    local username="$1"
    local agent_name="$2"
    local prefix="${username}-"
    if [[ "$agent_name" == "${prefix}"* ]]; then
        echo "$agent_name"
    else
        echo "${prefix}${agent_name}"
    fi
}

get_credential_path() {
    local agent_name="$1"
    # Find the agent directory matching {name}-{agent_id}
    for dir in "$AGENTS_DIR"/"${agent_name}"-*/; do
        [[ -d "$dir" ]] || continue
        local cred="${dir}credential.json"
        if [[ -f "$cred" ]]; then
            echo "$cred"
            return
        fi
    done
    # Fallback for registration (directory doesn't exist yet)
    echo ""
}

get_agent_dir() {
    local agent_name="$1"
    # Find the agent directory matching {name}-{agent_id}
    for dir in "$AGENTS_DIR"/"${agent_name}"-*/; do
        [[ -d "$dir" ]] || continue
        if [[ -f "${dir}credential.json" ]]; then
            echo "$dir"
            return
        fi
    done
    echo ""
}

load_agent_id() {
    local agent_name="$1"
    local cred_path
    cred_path=$(get_credential_path "$agent_name")

    [[ -n "$cred_path" && -f "$cred_path" ]] || die "Credentials not found for agent '$agent_name'. Run 'project.sh register' first."

    jq -r '.agent_id' "$cred_path"
}

# ---------------------------------------------------------------------------
# Project Helpers
# ---------------------------------------------------------------------------

# Create project and return project_id
create_project() {
    local project_name="$1"
    local coordinator_id="$2"
    local request="$3"
    local user_name="$4"
    local user_token="$5"
    local user_id="$6"
    local agent_pool="$7"

    # Build agent_pool flag if set
    local pool_flag=""
    if [[ -n "$agent_pool" ]]; then
        pool_flag="--agent-pool $agent_pool"
    fi

    local project_json
    if [[ -n "$user_token" && -n "$user_id" ]]; then
        project_json=$(python -m clawmeets.cli project create "$project_name" "$coordinator_id" "$request" -s "$SERVER_URL" --created-by "$user_id" --token "$user_token" $pool_flag)
    elif [[ -n "$user_token" ]]; then
        project_json=$(python -m clawmeets.cli project create "$project_name" "$coordinator_id" "$request" -s "$SERVER_URL" --token "$user_token" $pool_flag)
    else
        project_json=$(python -m clawmeets.cli project create "$project_name" "$coordinator_id" "$request" -s "$SERVER_URL" $pool_flag)
    fi
    echo "$project_json" | jq -r '.id'
}

# Upload files from setup folder to shared-context room
upload_setup_files() {
    local project_id="$1"
    local room_name="$2"
    local setup_folder="$3"
    local user_token="$4"

    if [[ ! -d "$setup_folder" ]]; then
        return 0
    fi

    if [[ -z "$user_token" ]]; then
        echo -e "${YELLOW}[Warning]${NC} Cannot upload setup files without user authentication"
        return 0
    fi

    for filepath in "$setup_folder"/*; do
        [[ -f "$filepath" ]] || continue
        local filename
        filename=$(basename "$filepath")
        curl -s -X PUT "${SERVER_URL}/projects/${project_id}/chatrooms/${room_name}/user-files/${filename}" \
            -H "Authorization: Bearer ${user_token}" \
            --data-binary "@${filepath}" >/dev/null
        setup_msg "Uploaded file: ${CYAN}$filename${NC}"
    done
}

# Post initial request to user-communication room
post_initial_request() {
    local project_id="$1"
    local room_name="$2"
    local user_name="$3"
    local coordinator_name="$4"
    local request="$5"
    local user_token="$6"

    local user_request="@${coordinator_name} ${request}"

    if [[ -n "$user_token" ]]; then
        curl -s -X POST "${SERVER_URL}/projects/${project_id}/chatrooms/${room_name}/user-message" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${user_token}" \
            -d "$(jq -n --arg content "$user_request" '{content: $content}')" >/dev/null
        setup_msg "Posted initial request (authenticated as ${user_name}, addressing @${coordinator_name})"
    else
        python -m clawmeets.cli message send "$project_id" "$room_name" "$user_name" "$user_request" -s "$SERVER_URL" >/dev/null
        setup_msg "Posted initial request (as ${user_name})"
    fi
}


# ---------------------------------------------------------------------------
# Summary Display
# ---------------------------------------------------------------------------

show_project_summary() {
    local project_id="$1"
    local all_room_names="$2"

    echo ""
    echo -e "${BOLD}--- Summary ---${NC}"

    # Count total messages
    local total_messages=0
    local total_files=0

    while IFS= read -r room_name; do
        [[ -n "$room_name" ]] || continue

        local msg_count file_count
        msg_count=$(curl -s "${SERVER_URL}/projects/${project_id}/chatrooms/${room_name}/messages" 2>/dev/null | jq 'length' || echo 0)
        file_count=$(curl -s "${SERVER_URL}/projects/${project_id}/chatrooms/${room_name}/files" 2>/dev/null | jq 'length' || echo 0)

        total_messages=$((total_messages + msg_count))
        total_files=$((total_files + file_count))
    done <<< "$all_room_names"

    echo -e "Messages exchanged: ${GREEN}$total_messages${NC}"
    echo -e "Files created: ${CYAN}$total_files${NC}"

    # List final files by chatroom
    if [[ $total_files -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}Files by Chatroom:${NC}"

        while IFS= read -r room_name; do
            [[ -n "$room_name" ]] || continue

            local room_files room_file_count
            room_files=$(curl -s "${SERVER_URL}/projects/${project_id}/chatrooms/${room_name}/files" 2>/dev/null || echo "[]")
            room_file_count=$(echo "$room_files" | jq 'length')

            if [[ $room_file_count -gt 0 ]]; then
                echo -e "  ${YELLOW}#${room_name}${NC}:"
                echo "$room_files" | jq -r '.[]' 2>/dev/null | while read -r fname; do
                    [[ -n "$fname" ]] || continue
                    [[ "$fname" != .* ]] || continue
                    echo "    - $fname"
                done
            fi
        done <<< "$all_room_names"
    fi

    show_cost_summary
}

show_cost_summary() {
    echo ""
    echo -e "${BOLD}Cost Summary:${NC}"

    local total_cost=0
    local total_invocations=0
    local found_cost=false

    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_work_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_work_dir" ]] || continue

            local projects_dir="${agent_work_dir}projects"
            if [[ -d "$projects_dir" ]]; then
                for cost_file in "$projects_dir"/*/cost.json; do
                    [[ -f "$cost_file" ]] || continue
                    found_cost=true
                    local name cost invocations input_tokens output_tokens project_id
                    name=$(jq -r '.agent_name // "unknown"' "$cost_file")
                    cost=$(jq -r '.total_cost_usd // 0' "$cost_file")
                    invocations=$(jq -r '.invocation_count // 0' "$cost_file")
                    input_tokens=$(jq -r '.total_input_tokens // 0' "$cost_file")
                    output_tokens=$(jq -r '.total_output_tokens // 0' "$cost_file")
                    project_id=$(basename "$(dirname "$cost_file")")

                    echo -e "  ${GREEN}$name${NC} [${project_id:0:8}...]: \$${cost} (${invocations} invocations, ${input_tokens} in / ${output_tokens} out tokens)"

                    total_cost=$(echo "$total_cost + $cost" | bc -l 2>/dev/null || echo "$total_cost")
                    total_invocations=$((total_invocations + invocations))
                done
            fi
        done
    fi

    if [[ "$found_cost" == "true" ]]; then
        local formatted_cost
        formatted_cost=$(printf "%.4f" "$total_cost" 2>/dev/null || echo "$total_cost")
        echo ""
        echo -e "  ${YELLOW}${BOLD}Total: \$${formatted_cost}${NC} (${total_invocations} total invocations)"
    else
        echo -e "  ${CYAN}(no cost data available)${NC}"
    fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_reset() {
    echo "=== Reset ==="

    # Stop server
    local server_pid="${BUS_DIR}/server.pid"
    stop_process "$server_pid" "server"

    # Stop listener
    local listener_pid="${BUS_DIR}/listener.pid"
    stop_process "$listener_pid" "listener"

    # Stop all agents
    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_dir" ]] || continue
            local agent_name
            agent_name=$(basename "$agent_dir")
            local agent_pid="${agent_dir}agent.pid"
            stop_process "$agent_pid" "agent $agent_name"
        done
    fi

    # Remove local bare git repo if git_url is a relative path
    if [[ -n "$PROJECT_CONFIG" && -f "$PROJECT_CONFIG" ]]; then
        local git_url
        git_url=$(jq -r '.git_url // empty' "$PROJECT_CONFIG")
        if [[ -n "$git_url" && "$git_url" != /* && "$git_url" != http* && "$git_url" != git@* ]]; then
            local config_dir resolved_path
            config_dir=$(dirname "$PROJECT_CONFIG")
            resolved_path="${config_dir}/${git_url}"
            if [[ -d "$resolved_path" && -f "$resolved_path/HEAD" ]]; then
                rm -rf "$resolved_path"
                echo "Removed local bare repo ${git_url}"
            fi
        fi
    fi

    # Remove data directory
    if [[ -d "$DATA_DIR" ]]; then
        rm -rf "$DATA_DIR"
        echo "Removed $DATA_DIR"
    fi

    echo "Reset complete."
}

cmd_stop_agents() {
    echo "=== Stop Agents ==="

    if [[ -d "$AGENTS_DIR" ]]; then
        local stopped=0
        for agent_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_dir" ]] || continue
            local agent_name
            agent_name=$(basename "$agent_dir")
            local agent_pid="${agent_dir}agent.pid"
            if [[ -f "$agent_pid" ]]; then
                stop_process "$agent_pid" "agent $agent_name"
                stopped=$((stopped + 1))
            fi
        done

        if [[ $stopped -eq 0 ]]; then
            echo "No agents were running."
        else
            echo "Stopped $stopped agent(s)."
        fi
    else
        echo "Agents directory not found."
    fi
}

cmd_init() {
    require_jq
    echo "=== Initialize ==="

    mkdir -p "${BUS_DIR}/agents"
    mkdir -p "${BUS_DIR}/projects"
    mkdir -p "$AGENTS_DIR"

    local admin_password
    admin_password=$(get_admin_password)

    python -m clawmeets.cli admin init-passwd "$admin_password" \
        --data-dir "$BUS_DIR"

    # Reserve usernames listed in project.json (written directly to passwd file, no server needed)
    if [[ -n "$PROJECT_CONFIG" && -f "$PROJECT_CONFIG" ]]; then
        local reserved project_user
        reserved=$(jq -c '.reserved_usernames // []' "$PROJECT_CONFIG" 2>/dev/null)
        project_user=$(get_project_user_field "username")
        if [[ "$reserved" != "[]" && -n "$reserved" ]]; then
            python3 -c "
import json, uuid
from datetime import datetime, timezone
from pathlib import Path

passwd_file = Path('$BUS_DIR') / 'passwd'
data = json.loads(passwd_file.read_text()) if passwd_file.exists() else {'users': {}}
existing = {u['username'] for u in data['users'].values()}
project_user = '$project_user'
reserved = json.loads('$reserved')
count = 0
for name in reserved:
    if name not in existing and name != project_user:
        data['users'][str(uuid.uuid4())] = {
            'username': name,
            'role': 'user',
            'password_hash': '!reserved',
            'created_at': datetime.now(timezone.utc).isoformat(),
            'email': f'{name}@clawmeets.ai',
            'email_verified': False,
        }
        count += 1
if count:
    passwd_file.write_text(json.dumps(data, indent=2))
    print(f'Reserved {count} username(s)')
"
        fi
    fi

    # Create local bare git repo if git_url is a relative path that doesn't exist yet
    if [[ -n "$PROJECT_CONFIG" && -f "$PROJECT_CONFIG" ]]; then
        local git_url
        git_url=$(jq -r '.git_url // empty' "$PROJECT_CONFIG")
        if [[ -n "$git_url" && "$git_url" != /* && "$git_url" != http* && "$git_url" != git@* ]]; then
            local config_dir resolved_path
            config_dir=$(dirname "$PROJECT_CONFIG")
            resolved_path="${config_dir}/${git_url}"
            if [[ ! -d "$resolved_path" ]]; then
                mkdir -p "$resolved_path"
                git init --bare "$resolved_path" > /dev/null 2>&1
                # Seed with an initial commit so branches have a valid ref
                local tmp_clone
                tmp_clone=$(mktemp -d)
                git clone "$resolved_path" "$tmp_clone/repo" > /dev/null 2>&1
                (cd "$tmp_clone/repo" && touch .gitignore && git add .gitignore && git commit -m "Initial commit" > /dev/null 2>&1 && git push origin HEAD > /dev/null 2>&1)
                rm -rf "$tmp_clone"
                echo "Created local bare git repo at ${git_url}"
            fi
        fi
    fi

    echo "Initialized ${DATA_DIR}/ (server: ${BUS_DIR}, agents: ${AGENTS_DIR})"
}

cmd_users() {
    require_jq
    echo "=== Create User ==="

    require_server

    local username password email
    username=$(get_project_user_field "username")
    password=$(get_project_user_field "password")
    email=$(get_project_user_field "email")

    [[ -n "$username" ]] || die "No username configured. Set CLAWMEETS_USERNAME or configure .user in project.json."
    [[ -n "$password" ]] || password=$(get_admin_password)

    # Auto-detect: env var > project.json admin_password > default (self-register)
    local has_admin
    if [[ -n "${CLAWMEETS_HAS_ADMIN_CREDENTIAL:-}" ]]; then
        has_admin="$CLAWMEETS_HAS_ADMIN_CREDENTIAL"
    elif [[ -f "$PROJECT_CONFIG" ]] && command -v jq &>/dev/null; then
        local admin_pw_in_config
        admin_pw_in_config=$(jq -r '.admin_password // empty' "$PROJECT_CONFIG")
        if [[ -n "$admin_pw_in_config" ]]; then
            has_admin="true"
        else
            has_admin="false"
        fi
    else
        has_admin="true"
    fi

    if [[ "$has_admin" == "true" ]]; then
        # Admin-based creation (pre-verified, no email needed)
        local admin_token
        admin_token=$(get_admin_token) || \
            die "Failed to login as admin. Check password in project config."

        local email_flag=""
        if [[ -n "$email" ]]; then
            email_flag="--email $email"
        fi

        python -m clawmeets.cli user create "$username" "$password" \
            --role user --token "$admin_token" \
            -s "$SERVER_URL" --agent-dir "$AGENTS_DIR" $email_flag 2>/dev/null || \
            echo "User '$username' already exists (skipping)"
    else
        # Self-registration (no admin token needed)
        [[ -n "$email" ]] || die "Email required for self-registration. Set CLAWMEETS_USER_EMAIL or configure .user.email in project.json."
        local invitation_code="${CLAWMEETS_INVITATION_CODE:-}"
        [[ -n "$invitation_code" ]] || die "Invitation code required for self-registration. Set CLAWMEETS_INVITATION_CODE."

        python -m clawmeets.cli user register "$username" "$password" "$email" \
            --invitation-code "$invitation_code" \
            -s "$SERVER_URL" --agent-dir "$AGENTS_DIR" 2>/dev/null || \
            echo "User '$username' already exists (skipping)"
    fi

    echo "User created (with assistant agent)"
}

cmd_server() {
    echo "=== Start Server ==="

    local pid_file="${BUS_DIR}/server.pid"
    local stdout_log="${BUS_DIR}/stdout.log"
    local stderr_log="${BUS_DIR}/stderr.log"

    # Check if already running
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if pid_is_alive "$pid"; then
            echo "Server already running (PID $pid)"
            return 0
        fi
    fi

    # Read batch_timeout from project.json (default: 600 seconds = 10 minutes)
    local batch_timeout=""
    if [[ -n "$PROJECT_CONFIG" && -f "$PROJECT_CONFIG" ]]; then
        batch_timeout=$(jq -r '.batch_timeout // empty' "$PROJECT_CONFIG")
    fi

    # Start server in background
    local server_args=(
        python -m clawmeets.cli server start
        --port "$BIND_PORT"
        --data-dir "$BUS_DIR"
    )
    if [[ -n "$batch_timeout" ]]; then
        server_args+=(--batch-timeout "$batch_timeout")
    fi
    "${server_args[@]}" >"$stdout_log" 2>"$stderr_log" &

    local pid=$!
    echo "$pid" > "$pid_file"
    echo "Started server on port $BIND_PORT (PID $pid)"
    echo "Logs: $stdout_log, $stderr_log"

    sleep 1
}

cmd_register() {
    require_jq
    echo "=== Register Worker Agents ==="

    require_server

    # Use user token so agents are registered under the project user
    local user_name
    user_name=$(get_project_user_field "username")
    [[ -n "$user_name" ]] || die "No user configured. Set CLAWMEETS_USERNAME or configure .user in project.json."

    local user_password
    user_password=$(get_project_user_field "password")
    [[ -n "$user_password" ]] || user_password=$(get_admin_password)

    local user_token
    user_token=$(python -m clawmeets.cli user login "$user_name" "$user_password" -s "$SERVER_URL" 2>/dev/null) || \
        die "Failed to login as user '$user_name'. Ensure user is created first (run 'users' command)."

    local agents_json=""
    if [[ -f "$PROJECT_CONFIG" ]]; then
        agents_json=$(jq -c '.agents // []' "$PROJECT_CONFIG")
    fi
    if [[ -z "$agents_json" || "$agents_json" == "[]" || "$agents_json" == "null" ]]; then
        echo "No worker agents to register."
        return 0
    fi

    echo "$agents_json" | jq -c '.[]' | while read -r agent; do
        local name desc caps cred_path knowledge_dir prefixed_name use_chrome
        name=$(echo "$agent" | jq -r '.name')
        desc=$(echo "$agent" | jq -r '.description // "Worker agent"')
        caps=$(echo "$agent" | jq -r '(.capabilities // []) | join(",")')
        knowledge_dir=$(echo "$agent" | jq -r '.knowledge_dir // empty')
        use_chrome=$(echo "$agent" | jq -r '.chrome // false')
        # Server will prefix with username, so look up with prefixed name
        prefixed_name=$(prefixed_agent_name "$user_name" "$name")
        cred_path=$(get_credential_path "$prefixed_name")

        local discoverable
        discoverable=$(echo "$agent" | jq -r '.discoverable // false')

        local reg_cmd=(
            python -m clawmeets.cli agent register "$name" "$desc"
            --token "$user_token"
            -s "$SERVER_URL"
            --agent-dir "$AGENTS_DIR"
        )
        if [[ "$discoverable" == "true" ]]; then
            reg_cmd+=(--discoverable)
        else
            reg_cmd+=(--no-discoverable)
        fi
        if [[ -n "$caps" ]]; then
            reg_cmd+=(--capabilities "$caps")
        fi

        "${reg_cmd[@]}"

        local agent_dir
        agent_dir=$(get_agent_dir "$prefixed_name")
        if [[ -n "$agent_dir" ]]; then
            # Build config.json with all agent-specific settings
            local config="{}"
            if [[ -n "$knowledge_dir" ]]; then
                config=$(echo "$config" | jq --arg v "$knowledge_dir" '.knowledge_dir = $v')
            fi
            if [[ "$use_chrome" == "true" ]]; then
                config=$(echo "$config" | jq '.use_chrome = true')
            fi
            echo "$config" > "${agent_dir}config.json"
        fi

        if [[ -n "$knowledge_dir" ]]; then
            echo "Registered worker agent '$prefixed_name' (knowledge_dir: $knowledge_dir)"
        else
            echo "Registered worker agent '$prefixed_name'"
        fi
    done
}

cmd_agents() {
    require_jq
    echo "=== Start Agents ==="

    if [[ ! -d "$AGENTS_DIR" ]]; then
        die "Agents directory not found: $AGENTS_DIR"
    fi

    # Build agent name list from project.json:
    # - Workers: {username}-{agent_name} (prefixed with registering user's username)
    # - Assistant: {username}-assistant
    local agent_names=()
    local project_user=""
    project_user=$(get_project_user_field "username")
    if [[ -f "$PROJECT_CONFIG" ]]; then
        while IFS= read -r name; do
            if [[ -n "$name" && -n "$project_user" ]]; then
                agent_names+=("$(prefixed_agent_name "$project_user" "$name")")
            elif [[ -n "$name" ]]; then
                agent_names+=("$name")
            fi
        done < <(jq -r '.agents[]?.name // empty' "$PROJECT_CONFIG")
    fi
    # Add the user's assistant agent
    if [[ -n "$project_user" ]]; then
        agent_names+=("${project_user}-assistant")
    fi

    if [[ ${#agent_names[@]} -eq 0 ]]; then
        echo "No agents found in project config."
        return 0
    fi

    # Read git config and claude_plugin_dir from project.json (shared across all agents)
    local git_url="" git_ignored_folder="" claude_plugin_dir=""
    if [[ -n "$PROJECT_CONFIG" && -f "$PROJECT_CONFIG" ]]; then
        git_url=$(jq -r '.git_url // empty' "$PROJECT_CONFIG")
        git_ignored_folder=$(jq -r '.git_ignored_folder // empty' "$PROJECT_CONFIG")
        claude_plugin_dir=$(jq -r '.claude_plugin_dir // empty' "$PROJECT_CONFIG")
        if [[ -n "$git_url" && "$git_url" != /* && "$git_url" != http* && "$git_url" != git* ]]; then
            local config_dir
            config_dir=$(dirname "$PROJECT_CONFIG")
            git_url=$(cd "$config_dir" && cd "$git_url" && pwd)
        fi
        # Resolve relative claude_plugin_dir paths
        if [[ -n "$claude_plugin_dir" && "$claude_plugin_dir" != /* ]]; then
            local config_dir
            config_dir=$(dirname "$PROJECT_CONFIG")
            claude_plugin_dir=$(cd "$config_dir" && cd "$claude_plugin_dir" && pwd)
        fi
    fi

    local started=0
    for name in "${agent_names[@]}"; do
        local agent_dir
        agent_dir=$(get_agent_dir "$name")
        if [[ -z "$agent_dir" || ! -d "$agent_dir" ]]; then
            echo "Agent '$name' not found in $AGENTS_DIR, skipping."
            continue
        fi

        local pid_file="${agent_dir}agent.pid"

        # Check if already running
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file")
            if pid_is_alive "$pid"; then
                echo "Agent '$name' already running (PID $pid)"
                continue
            fi
        fi

        # Read agent-specific config
        local knowledge_dir="" use_chrome=""
        if [[ -f "${agent_dir}config.json" ]]; then
            knowledge_dir=$(jq -r '.knowledge_dir // empty' "${agent_dir}config.json")
            use_chrome=$(jq -r '.use_chrome // empty' "${agent_dir}config.json")
        fi

        local cmd_args=(
            python -m clawmeets.cli agent run
            --server "$SERVER_URL"
            --agent-dir "$agent_dir"
        )
        if [[ -n "$knowledge_dir" ]]; then
            cmd_args+=(--knowledge-dir "$knowledge_dir")
        fi
        if [[ "$use_chrome" == "true" ]]; then
            cmd_args+=(--chrome)
        fi
        if [[ -n "$git_url" ]]; then
            cmd_args+=(--git-url "$git_url")
        fi
        if [[ -n "$git_ignored_folder" ]]; then
            cmd_args+=(--git-ignored-folder "$git_ignored_folder")
        fi
        if [[ -n "$claude_plugin_dir" ]]; then
            cmd_args+=(--claude-plugin-dir "$claude_plugin_dir")
        fi

        local stdout_log="${agent_dir}stdout.log"
        local stderr_log="${agent_dir}stderr.log"

        "${cmd_args[@]}" >"$stdout_log" 2>"$stderr_log" &

        local pid=$!
        echo "$pid" > "$pid_file"
        if [[ -n "$knowledge_dir" ]]; then
            echo "Started agent '$name' (PID $pid, knowledge_dir: $knowledge_dir)"
        else
            echo "Started agent '$name' (PID $pid)"
        fi
        echo "  Logs: $stdout_log, $stderr_log"
        started=$((started + 1))
    done

    if [[ $started -eq 0 ]]; then
        echo "No new agents started (all already running or no agents found)."
    fi

    sleep 1
}

cmd_verify_agents() {
    require_jq
    echo "=== Verify Agents ==="

    require_server

    local admin_token
    admin_token=$(get_admin_token) || \
        die "Failed to login as admin. Check password in project config."

    # Read agent names from project.json
    local agents_json=""
    if [[ -f "$PROJECT_CONFIG" ]]; then
        agents_json=$(jq -c '.agents // []' "$PROJECT_CONFIG")
    fi

    if [[ -z "$agents_json" || "$agents_json" == "[]" || "$agents_json" == "null" ]]; then
        echo "No worker agents to verify."
        return 0
    fi

    local project_user
    project_user=$(get_project_user_field "username")

    echo "$agents_json" | jq -r '.[].name' | while read -r name; do
        [[ -n "$name" ]] || continue

        local prefixed_name
        prefixed_name=$(prefixed_agent_name "$project_user" "$name")

        local agent_id
        agent_id=$(load_agent_id "$prefixed_name" 2>/dev/null) || {
            echo "Agent '$prefixed_name' not registered, skipping."
            continue
        }

        python -m clawmeets.cli admin verify-agent "$agent_id" \
            --token "$admin_token" -s "$SERVER_URL" >/dev/null 2>&1 && \
            echo "Verified agent '$prefixed_name' ($agent_id)" || \
            echo "Failed to verify agent '$prefixed_name' ($agent_id)"
    done
}

cmd_listen() {
    local mode="${1:-foreground}"

    require_jq

    # Check server (soft fail for background mode)
    if ! curl -s "${SERVER_URL}/agents" >/dev/null 2>&1; then
        if [[ "$mode" == "background" ]]; then
            echo "Server not running, skipping listener."
            return 0
        else
            die "Server not running. Run 'project.sh server' first."
        fi
    fi

    if [[ ! -f "$PROJECT_CONFIG" ]]; then
        if [[ "$mode" == "background" ]]; then
            echo "Project config not found, skipping listener."
            return 0
        else
            die "Project config not found: $PROJECT_CONFIG"
        fi
    fi

    local user_name user_password
    user_name=$(get_project_user_field "username")
    [[ -n "$user_name" ]] || user_name="admin"
    user_password=$(get_project_user_field "password")
    [[ -n "$user_password" ]] || user_password=$(get_admin_password)

    # Determine notification script
    local notify_script="${NOTIFY_SCRIPT:-${SCRIPT_DIR}/notify.py}"
    if [[ ! -f "$notify_script" ]]; then
        if [[ "$mode" == "background" ]]; then
            echo "No notification script found, skipping listener."
            return 0
        else
            die "No notification script found. Set NOTIFY_SCRIPT or ensure scripts/notify.py exists."
        fi
    fi

    if [[ ! -x "$notify_script" ]]; then
        if [[ "$mode" == "background" ]]; then
            echo "Notification script not executable, skipping listener."
            return 0
        else
            die "Notification script not executable: $notify_script"
        fi
    fi

    if [[ "$mode" == "background" ]]; then
        echo "=== Start User Notification Listener (background) ==="

        local pid_file="${BUS_DIR}/listener.pid"
        local log_file="${BUS_DIR}/listener.log"

        python -m clawmeets.cli user listen "$user_name" "$user_password" "$notify_script" \
            -s "$SERVER_URL" \
            --user-dir "$USERS_DIR" \
            --log-level "${LOG_LEVEL:-warning}" \
            >"$log_file" 2>&1 &

        local pid=$!
        echo "$pid" > "$pid_file"
        echo "Started notification listener (PID $pid)"
        echo "Log: $log_file"
    else
        echo "=== Start User Notification Listener ==="
        echo "User: $user_name"
        echo "Script: $notify_script"
        echo ""
        echo "Listening for notifications... (Ctrl+C to stop)"
        echo ""

        python -m clawmeets.cli user listen "$user_name" "$user_password" "$notify_script" \
            -s "$SERVER_URL" \
            --user-dir "$USERS_DIR" \
            --log-level "${LOG_LEVEL:-warning}"
    fi
}

cmd_setup() {
    require_jq

    echo -e "${BOLD}=== Setup Project ===${NC}"
    echo ""

    [[ -f "$PROJECT_CONFIG" ]] || die "Project config not found: $PROJECT_CONFIG"

    # Parse project config
    local project_name user_name coordinator_name
    project_name=$(jq -r '.name' "$PROJECT_CONFIG")
    user_name=$(get_project_user_field "username")
    [[ -n "$user_name" ]] || user_name="admin"
    coordinator_name=$(jq -r '.coordinator // null' "$PROJECT_CONFIG")
    if [[ "$coordinator_name" == "null" || -z "$coordinator_name" ]]; then
        coordinator_name="${user_name}-assistant"
    fi

    # Check if shared_context is configured
    local setup_folder_raw config_dir setup_folder
    setup_folder_raw=$(jq -r '.shared_context // empty' "$PROJECT_CONFIG")
    config_dir=$(dirname "$PROJECT_CONFIG")

    if [[ -z "$setup_folder_raw" ]]; then
        echo -e "${YELLOW}[Info]${NC} No shared_context configured in project.json"
        echo ""
        echo "To create a project manually, use:"
        echo "  python -m clawmeets.cli project create \"$project_name\" <coordinator_id> \"<request>\" \\"
        echo "    -s \"$SERVER_URL\" --token <user_token>"
        echo ""
        echo "To upload setup files:"
        echo "  curl -X PUT \"${SERVER_URL}/projects/<project_id>/chatrooms/shared-context/user-files/<filename>\" \\"
        echo "    -H \"Authorization: Bearer <user_token>\" \\"
        echo "    --data-binary @<filepath>"
        echo ""
        return 0
    fi

    if [[ "$setup_folder_raw" == /* ]]; then
        setup_folder="$setup_folder_raw"
    else
        setup_folder="$config_dir/$setup_folder_raw"
    fi

    # Read request (needed for project creation)
    local request
    request=$(jq -r '.request // ""' "$PROJECT_CONFIG")

    # Get coordinator ID
    local coordinator_id
    coordinator_id=$(load_agent_id "$coordinator_name")

    # Get user credentials
    local user_password
    user_password=$(get_project_user_field "password")
    [[ -n "$user_password" ]] || user_password=$(get_admin_password)

    # Get user JWT token and ID
    local user_token user_id
    user_token=$(python -m clawmeets.cli user login "$user_name" "$user_password" -s "$SERVER_URL" 2>/dev/null || echo "")
    if [[ -n "$user_token" ]]; then
        user_id=$(curl -s "${SERVER_URL}/auth/user/me" \
            -H "Authorization: Bearer ${user_token}" | jq -r '.id // empty')
    fi

    # Read agent_pool from project.json (default: "owned")
    local agent_pool
    agent_pool=$(jq -r '.agent_pool // "owned"' "$PROJECT_CONFIG")

    setup_msg "Creating project '${BOLD}$project_name${NC}' (as ${user_name}, agent_pool=${agent_pool})..."

    # Create project
    local project_id
    project_id=$(create_project "$project_name" "$coordinator_id" "$request" "$user_name" "$user_token" "$user_id" "$agent_pool")
    setup_msg "Project ID: ${project_id:0:8}..."

    # Save project ID for later commands
    echo "$project_id" > ".current_project"
    setup_msg "Saved project ID to .current_project"

    # Get chatroom names
    local shared_context_room_name
    shared_context_room_name=$(curl -s "${SERVER_URL}/projects/${project_id}/chatrooms" | jq -r '.[] | select(.name | startswith("shared-context")) | .name')
    [[ -n "$shared_context_room_name" ]] || die "No shared-context chatroom found"

    # Upload setup files
    upload_setup_files "$project_id" "$shared_context_room_name" "$setup_folder" "$user_token"

    echo ""
    echo -e "${GREEN}Project setup complete.${NC}"
    echo "Project ID: $project_id"
}

cmd_send() {
    require_jq

    echo -e "${BOLD}=== Send Initial Request ===${NC}"
    echo ""

    [[ -f "$PROJECT_CONFIG" ]] || die "Project config not found: $PROJECT_CONFIG"

    # Parse project config
    local user_name coordinator_name request
    user_name=$(get_project_user_field "username")
    [[ -n "$user_name" ]] || user_name="admin"
    coordinator_name=$(jq -r '.coordinator // null' "$PROJECT_CONFIG")
    if [[ "$coordinator_name" == "null" || -z "$coordinator_name" ]]; then
        coordinator_name="${user_name}-assistant"
    fi
    request=$(jq -r '.request // empty' "$PROJECT_CONFIG")

    # Check if request is configured
    if [[ -z "$request" ]]; then
        echo -e "${YELLOW}[Info]${NC} No initial request configured in project.json"
        echo ""
        echo "To send a request manually, use:"
        echo "  curl -X POST \"${SERVER_URL}/projects/<project_id>/chatrooms/user-communication/user-message\" \\"
        echo "    -H \"Content-Type: application/json\" \\"
        echo "    -H \"Authorization: Bearer <user_token>\" \\"
        echo "    -d '{\"content\": \"@${coordinator_name} <your request here>\"}'"
        echo ""
        return 0
    fi

    # Load project ID from saved state
    local project_id
    if [[ -f ".current_project" ]]; then
        project_id=$(cat ".current_project")
    else
        die "No current project. Run 'project.sh setup' first."
    fi

    # Get user credentials
    local user_password
    user_password=$(get_project_user_field "password")
    [[ -n "$user_password" ]] || user_password=$(get_admin_password)

    # Get user JWT token
    local user_token
    user_token=$(python -m clawmeets.cli user login "$user_name" "$user_password" -s "$SERVER_URL" 2>/dev/null || echo "")

    # Get user-communication chatroom name
    local user_comm_room_name
    user_comm_room_name=$(curl -s "${SERVER_URL}/projects/${project_id}/chatrooms" | jq -r '.[] | select(.name | startswith("user-communication")) | .name')
    [[ -n "$user_comm_room_name" ]] || die "No user-communication chatroom found"

    # Post initial request
    post_initial_request "$project_id" "$user_comm_room_name" "$user_name" "$coordinator_name" "$request" "$user_token"

    echo ""
    echo -e "${GREEN}Initial request sent.${NC}"
}

cmd_console() {
    require_jq

    [[ -f "$PROJECT_CONFIG" ]] || die "Project config not found: $PROJECT_CONFIG"

    local user_name user_password notify_script
    user_name=$(get_project_user_field "username")
    [[ -n "$user_name" ]] || user_name="admin"
    user_password=$(get_project_user_field "password")
    [[ -n "$user_password" ]] || user_password=$(get_admin_password)
    notify_script=$(jq -r '.notify_script // empty' "$PROJECT_CONFIG")

    echo "Listening for changelog events... (Ctrl+C to stop)"
    echo ""

    local cmd_args=(
        python -m clawmeets.cli user listen "$user_name" "$user_password"
        --console
        -s "$SERVER_URL"
        --user-dir "$USERS_DIR"
        --log-level "${LOG_LEVEL:-warning}"
    )

    # Add notify script if specified in project.json
    if [[ -n "$notify_script" ]]; then
        # Resolve relative path from project config directory
        local config_dir
        config_dir=$(dirname "$PROJECT_CONFIG")
        if [[ "$notify_script" != /* ]]; then
            notify_script="$config_dir/$notify_script"
        fi
        if [[ -x "$notify_script" ]]; then
            cmd_args+=("$notify_script")
        fi
    fi

    "${cmd_args[@]}"
}

cmd_run() {
    require_jq

    echo -e "${BOLD}=== Run Project ===${NC}"
    echo ""

    # Setup: create project and upload files
    cmd_setup

    echo ""

    # Send: post initial request
    cmd_send

    echo ""

    # Console: watch changelog events
    cmd_console
}

cmd_run_with_browser() {
    require_jq

    echo -e "${BOLD}=== Open Project in Browser ===${NC}"
    echo ""

    [[ -f "$PROJECT_CONFIG" ]] || die "Project config not found: $PROJECT_CONFIG"

    # Read project config
    local project_name request shared_context_raw config_dir
    project_name=$(jq -r '.name // empty' "$PROJECT_CONFIG")
    request=$(jq -r '.request // empty' "$PROJECT_CONFIG")
    shared_context_raw=$(jq -r '.shared_context // empty' "$PROJECT_CONFIG")

    # Build URL with query params
    local url="${SERVER_URL}/app/projects/new"
    local params=""

    if [[ -n "$project_name" ]]; then
        params="${params}&name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${project_name}'))")"
    fi

    if [[ -n "$request" ]]; then
        params="${params}&request=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().rstrip('\n')))" <<< "$request")"
    fi

    # Collect shared_context filenames
    if [[ -n "$shared_context_raw" ]]; then
        config_dir=$(dirname "$PROJECT_CONFIG")
        local setup_folder
        if [[ "$shared_context_raw" == /* ]]; then
            setup_folder="$shared_context_raw"
        else
            setup_folder="$config_dir/$shared_context_raw"
        fi
        if [[ -d "$setup_folder" ]]; then
            local filenames=""
            for filepath in "$setup_folder"/*; do
                [[ -f "$filepath" ]] || continue
                filenames="${filenames},$(basename "$filepath")"
            done
            filenames="${filenames#,}"
            if [[ -n "$filenames" ]]; then
                params="${params}&context_files=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${filenames}'))")"
            fi
        fi
    fi

    # Strip leading &
    params="${params#&}"
    if [[ -n "$params" ]]; then
        url="${url}?${params}"
    fi

    echo "Opening: $url"
    open "$url" 2>/dev/null || xdg-open "$url" 2>/dev/null || echo "Open this URL in your browser: $url"
}

cmd_clear() {
    echo "=== Clear Project Data ==="

    local projects_dir="${BUS_DIR}/projects"
    if [[ -d "$projects_dir" ]]; then
        rm -rf "$projects_dir"
        mkdir -p "$projects_dir"
        echo "Cleared $projects_dir"
    fi

    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_work_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_work_dir" ]] || continue

            local agent_projects_dir="${agent_work_dir}projects"
            if [[ -d "$agent_projects_dir" ]]; then
                rm -rf "$agent_projects_dir"
            fi

            echo "Cleared $(basename "$agent_work_dir")"
        done
    fi

    echo "Clear complete. Agent registrations preserved."
}

cmd_delete() {
    local project_id="$1"
    echo "=== Delete Project ${project_id:0:8}… ==="

    if [[ -z "${USER_TOKEN:-}" ]]; then
        echo "Error: USER_TOKEN environment variable required."
        echo "Get one with: python -m clawmeets.cli user login <username> <password>"
        exit 1
    fi

    python -m clawmeets.cli project delete "$project_id" \
        -s "$SERVER_URL" \
        -t "$USER_TOKEN" \
        --force

    # Clean up local agent project directories
    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_dir" ]] || continue
            for subdir in "projects" "metadata/projects" "sandbox/projects"; do
                for d in "$agent_dir$subdir"/*-"${project_id}"; do
                    if [[ -d "$d" ]]; then
                        rm -rf "$d"
                        echo "Cleaned up: $d"
                    fi
                done
            done
        done
    fi

    echo "Delete complete."
}

cmd_status() {
    echo "=== Project Status ==="
    echo ""

    # Check server
    local server_pid_file="${BUS_DIR}/server.pid"
    if [[ -f "$server_pid_file" ]]; then
        local pid
        pid=$(cat "$server_pid_file")
        if pid_is_alive "$pid"; then
            echo "Server:   running (PID $pid)"
        else
            echo "Server:   dead (stale PID $pid)"
        fi
    else
        echo "Server:   not started"
    fi

    # Check listener
    local listener_pid_file="${BUS_DIR}/listener.pid"
    if [[ -f "$listener_pid_file" ]]; then
        local pid
        pid=$(cat "$listener_pid_file")
        if pid_is_alive "$pid"; then
            echo "Listener: running (PID $pid)"
        else
            echo "Listener: dead (stale PID $pid)"
        fi
    else
        echo "Listener: not started"
    fi

    echo ""

    # Check agents
    if [[ -d "$AGENTS_DIR" ]]; then
        local found_agent=false
        for agent_work_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_work_dir" ]] || continue
            found_agent=true
            local name pid_file
            name=$(basename "$agent_work_dir")
            pid_file="${agent_work_dir}agent.pid"

            if [[ -f "$pid_file" ]]; then
                local pid
                pid=$(cat "$pid_file")
                if pid_is_alive "$pid"; then
                    echo "Agent $name:  running (PID $pid)"
                else
                    echo "Agent $name:  dead (stale PID $pid)"
                fi
            else
                echo "Agent $name:  not started"
            fi
        done

        if [[ "$found_agent" == "false" ]]; then
            echo "Agents:  (none)"
        fi
    else
        echo "Agents:  (directory not initialized)"
    fi

    # Check registrations
    if [[ -d "$AGENTS_DIR" ]]; then
        local creds=0
        local registered_agents=""
        for agent_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_dir" ]] || continue
            local cred="${agent_dir}credential.json"
            if [[ -f "$cred" ]]; then
                creds=$((creds + 1))
                local dirname
                dirname=$(basename "$agent_dir")
                registered_agents="${registered_agents}  - ${dirname%-*}\n"
            fi
        done
        if [[ "$creds" -gt 0 ]]; then
            echo ""
            echo "Registrations: $creds agent(s)"
            echo -e "$registered_agents"
        else
            echo ""
            echo "Registrations: (none)"
        fi
    else
        echo ""
        echo "Registrations: (none)"
    fi
}

cmd_stop_all() {
    echo "=== Stop All ==="

    # Stop server
    local server_pid="${BUS_DIR}/server.pid"
    stop_process "$server_pid" "server"

    # Stop listener
    local listener_pid="${BUS_DIR}/listener.pid"
    stop_process "$listener_pid" "listener"

    # Stop all agents
    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_dir in "$AGENTS_DIR"/*/; do
            [[ -d "$agent_dir" ]] || continue
            local agent_name
            agent_name=$(basename "$agent_dir")
            local agent_pid="${agent_dir}agent.pid"
            stop_process "$agent_pid" "agent $agent_name"
        done
    fi

    echo "All processes stopped."
}

cmd_restart() {
    echo "=== Restart ==="
    echo ""

    cmd_stop_all
    echo ""
    cmd_init
    echo ""
    cmd_server
    echo ""
    cmd_agents
}

usage() {
    echo "Usage: $0 <command> [command ...]"
    echo ""
    echo "Commands:"
    echo "  restart      Stop and restart server + agent processes (preserves data)"
    echo "  reset        Stop all processes, clear all directories"
    echo "  init         Initialize directory structure"
    echo "  server       Start server in background"
    echo "  users        Create users from project config (auto-creates assistant agents)"
    echo "  register     Register worker agents from config"
    echo "  verify-agents Verify all worker agents from config (admin)"
    echo "  agents       Start agents from project config in background"
    echo "  setup        Create project and upload setup files"
    echo "  send         Post initial request to coordinator"
    echo "  console      Watch changelog events with console output (Ctrl+C to stop)"
    echo "  run          Execute project workflow (setup + send + console)"
    echo "  run-with-browser  Open browser to create project with prefilled config"
    echo "  listen       Start user notification listener with TTS (run in separate terminal)"
    echo "  clear        Clear project files (keep registrations)"
    echo "  status       Show process status"
    echo "  stop-all     Stop server and all agent processes"
    echo "  stop-agents  Stop all agent processes (keep server running)"
    echo "  delete       Delete a project by ID (requires USER_TOKEN env var)"
    echo ""
    echo "Configuration (priority: env var > project.json > default):"
    echo "  DATA_DIR / data_dir       Base data directory (default: .clawmeets_data)"
    echo ""
    echo "Environment Variables:"
    echo "  CLAWMEETS_SERVER_URL            Full server URL (e.g. https://clawmeets.ai)"
    echo "  CLAWMEETS_BIND_SERVER_PORT     Port for local server startup (default: 4567)"
    echo "  CLAWMEETS_HAS_ADMIN_CREDENTIAL  'true' (default) = admin create, 'false' = self-register"
    echo "  CLAWMEETS_USERNAME            Override username from project.json"
    echo "  CLAWMEETS_USER_EMAIL          Override email from project.json"
    echo "  CLAWMEETS_USER_PASSWORD       Override password from project.json"
    echo "  PROJECT_CONFIG  Project config file (default: project.json)"
    echo "  NOTIFY_SCRIPT   Custom notification script (default: scripts/notify.py)"
    exit 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    if [[ $# -eq 0 ]]; then
        usage
        return
    fi

    while [[ $# -gt 0 ]]; do
        local cmd="$1"
        shift
        case "$cmd" in
            restart)  cmd_restart ;;
            reset)    cmd_reset ;;
            init)     cmd_init ;;
            server)   cmd_server ;;
            users)    cmd_users ;;
            register) cmd_register ;;
            verify-agents) cmd_verify_agents ;;
            agents)   cmd_agents ;;
            setup)    cmd_setup ;;
            send)     cmd_send ;;
            console)  cmd_console ;;
            run)      cmd_run ;;
            run-with-browser) cmd_run_with_browser ;;
            listen)   cmd_listen "${1:-foreground}"; shift ;;
            clear)    cmd_clear ;;
            status)   cmd_status ;;
            stop-all) cmd_stop_all ;;
            stop-agents) cmd_stop_agents ;;
            delete)   cmd_delete "${1:?Usage: $0 delete <project-id>}"; shift ;;
            -h|--help|help) usage; return ;;
            *)        echo "Unknown command: $cmd"; usage; return 1 ;;
        esac
    done
}

main "$@"
