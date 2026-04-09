# AI a la Carte Example: Solopreneur Product Strategy

This example demonstrates a solopreneur using ClawMeets to run user research, define an ICP, and build a GTM strategy — all with AI agents. A PM agent interviews three user persona agents, then a marketing agent develops positioning and launch plans based on the research.

## Agents

| Agent | Role |
|-------|------|
| `pm` | Product Manager - interviews personas, defines ICP, scopes MVP features |
| `marketing` | Fractional CMO - develops GTM strategy, positioning, messaging, launch plan |
| `local_foodie` | User Persona - frequent diner who explores ethnic cuisines |
| `tourist` | User Persona - international traveler encountering foreign-language menus |
| `casual_diner` | User Persona - mainstream user who wants simple menu explanations |

Your assistant is auto-created when the user is registered and acts as the coordinator.

## Project

"AI a la Carte" is a mobile app that helps diners understand unfamiliar menus. The workflow runs in three phases:

1. **User Research**: PM interviews each persona agent to understand dining habits, pain points, willingness to pay
2. **ICP & MVP**: PM synthesizes interviews into ICP recommendation and MVP scope
3. **GTM Strategy**: Marketing develops positioning, messaging, growth channels, and launch plan based on PM's research

All agents challenge each other — personas push back on assumptions, PM and Marketing debate trade-offs.

## File Structure

```
ai-la-carte/
├── README.md           # This file
├── project.json        # Project and agent configuration
├── shared_context/
│   ├── VISION.md       # Product vision and context
│   └── BRIEF.md        # Project brief
├── pm/                 # PM agent knowledge
├── marketing/          # Marketing agent knowledge
├── local_foodie/       # Local foodie persona knowledge
├── tourist/            # Tourist persona knowledge
└── casual_diner/       # Casual diner persona knowledge
```

## Prerequisites

- Python 3.11+
- `jq` command-line JSON processor (`brew install jq` on macOS)

## Running the Example

```bash
# 1. Navigate to the example directory
cd examples/ai-la-carte

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

## What Happens

1. **Server starts** - The ClawMeets server runs on `localhost:4567`
2. **User created** - User and assistant agent are registered
3. **Agents register** - Each agent gets credentials
4. **Project created** - "ai-la-carte" project with shared-context
5. **Context uploaded** - `VISION.md` and `BRIEF.md` provide product context to all agents
6. **Request posted** - Coordinator receives the three-phase research request
7. **Phase 1** - PM interviews each persona agent in separate chatrooms
8. **Phase 2** - PM synthesizes interviews into ICP and MVP recommendations
9. **Phase 3** - Marketing develops GTM strategy using PM's research and persona insights
10. **Project completes** - Coordinator delivers final strategy documents

## Cleanup

```bash
# Stop all processes and clear everything
../../scripts/project.sh reset

# Or just clear project data (keep agent registrations)
../../scripts/project.sh clear
```

## Customization

- **VISION.md / BRIEF.md** - Change the product concept
- **project.json** - Modify agents, personas, or the research request
- **Persona knowledge dirs** - Add background context for each persona
