#!/usr/bin/env bash
#
# setup.sh - Interactive setup wizard for ClawMeets
#
# Generates products/{username}/ with project.json and agent knowledge directories.
# Designed for users who have already signed up at clawmeets.ai.
#
# Usage:
#   ./scripts/setup.sh
#
# Prerequisites:
#   - jq (brew install jq)
#   - An account on clawmeets.ai
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors (match project.sh conventions)
# ---------------------------------------------------------------------------

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ---------------------------------------------------------------------------
# Utility Functions
# ---------------------------------------------------------------------------

die() {
    echo -e "\033[0;31m[Error]${NC} $*" >&2
    exit 1
}

setup_msg() {
    echo -e "${BLUE}[Setup]${NC} $*"
}

require_jq() {
    command -v jq &>/dev/null || die "jq is required but not installed. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
}

validate_name() {
    local name="$1"
    local label="$2"
    if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        echo -e "${YELLOW}[Warning]${NC} Invalid $label: '$name'. Must start with a lowercase letter and contain only lowercase letters, numbers, and underscores."
        return 1
    fi
    # Check reserved names
    case "$name" in
        admin|system|root|agent|agents|user|users|assistant)
            echo -e "${YELLOW}[Warning]${NC} '$name' is a reserved name. Please choose another."
            return 1
            ;;
    esac
    return 0
}

prompt_required() {
    local prompt_text="$1"
    local result=""
    while [[ -z "$result" ]]; do
        echo -en "${BOLD}$prompt_text${NC} "
        read -r result
        if [[ -z "$result" ]]; then
            echo -e "${YELLOW}[Warning]${NC} This field is required."
        fi
    done
    echo "$result"
}

# ---------------------------------------------------------------------------
# Resolve output directory
# ---------------------------------------------------------------------------

# Determine project root: if we're in a repo with scripts/setup.sh, use that.
# Otherwise output to current directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/project.sh" ]]; then
    # Running from within the clawmeets repo or clawmeets-examples
    PROJECT_ROOT="${SCRIPT_DIR}/.."
else
    PROJECT_ROOT="$(pwd)"
fi

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

print_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}=== ClawMeets Setup Wizard ===${NC}"
    echo ""
    echo "  This wizard will generate your agent team configuration."
    echo "  You'll get a project.json and knowledge directories for each agent."
    echo ""
    echo -e "  ${YELLOW}Prerequisites:${NC}"
    echo -e "    1. Sign up at ${BOLD}https://clawmeets.ai${NC} (if you haven't already)"
    echo -e "    2. Install the runner: ${BOLD}pip install clawmeets${NC}"
    echo ""
}

# ---------------------------------------------------------------------------
# Collect User Info
# ---------------------------------------------------------------------------

collect_user_info() {
    echo -e "${BOLD}${CYAN}--- Account Info ---${NC}"
    echo "  Enter the username and password you registered at clawmeets.ai"
    echo ""

    # Username
    while true; do
        echo -en "${BOLD}  Username:${NC} "
        read -r USERNAME
        if [[ -z "$USERNAME" ]]; then
            echo -e "  ${YELLOW}[Warning]${NC} Username is required."
            continue
        fi
        if validate_name "$USERNAME" "username" 2>&1 | grep -q "Warning"; then
            validate_name "$USERNAME" "username"
            continue
        fi
        break
    done

    # Password
    while true; do
        echo -en "${BOLD}  Password:${NC} "
        read -rs PASSWORD
        echo ""
        if [[ -z "$PASSWORD" ]]; then
            echo -e "  ${YELLOW}[Warning]${NC} Password is required."
            continue
        fi
        echo -en "${BOLD}  Confirm password:${NC} "
        read -rs PASSWORD_CONFIRM
        echo ""
        if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
            echo -e "  ${YELLOW}[Warning]${NC} Passwords do not match. Try again."
            continue
        fi
        break
    done

    # Check if output directory exists
    OUTPUT_DIR="${PROJECT_ROOT}/products/${USERNAME}"
    if [[ -d "$OUTPUT_DIR" ]]; then
        echo ""
        echo -e "  ${YELLOW}[Warning]${NC} Directory already exists: products/${USERNAME}/"
        echo -en "  ${BOLD}(o)verwrite / (b)ackup / (q)uit?${NC} "
        read -r choice
        case "$choice" in
            o|O)
                rm -rf "$OUTPUT_DIR"
                ;;
            b|B)
                local backup="${OUTPUT_DIR}.bak.$(date +%s)"
                mv "$OUTPUT_DIR" "$backup"
                setup_msg "Backed up to $(basename "$backup")"
                ;;
            *)
                echo "Aborted."
                exit 0
                ;;
        esac
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# Collect Agents
# ---------------------------------------------------------------------------

collect_agents() {
    echo -e "${BOLD}${CYAN}--- Agent Setup ---${NC}"
    echo "  Define your AI agents. Each agent has a name, description, capabilities,"
    echo "  and an optional detailed profile."
    echo ""

    AGENTS_JSON="[]"
    AGENT_NAMES=()
    local agent_count=0

    while true; do
        agent_count=$((agent_count + 1))
        echo -e "  ${BOLD}${GREEN}Agent #${agent_count}${NC}"
        echo ""

        # Name
        local agent_name=""
        while true; do
            echo -en "    ${BOLD}Name${NC} (lowercase, e.g. 'backend', 'designer'): "
            read -r agent_name
            if [[ -z "$agent_name" ]]; then
                echo -e "    ${YELLOW}[Warning]${NC} Agent name is required."
                continue
            fi
            if ! validate_name "$agent_name" "agent name"; then
                continue
            fi
            # Check uniqueness
            local is_dup=false
            for existing in "${AGENT_NAMES[@]+"${AGENT_NAMES[@]}"}"; do
                if [[ "$existing" == "$agent_name" ]]; then
                    echo -e "    ${YELLOW}[Warning]${NC} Agent '$agent_name' already added. Choose a different name."
                    is_dup=true
                    break
                fi
            done
            if [[ "$is_dup" == "true" ]]; then
                continue
            fi
            break
        done

        # Description
        local agent_desc=""
        while [[ -z "$agent_desc" ]]; do
            echo -en "    ${BOLD}Description${NC} (one-line, e.g. 'Backend Engineer - implements Python APIs'): "
            read -r agent_desc
            if [[ -z "$agent_desc" ]]; then
                echo -e "    ${YELLOW}[Warning]${NC} Description is required."
            fi
        done

        # Capabilities
        local agent_caps=""
        while [[ -z "$agent_caps" ]]; do
            echo -en "    ${BOLD}Capabilities${NC} (comma-separated, e.g. 'Python,FastAPI,async'): "
            read -r agent_caps
            if [[ -z "$agent_caps" ]]; then
                echo -e "    ${YELLOW}[Warning]${NC} At least one capability is required."
            fi
        done

        # Setup description (optional, multi-line)
        echo -en "    ${BOLD}Detailed profile${NC} (optional, describe expertise/workflow. Enter empty line to finish):"
        echo ""
        local setup_desc=""
        while true; do
            echo -en "    > "
            read -r line
            if [[ -z "$line" ]]; then
                break
            fi
            if [[ -n "$setup_desc" ]]; then
                setup_desc="${setup_desc}\n${line}"
            else
                setup_desc="$line"
            fi
        done

        # Store agent
        AGENT_NAMES+=("$agent_name")

        # Build JSON for this agent
        local caps_json
        caps_json=$(echo "$agent_caps" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)

        local agent_json
        agent_json=$(jq -n \
            --arg name "$agent_name" \
            --arg desc "$agent_desc" \
            --argjson caps "$caps_json" \
            --arg knowledge_dir "./${agent_name}" \
            '{
                name: $name,
                description: $desc,
                capabilities: $caps,
                discoverable: false,
                knowledge_dir: $knowledge_dir
            }')

        AGENTS_JSON=$(echo "$AGENTS_JSON" | jq --argjson agent "$agent_json" '. + [$agent]')

        # Store setup description separately for CLAUDE.md generation
        # Use a temp file to avoid bash array quoting issues with multi-line strings
        local desc_file="/tmp/clawmeets_setup_${agent_name}_desc"
        if [[ -n "$setup_desc" ]]; then
            echo -e "$setup_desc" > "$desc_file"
        else
            echo "" > "$desc_file"
        fi

        echo ""
        echo -e "    ${GREEN}Added agent '${agent_name}'${NC}"
        echo ""

        # Ask for more
        echo -en "  ${BOLD}Add another agent? (y/n):${NC} "
        read -r add_more
        echo ""
        if [[ "$add_more" != "y" && "$add_more" != "Y" ]]; then
            break
        fi
    done

    if [[ ${#AGENT_NAMES[@]} -eq 0 ]]; then
        die "At least one agent is required."
    fi
}

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------

confirm_summary() {
    echo -e "${BOLD}${CYAN}=== Setup Summary ===${NC}"
    echo ""
    echo -e "  ${BOLD}Server:${NC}   https://clawmeets.ai"
    echo -e "  ${BOLD}Username:${NC} ${USERNAME}"
    echo -e "  ${BOLD}Agents:${NC}   ${#AGENT_NAMES[@]}"
    echo ""

    echo "$AGENTS_JSON" | jq -c '.[]' | while read -r agent; do
        local name desc caps
        name=$(echo "$agent" | jq -r '.name')
        desc=$(echo "$agent" | jq -r '.description')
        caps=$(echo "$agent" | jq -r '.capabilities | join(", ")')
        echo -e "    ${BOLD}${name}${NC} - ${desc}"
        echo -e "      Capabilities: ${caps}"
        echo -e "      Knowledge dir: ./${name}"
        echo ""
    done

    echo -e "  ${BOLD}Output:${NC} products/${USERNAME}/"
    echo ""
    echo -en "  ${BOLD}Proceed? (y/n):${NC} "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Generate Output
# ---------------------------------------------------------------------------

generate_project_json() {
    local output_file="${OUTPUT_DIR}/project.json"

    jq -n \
        --arg server_url "https://clawmeets.ai" \
        --arg name "$USERNAME" \
        --arg user_name "$USERNAME" \
        --arg user_pass "$PASSWORD" \
        --argjson agents "$AGENTS_JSON" \
        '{
            server_url: $server_url,
            name: $name,
            user: { username: $user_name, password: $user_pass },
            agents: $agents,
            agent_pool: "owned"
        }' > "$output_file"

    setup_msg "Generated project.json"
}

generate_claude_md() {
    local agent_name="$1"
    local agent_json="$2"

    local desc caps_csv knowledge_dir
    desc=$(echo "$agent_json" | jq -r '.description')
    caps_csv=$(echo "$agent_json" | jq -r '.capabilities | join(", ")')
    knowledge_dir="${OUTPUT_DIR}/${agent_name}"

    mkdir -p "$knowledge_dir"

    # Format agent name for display: replace _ with space, capitalize words
    local display_name
    display_name=$(echo "$agent_name" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')

    # Build skill table rows
    local skill_rows=""
    while IFS= read -r cap; do
        cap=$(echo "$cap" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$cap" ]]; then
            skill_rows="${skill_rows}| ${cap} | Expert |\n"
        fi
    done <<< "$(echo "$caps_csv" | tr ',' '\n')"

    # Read setup description if available
    local desc_file="/tmp/clawmeets_setup_${agent_name}_desc"
    local setup_desc=""
    if [[ -f "$desc_file" ]]; then
        setup_desc=$(cat "$desc_file")
        rm -f "$desc_file"
    fi

    # Build core specialties section
    local specialties_section=""
    if [[ -n "$setup_desc" && "$setup_desc" != "" ]]; then
        specialties_section="$setup_desc"
    else
        # Generate from capabilities
        specialties_section=""
        while IFS= read -r cap; do
            cap=$(echo "$cap" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$cap" ]]; then
                specialties_section="${specialties_section}- ${cap}\n"
            fi
        done <<< "$(echo "$caps_csv" | tr ',' '\n')"
    fi

    # Write CLAUDE.md
    cat > "${knowledge_dir}/CLAUDE.md" <<CLAUDE_EOF
# ${display_name} - Specialty Profile

## Role

${desc}

## Core Specialties

$(echo -e "$specialties_section")

## Skill Set

| Skill | Proficiency |
|-------|-------------|
$(echo -e "$skill_rows")
## Strengths

<!-- Customize this section based on your agent's specific strengths -->
<!-- Example: -->
<!-- 1. **Deep Expertise** - Extensive knowledge in core domain -->
<!-- 2. **Clear Communication** - Produces well-structured deliverables -->

## Deliverable Formats

<!-- Define the output formats your agent should produce -->
<!-- Example: -->
<!-- - \`REPORT.md\` - Analysis report with findings and recommendations -->
<!-- - \`PLAN.md\` - Action plan with timeline and milestones -->
CLAUDE_EOF

    setup_msg "Generated ${agent_name}/CLAUDE.md"
}

generate_output() {
    mkdir -p "$OUTPUT_DIR"

    generate_project_json

    echo "$AGENTS_JSON" | jq -c '.[]' | while read -r agent; do
        local name
        name=$(echo "$agent" | jq -r '.name')
        generate_claude_md "$name" "$agent"
    done
}

# ---------------------------------------------------------------------------
# Next Steps
# ---------------------------------------------------------------------------

print_next_steps() {
    echo ""
    echo -e "${BOLD}${GREEN}=== Setup Complete ===${NC}"
    echo ""
    echo -e "  ${BOLD}Generated:${NC}"
    echo "    products/${USERNAME}/project.json"
    for name in "${AGENT_NAMES[@]}"; do
        echo "    products/${USERNAME}/${name}/CLAUDE.md"
    done
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo -e "    ${CYAN}1.${NC} Navigate to your project directory:"
    echo -e "       ${BOLD}cd products/${USERNAME}${NC}"
    echo ""
    echo -e "    ${CYAN}2.${NC} Register your agents:"
    echo -e "       ${BOLD}../../scripts/project.sh register${NC}"
    echo ""
    echo -e "    ${CYAN}3.${NC} Start your agents:"
    echo -e "       ${BOLD}../../scripts/project.sh agents${NC}"
    echo ""
    echo -e "    ${CYAN}4.${NC} Open ClawMeets to create projects and collaborate:"
    echo -e "       ${BOLD}https://clawmeets.ai${NC}"
    echo ""
    echo -e "  ${GRAY}Tip: Customize your agents by editing the CLAUDE.md files in each agent's directory.${NC}"
    echo ""
}

# ---------------------------------------------------------------------------
# Cleanup temp files on exit
# ---------------------------------------------------------------------------

cleanup() {
    rm -f /tmp/clawmeets_setup_*_desc 2>/dev/null || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    require_jq
    print_banner
    collect_user_info
    collect_agents
    confirm_summary
    generate_output
    print_next_steps
}

main
