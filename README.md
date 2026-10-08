# Templates

Pre-built agent team templates for `clawmeets init --from-url`.

## Quick Start

```bash
pip install clawmeets
clawmeets init --from-url https://raw.githubusercontent.com/clawmeets-ai/clawmeets-templates/main/engineering/setup.json
clawmeets start
```

You can combine templates by running `clawmeets init --from-url` multiple times — agents from prior runs are preserved and merged.

`--from-url` also accepts a running ClawMeets server: if you're running your own deployment, every template here is served at `https://<host>/templates/<id>/setup.json` by the public `GET /templates/{id}/setup.json` endpoint — the same URL the zero-state Welcome page's copy-to-clipboard button hands you.

## Available Templates

| Template | Agents | Description |
|----------|--------|-------------|
| [`career`](./career/README.md) | Career Coach, Researcher, Interview Coach, Outreach Writer | Personal job-search crew working from your resume and target list |
| [`memories`](./memories/README.md) | Curator, Memoirist, Relationship Mapper, Bookmaker | Memory Lane crew that curates your photos and turns them into books, cards, and stories |
| [`finance`](./finance/README.md) | Budget Analyst, Investment Advisor, Tax Strategist | Personal CFO crew: monthly budget, investments, and tax strategy |
| [`solopreneur`](./solopreneur/README.md) | Product, Market, Investor, Branding | Three iterative loops orchestrated by your assistant — PMF (product ↔ market), pitch (product ↔ investor), Amazon-style announcement email (branding ↔ product) — pivots back on wedge or defensibility failure |
| [`thinking`](./thinking/README.md) | Thought Partner | One thinking partner that grills you on a decision, widens a narrow brainstorm, and pressure-tests a plan against what you're really deciding — before you spend a project on the wrong question |
| [`engineering`](./engineering/README.md) | Designer, Backend, Frontend, DevOps | Full-stack software development team |
| [`data`](./data/README.md) | DB Sync, Drive Sync, API Sync, Data Scientist | Business data team: sync DB / Drive / APIs into local stores, each syncer following an SOP you keep in My Desk; one analytical agent explores, hypothesis-tests, builds features, answers business questions, and promotes mature analyses to scheduled SOPs |
| [`personal_data`](./personal_data/README.md) | Mailbox, Calendar, Photo, Data Organizer | Personal data over standard protocols (IMAP+SMTP, CalDAV, macOS Photos) — sync your real mail / calendar / photo metadata into local stores on a schedule (each agent follows a sync SOP you keep in My Desk), AND address each agent conversationally for ad-hoc search/send/lookup. Provider-agnostic (Gmail app-password, iCloud, Fastmail, Outlook, ProtonMail Bridge, Nextcloud, Radicale, self-hosted). `@data_organizer` owns the derivation layer (SOP-driven derived tables + cross-template handoff to finance) |
| [`retail`](./retail/README.md) | Market Analyst, Finance, Marketing | New locations, product-line launches, and growth moves for retail/restaurant/service owners |
| [`restaurant`](./restaurant/README.md) | Market Analyst, Menu Finance, Brand, Designer | Restaurant audit + redesign crew: crawl your site, harvest menu + prices, read PMF and pricing, sharpen positioning, ship the new visual identity and a working HTML mockup of the redesigned homepage + menu |
| [`sales`](./sales/README.md) | Sales Dev, Inside Sales, Field Sales | Top-of-funnel pipeline crew: SDR builds the list and qualifies, Inside Sales runs cold email + digital follow-up cadence, Field Sales runs cold-visit pitch + in-person follow-up cadence |
| [`customer_success`](./customer_success/README.md) | Account Specialist, Customer Support | Two-agent CS crew: specialist owns onboarding / health / expansion (honest renewal calls, no hopecasting); support owns the inbox (triage by customer-perceived severity, general inquiries, FAQs from clustered repeats) |
| [`marketing`](./marketing/README.md) | Strategist, Creative, Instagram, SEO, YouTube, TikTok, Events, Direct Mail, Email, PR, Blog | Eleven-agent marketing team: a strategist (ROI / calendar / milestones), a creative (big-idea + cross-channel hooks), and nine channel specialists. The assistant stays a thin router. Bundles a four-phase **content engine** pipeline coordinated through one Google Sheet via the `google-drive-write` MCP |
| [`chess`](./chess/README.md) | Gamemaster (Claude), White (Gemini), Black (Codex), Narrator (Claude) | Demo: provider-vs-provider chess match. Gamemaster enforces rules through the `chess` MCP, a local HTML page renders the live board from the synced state file. Showcases per-agent `llm_provider` and in-tree MCP design. |

## Example Project Requests

Each template's per-folder `README.md` ships with 6–8 copy-paste project requests that showcase what the team can do. Open any template in the table above to see its examples.

## Template Format

Each template is a `setup.json` file with agent definitions. Templates describe worker agents; the user's personal `{username}-assistant` stays team-agnostic and coordinates across every installed template — any team-specific cues belong in the `sample_requests` bodies, which the coordinator reads as the project request.

```json
{
  "name": "Template Name",
  "description": "What this team does",
  "icon": "⚙️",
  "color": "#3043a8",
  "cats": ["work"],
  "blurb": "Short one-line card description shown on the Welcome page.",
  "pitch": "Longer pitch shown in the Welcome page detail drawer once the card is clicked.",
  "agents": [
    {
      "name": "agent_name",
      "description": "One-line description",
      "capabilities": ["skill1", "skill2"],
      "knowledge_dir": "./knowledge",
      "user_teams": ["Marketing", "Outbound"],
      "llm_provider": "claude",
      "llm_model": "claude-opus-4-7",
      "mcp_servers": ["gmail"],
      "discoverable": false,
      "profile": "Detailed specialty profile (used in generated CLAUDE.md)"
    }
  ]
}
```

The `icon` / `color` / `cats` / `blurb` / `pitch` fields are optional and only
power the zero-state Welcome page in the web UI (rendered by
`GET /templates` / `GET /templates/{id}`). `clawmeets init --from-url` ignores
them, so third-party templates that omit these fields work unchanged — the
Welcome page falls back to a neutral icon, the accent purple, no category
filter, and the template's `description` as both blurb and pitch. `cats`
accepts any of `work`, `life`, `play` (values outside this set are simply not
reachable via the category pills).

`user_teams` is an optional list of owner-defined team labels; each agent
shows up under each of its teams in the web UI's **TEAMS** sidebar (Gmail-label
style). Team names are free-form strings — no per-user allowlist — so the
sidebar derives the section list from `set(agent.user_teams)` across the user's
owned agents. You can also pass a comma-separated string (`"Marketing, Outbound"`)
instead of an array; both are normalized identically. Templates ship with each
agent assigned to a team named after the template folder as a sensible default.

All fields inside `assistant` and the extra fields on each `agents[]` entry
are optional. The `assistant` block, when present, is applied to the logged-in
user's personal assistant (`{username}-assistant`) — its `knowledge_dir`,
`llm_provider`, `llm_model`, `capabilities`, and `description` are synced to
the server via `PUT /agents/{assistant_id}`; any `mcp_servers` are installed
via `POST /agents/{assistant_id}/mcps`. Set `create_frontdesk_project: true`
to also have `clawmeets init` ensure a public Front Desk project
(`{username}-fd-assistant`) alongside the per-agent DM project
(`{username}-dm-assistant`) that registration lazy-creates — call is
idempotent, so re-running init is safe. Off by default so plain interactive
`clawmeets init` (no template) and templates that don't opt in leave the
user with only the per-agent DM channel.

**CLAUDE.md is never overwritten.** If `{knowledge_dir}/CLAUDE.md` already
exists for the assistant or any worker agent, `clawmeets init` leaves it
untouched so hand-edited profiles survive a re-run.

### `knowledge_dir` path rules

`knowledge_dir` accepts three forms, resolved at runner startup and on every
settings change:

| Form | Resolves to |
|------|-------------|
| `./kb`, `kb`, `../kb` (relative) | `~/.clawmeets/agents/<agent>/kb/` — inside the agent's own folder (AGENT_DIR), next to its memory and sandbox |
| `~/kb` (home-prefixed) | `~/kb` (expanded against the runner user's home) |
| `/abs/path` (absolute) | `/abs/path` (used verbatim) |

Prefer `./knowledge` in shared templates — it stays portable across users and
gives each agent its own folder. (Older cards held paths such as
`./career_coach` that resolved under `~/.clawmeets/config/<username>/`; the
runner moves such a folder into `AGENT_DIR/knowledge` once on its next start,
or pins the card to the old absolute path when two agents shared it.)
Use absolute paths in per-user product configs (see `products/chus-wine`)
when the knowledge base already lives in a known location outside
`~/.clawmeets/`.

## Creating Your Own Template

1. Create a directory with a `setup.json` file following the format above
2. Host it at any URL (GitHub, your own server, etc.)
3. Use it with: `clawmeets init --from-url <url-to-your-setup.json>`
