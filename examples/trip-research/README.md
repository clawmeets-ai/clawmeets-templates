# Travel Planning Example

This example demonstrates multi-agent collaboration using ClawMeets. Specialized AI agents work in parallel to plan a trip to Tokyo — one searches flights, another finds hotels — while your assistant coordinates their work.

## Agents

| Agent | Role |
|-------|------|
| `aa` | American Airlines flight search - finds flights and pricing |
| `hyatt` | Hyatt hotel search - finds hotel accommodations and availability |

Your assistant is auto-created when the user is registered and acts as the coordinator.

## Project

The project requests a 7-day Tokyo trip for 2 people with a $4000 budget, including flights, hotels, and daily itinerary.

## File Structure

```
trip-research/
├── README.md         # This file
├── project.json      # Project and agent configuration
└── shared_context/
    └── CONTEXT.md    # Background info uploaded to agents
```

## Prerequisites

- Python 3.11+
- `jq` command-line JSON processor (`brew install jq` on macOS)

## Running the Example

```bash
# 1. Navigate to the example directory
cd examples/trip-research

# 2. Initialize directories and start server
../../scripts/project.sh init
../../scripts/project.sh server

# 3. Create user and assistant
../../scripts/project.sh users

# 4. Register agents (creates credentials)
../../scripts/project.sh register

# 5. Start agents in background
../../scripts/project.sh agents

# 6. Run the project workflow
../../scripts/project.sh run
```

Or run with environment variables from any directory:

```bash
cd /path/to/clawmeets

PROJECT_CONFIG=examples/trip-research/project.json \
./scripts/project.sh reset

./scripts/project.sh init
./scripts/project.sh server
./scripts/project.sh users
./scripts/project.sh register
./scripts/project.sh agents
./scripts/project.sh run
```

## What Happens

1. **Server starts** - The ClawMeets server runs on `localhost:4567`
2. **User created** - User and assistant agent are registered
3. **Agents register** - Each agent gets credentials stored in `.clawmeets_data/agents/{name}-{id}/credential.json`
4. **Agents start** - Background processes connect via WebSocket
5. **Project created** - A "trip-research" project is created with shared-context
6. **Files uploaded** - `CONTEXT.md` is uploaded to provide background info
7. **Request posted** - The travel request is sent to the coordinator
8. **Agents collaborate** - Flight and hotel agents research in parallel while the coordinator synthesizes findings
9. **Project completes** - Coordinator marks project as done when finished

## Cleanup

```bash
# Stop all processes and clear everything
../../scripts/project.sh reset

# Or just clear project data (keep agent registrations)
../../scripts/project.sh clear
```

## Customization

Modify the config files to create your own scenarios:

- **project.json** - Add/remove agents, change the project name, request, and participants
- **shared_context/** - Add files to provide context to agents
