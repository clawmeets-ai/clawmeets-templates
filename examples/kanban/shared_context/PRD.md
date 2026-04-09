# Task Board - Product Requirements Document

## Vision

A minimal, focused task board for small development teams who need to track sprint work without the overhead of complex project management tools.

## Target Users

**Primary Persona: Small Dev Team Lead**
- Team size: 3-8 developers
- Context: Agile/Scrum sprints, 1-2 week cycles
- Pain points: Jira is too heavy, sticky notes don't sync
- Goals: Quick daily standups, clear sprint visibility, minimal friction

**Usage Context:**
- Checks board 5-10 times per day
- Updates tasks during standups (mobile-friendly)
- Reviews board in sprint planning meetings (desktop)

---

## User Missions (Prioritized by Criticality)

### Critical (P0) - Core Value Proposition

These missions define the product's reason to exist. Without them, users abandon immediately.

1. **See all tasks at a glance by status**
   - User needs to instantly understand sprint state in <3 seconds
   - Columns: To Do | In Progress | Done
   - Visual scan must reveal blockers and progress

2. **Create a new task in <10 seconds**
   - Minimal required fields: title only
   - Optional: description, priority, assignee
   - No page navigation required

3. **Move tasks between statuses**
   - Drag-and-drop on desktop
   - Tap-to-move on mobile
   - Instant visual feedback

### Important (P1) - Retention Drivers

Missing these causes friction and gradual churn.

4. **Set and visualize task priority**
   - Three levels: High / Medium / Low
   - Visual indicator (color/icon) visible without hover
   - High priority tasks should draw attention

5. **Assign tasks to team members**
   - Assignee avatar/initials visible on card
   - Filter by assignee
   - Unassigned tasks visually distinct

6. **Filter and search tasks**
   - Search by title/description
   - Filter by: assignee, priority, status
   - Persist filter state in URL

### Nice-to-Have (P2) - Delight Features

Enhance experience but can ship without.

7. **Due dates with overdue indicators**
8. **Task comments/discussion thread**
9. **Activity history log**

---

## Information Hierarchy Requirements

**For UX Designer:** Optimize visual hierarchy based on mission criticality above.

### Card Design Priority (what to show first)
1. Title (always visible, scannable)
2. Status (column position)
3. Priority indicator (color/icon)
4. Assignee (avatar)
5. Due date (if set, subtle unless overdue)

### Board Layout Priority
1. Status columns (primary organization)
2. Task cards (main content)
3. Quick-add input (persistent, accessible)
4. Filters (secondary, collapsible on mobile)

### Visual Attention Budget
- 60% → Task cards and their status
- 20% → Actions (add task, move task)
- 15% → Navigation and filters
- 5% → Branding and secondary info

---

## Technical Requirements

### Backend (Python + SQLite)
- FastAPI for REST endpoints
- SQLite database (single file, no server)
- Models: Task, User, Comment (P2)
- RESTful API: `/api/tasks`, `/api/users`

### Frontend (React)
- React 18+ with TypeScript
- Component library: Your choice (or custom)
- State management: React Query or Zustand
- Responsive: Mobile-first

### API Contract (Coordinate between backend/frontend)
```
GET    /api/tasks         - List all tasks
POST   /api/tasks         - Create task
PATCH  /api/tasks/:id     - Update task (status, priority, etc.)
DELETE /api/tasks/:id     - Delete task
GET    /api/users         - List team members
```

---

## Verification & Deployment

Every feature milestone must conclude with deployment verification:

1. DevOps deploys the application from the git project branch using Docker
2. DevOps exposes the running app via a public tunnel URL
3. The coordinator reports the URL to the user for testing
4. No merge to main until the user explicitly approves

---

## Deliverables

| Agent | Deliverable | Format |
|-------|-------------|--------|
| Designer | UX wireframes and component specs | `DESIGN.md` |
| Backend | API spec and database schema | `API.md` + `schema.sql` |
| Frontend | Component architecture and key components | `COMPONENTS.md` + `*.tsx` files |
| DevOps | Deployment report with public URL | `DEPLOYMENT.md` + `docker-compose.yml` |

---

## Success Criteria

1. A user can view, create, and move tasks in under 30 seconds
2. Information hierarchy clearly communicates task priority and status
3. API and frontend contracts are aligned
4. Design decisions are justified by user mission criticality
5. Application is deployed and accessible via a public URL for user verification
