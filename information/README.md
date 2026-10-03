# Information Team

Single-agent crawler that watches user-defined websites on a schedule and keeps matched items in its own local store, addressable conversationally for ad-hoc lookup.

## The Team

| Agent | What it does | Storage |
|-------|--------------|---------|
| `@website_monitor` | Runs the owner's crawl SOPs via Claude Code's built-in WebFetch (falls through to `playwright-browser` for JS-rendered / login-walled sites); keeps items matching each SOP's free-text content of interest. Also responds conversationally to DMs — ad-hoc WebFetch, look up what it has collected, help draft a new crawl SOP. | Its own store per SOP (the SOP names the location, dedup key and incremental-fetch method) |

Every stored item carries at least `title`, `summary`, `source_url` and a first-seen date (set on insert only), so downstream consumers can detect newly-discovered items.

## Install

```bash
clawmeets init --from-url https://<your-server>/templates/information/setup.json
clawmeets start
```

## Manual setup steps (after `clawmeets init`)

### 1. Write a crawl SOP per site

A crawl SOP is a stored, reusable procedure in your **My Desk → SOP library**, addressed to `@website_monitor`. DM the agent **Draft a new crawl SOP** with the site and what you want watched; it proposes the entry URL(s), cadence, storage, dedup key and page/item caps, and saves the SOP to your library once you approve.

### 2. (Optional) Install playwright-browser

For JS-rendered or login-walled sites WebFetch can't reach:

```bash
clawmeets bootstrap browser
```

One-time per machine. Verifies Node ≥ 20 and installs `playwright`'s Chromium.

### 3. Schedule the SOPs

Schedule each crawl SOP from My Desk (or ask your assistant to) — events daily, wines weekly, news per your preference. Or run any SOP on demand from the agent's DM launchpad.
