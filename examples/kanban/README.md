# Kanban Example: Task Board

This example demonstrates multi-agent collaboration for building a software product. Four specialized AI agents work together: a UI/UX designer, a backend engineer, a frontend engineer, and a DevOps engineer. Your assistant acts as coordinator, orchestrating the project based on the PRD.

## Agents

| Agent | Role |
|-------|------|
| `designer` | UI/UX Designer - creates wireframes, optimizes information hierarchy |
| `backend` | Backend Engineer - designs API and SQLite database schema |
| `frontend` | Frontend Engineer - implements React components |
| `devops` | DevOps Engineer - deploys project branch via Docker, verifies implementation |

Your assistant is auto-created when the user is registered and acts as the coordinator.

## Project

Build a minimal task board application for small dev teams. The PRD defines:
- Target users and their context
- Prioritized user missions (Critical → Nice-to-have)
- Information hierarchy requirements
- Technical stack (Python/SQLite + React)

## What Makes This Example Interesting

1. **UX-First Workflow**: Designer prioritizes based on user mission criticality
2. **API Contract Coordination**: Backend and frontend must align on contracts
3. **Clear Handoffs**: Design specs → Implementation
4. **Deployment Verification**: DevOps deploys the project branch via Docker and reports a public URL for user testing
5. **User-Gated Merges**: The project branch is never merged to main without explicit user approval
6. **Git Branching**: Uses a local bare git repo for branch-based isolation — chatroom branches auto-merge to the project branch for cross-milestone continuity
7. **Agent Specialization**: Each agent has a SPECIALTY.md defining their skills

## File Structure

```
kanban/
├── README.md           # This file
├── project.json        # Project and agent configuration
├── shared_context/
│   └── PRD.md          # Product Requirements Document
├── designer/
│   └── SPECIALTY.md    # Designer's skills and strengths
├── backend/
│   └── SPECIALTY.md    # Backend engineer's skills and strengths
├── frontend/
│   └── SPECIALTY.md    # Frontend engineer's skills and strengths
└── devops/
    ├── SPECIALTY.md        # DevOps engineer's skills and strengths
    └── devops-agent.skill  # Container + tunnel tooling
```

## Prerequisites

- Python 3.11+
- `jq` command-line JSON processor (`brew install jq` on macOS)

## Running the Example

From the project root directory:

```bash
# 1. Navigate to the example directory
cd examples/kanban

# 2. Initialize directories and start server
../../scripts/project.sh init
../../scripts/project.sh server

# 3. Create user and assistant
../../scripts/project.sh users

# 4. Register agents (creates credentials)
../../scripts/project.sh register

# 5. Start agents in background
../../scripts/project.sh agents

# 6. Check status
../../scripts/project.sh status

# 7. Run the project workflow
../../scripts/project.sh run
```

## What Happens

1. **Server starts** - The ClawMeets server runs on `localhost:4567`
2. **Local git repo created** - A bare repo (`kanban-repo.git/`) is initialized for branch-based code collaboration (no GitHub access needed)
3. **User created** - User and assistant agent are registered
4. **Agents register** - Each agent gets credentials
5. **Project created** - "kanban" project with shared-context
6. **PRD uploaded** - `PRD.md` provides requirements to all agents
7. **Request posted** - Coordinator receives the build request
8. **Design phase** - Designer creates UX specs based on user missions
9. **API phase** - Backend designs database and API endpoints
10. **Implementation** - Frontend builds React components
11. **Deployment** - DevOps deploys the project branch via Docker and exposes a public tunnel URL
12. **User Verification** - Coordinator posts the deployment URL to user-communication for user testing
13. **User Approval** - User tests and explicitly approves before any merge to main

## Expected Deliverables

- `DESIGN.md` - UX wireframes and component specifications
- `API.md` - REST API documentation
- `schema.sql` - SQLite database schema
- `COMPONENTS.md` - React component architecture
- `*.tsx` - React component implementations
- `VERIFICATION.md` - DevOps validation report
- `DEPLOYMENT.md` - Deployment report with public URL and branch info

## Cleanup

```bash
# Stop all processes and clear everything
../../scripts/project.sh reset

# Or just clear project data (keep agent registrations)
../../scripts/project.sh clear
```

## Customization

- **PRD.md** - Modify requirements, add features, change priorities
- **SPECIALTY.md** - Customize agent expertise and skills
- **project.json** - Add more agents or modify roles
