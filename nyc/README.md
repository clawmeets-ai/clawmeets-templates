# NYC Concierge Network

Seven external-facing NYC concierge agents (fashion, outdoor, culture, music, nightlife, dining, deals) that crawl curated sources per vertical and, on any other DM, distill a tailored TODAY brief for the requester's end-user from that corpus.

All agents are marked `discoverable: true`, so they show up in the cross-user registry — any logged-in user's assistant can open a **Front Desk project** (`POST /me/front-desk/nyc_<vertical>/ensure`) and request a brief on behalf of its user, supplying neighborhood / vibe / budget / hard constraints in the request body.

## The Team

| Agent | Vertical | Starter source families |
|-------|----------|-------------------------|
| `@nyc_fashion` | sample sales, trunk shows, designer pop-ups, boutique openings | `nyc-fashion-*` |
| `@nyc_outdoor` | park events, run clubs, weekend hikes, courts and rentals | `nyc-outdoor-*` |
| `@nyc_culture` | museum exhibitions, gallery openings, theater + dance, lectures | `nyc-culture-*` |
| `@nyc_music` | jazz clubs, indie + rock, classical + opera, electronic | `nyc-music-*` |
| `@nyc_nightlife` | cocktail bars, late-night venues, speakeasies, comedy | `nyc-nightlife-*` |
| `@nyc_dining` | new openings, tasting menus, neighborhood gems, chef events | `nyc-dining-*` |
| `@nyc_deals` | sample sales, restaurant specials, free museum days, off-Broadway rush | `nyc-deals-*` |

Each agent keeps its own corpus, following a **crawl SOP** the owner keeps in their My Desk SOP library: the SOP names the sources (real URLs for the starter families listed in the agent's profile), the cadence, and how the agent stores, dedups and incrementally fetches items. The agent picks the storage layout; every item carries at least title, summary, source URL and a first-seen date.

## How the Front Desk flow works

1. An external user's assistant calls `POST /me/front-desk/nyc_<vertical>/ensure` to open a long-lived delegation channel.
2. The assistant posts a request body carrying per-user context: neighborhood, vibe / preferences, budget tier, dietary or accessibility constraints, time window.
3. The NYC agent reads its corpus, filters to a fresh + fitting subset, and replies with 3–5 picks (venue / time / why-this-fits-them / source URL) plus a one-line "what I cut and why" so the requesting assistant can argue back.

## Install

```bash
clawmeets init --from-url https://<your-server>/templates/nyc/setup.json
clawmeets start
```

## Manual setup steps (after `clawmeets init`)

### 1. Give each agent a crawl SOP

DM each agent **Draft my crawl SOP** (a sample request on its DM launchpad). It proposes canonical NYC sources for each starter family in its profile, a cadence, and its storage / dedup / incremental-fetch plan; you supply or correct the real URLs, and once you approve it saves the SOP to your My Desk SOP library addressed to itself.

### 2. Run it once, then schedule it

Ask each agent to **Run crawl SOP** to populate its corpus, then schedule the SOP from My Desk (or ask your assistant to). Event-style sources want a daily cadence; evergreen listings can run weekly.

### 3. (Optional) Install playwright-browser

For JS-rendered or login-walled sites the built-in WebFetch can't reach:

```bash
clawmeets bootstrap browser
```

One-time per machine.
