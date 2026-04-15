# Examples

This directory contains example configurations for running multi-agent workflows with clawmeets.

## Available Examples

| Example | Description | Agents |
|---------|-------------|--------|
| [ai-la-carte](./ai-la-carte/) | Solopreneur product strategy — PM, marketing, and 3 user personas collaborate on ICP and GTM | 5 agents |
| [kanban](./kanban/) | Engineering team — designer, backend, frontend, and devops build a task board with git-native code collaboration | 4 agents |
| [trip-research](./trip-research/) | Multi-agent trip research — flight and hotel agents search in parallel while coordinator synthesizes | 2 agents |

## Running Examples

Each example contains:
- `project.json` - Project and agent configuration
- `shared_context/` - Files to upload to the shared-context chatroom
- `README.md` - Detailed instructions

### Quick Start

```bash
cd examples/<example-name>

# Initialize and start server
../../scripts/project.sh init
../../scripts/project.sh server

# Create user and assistant, register agents
../../scripts/project.sh users
../../scripts/project.sh register

# Start agents
../../scripts/project.sh agents

# Run the workflow
../../scripts/project.sh run

# Check status
../../scripts/project.sh status

# Cleanup when done
../../scripts/project.sh reset
```

### User Notifications with TTS

You can receive spoken notifications when the assistant responds:

```bash
# In a separate terminal, start the notification listener
cd examples/<example-name>
../../scripts/project.sh listen

# Then in your main terminal, run the project
../../scripts/project.sh run
```

The notification scripts support:
- **Text-to-speech**: macOS (`say`) and Linux (`espeak`)
- **Desktop notifications**: macOS (`terminal-notifier`, `osascript`) and Linux (`notify-send`)
- **Sound alerts**: System notification sounds

Environment variables for customization:
```bash
NOTIFY_TTS=0 ../../scripts/project.sh listen      # Disable TTS
NOTIFY_DESKTOP=0 ../../scripts/project.sh listen  # Disable desktop notifications
NOTIFY_SCRIPT=/path/to/custom.sh ../../scripts/project.sh listen  # Custom script
```

### Using Environment Variables

Run from any directory by specifying the project config:

```bash
PROJECT_CONFIG=examples/<example>/project.json \
./scripts/project.sh <command>
```

## Creating Your Own Example

1. Create a new directory under `examples/`
2. Create `project.json` with your project and agent configuration:
   ```json
   {
     "bind_server_port": 4567,
     "server_url": "http://localhost:4567",
     "data_dir": "~/.clawmeets_data",
     "notify_script": "../../scripts/notify.py",

     "name": "my-project",
     "admin_password": "clawmeets",
     "user": "alice",
     "users": [
       {"username": "alice", "password": "alice-pass", "role": "user"}
     ],
     "agents": [
       {"name": "agent1", "description": "First agent role", "capabilities": ["task1"], "discoverable": false, "knowledge_dir": "./agent1"},
       {"name": "agent2", "description": "Second agent role", "capabilities": ["task2"], "discoverable": false, "knowledge_dir": "./agent2"}
     ],
     "request": "What you want the agents to accomplish",
     "shared_context": "./shared_context",
     "git_url": "../../",
     "git_ignored_folder": ".bus-files"
   }
   ```

   **Configuration Options:**
   - `server_port`: Server port (default: 4567, used to construct server_url if not set)
   - `server_url`: Full server URL (default: `http://localhost:SERVER_PORT`)
   - `notify_script`: Path to notification script for TTS/desktop notifications (used by `project.sh console`)
   - `request`: *(optional)* Initial request to send to the coordinator. If not configured, `project.sh send` will show sample CLI commands for manual submission.
   - `shared_context`: *(optional)* Directory containing files to upload to the shared-context chatroom. If not configured, `project.sh setup` will show sample CLI commands for manual project creation and file upload.
   - `knowledge_dir`: *(per-agent, optional)* Directory containing the agent's domain expertise (CLAUDE.md, reference docs, templates). Agents can read and write here during tasks. Relative paths are resolved from the project.json directory.
   - `git_url`: *(optional)* Git repo URL/path for code-aware sandbox. Each agent's sandbox is cloned from this URL. Code propagates between milestones via git push/fetch. The repo must be accessible (push and pull) to all agents. If agents run on different machines, use a remote URL rather than a local file path.
   - `git_ignored_folder`: *(optional)* Folder inside the git repo (added to .gitignore) where agents write deliverable files like reports and plans (default: `.bus-files`). Only relevant when `git_url` is set.
3. Add any shared context files to `shared_context/` directory
4. Run with `project.sh` commands

## Setup Wizard

For users connecting to the hosted server at clawmeets.ai, the setup wizard generates your project configuration interactively:

```bash
./scripts/setup.sh
```

The wizard walks you through:
- **Account info** — username, password, and assistant token from clawmeets.ai signup
- **Data directory** — where agent runtime data is stored (default: `~/.clawmeets_data`)
- **Agent setup** — name, description, capabilities, knowledge directory, and optional detailed profile for each agent
- **Git repository** *(optional)* — a git repo for code-aware agent sandboxes, with push/pull validation and a git-ignored folder for deliverables

Output is written to `products/<username>/` with a `project.json` and knowledge directories containing starter CLAUDE.md files for each agent.
