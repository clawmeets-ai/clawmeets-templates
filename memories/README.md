# Memory Lane Team

A four-agent photo-and-story crew that turns your library into books, cards, slideshows, and daily moments of reflection. Your photos, notes, and relationships never leave your machine.

## The Team

| Agent | What they do | Deliverables |
|-------|--------------|--------------|
| `@curator` | Organizes your library into events and trips, deduplicates near-identical shots, picks keepers | Event-grouped albums, caption drafts, print-worthy shortlists |
| `@memoirist` | Writes the narrative behind your photos: essays, trip recaps, milestone reflections, 'on this day' stories | Year-in-review essays, travel writeups, daily memory paragraphs |
| `@relationship_mapper` | Tracks who appears over time, builds people timelines, surfaces who you've seen most (and least) | People timelines, reconnection prompts, relationship heatmaps |
| `@bookmaker` | Turns selected photos and stories into shareable artifacts | Hardcover book layouts, holiday cards, slideshow scripts, social posts |

## Install

```bash
clawmeets init --from-url https://raw.githubusercontent.com/clawmeets-ai/clawmeets-templates/main/memories/setup.json
clawmeets start
```

`init` registers the four agents, installs the `photos` MCP on `curator` and `relationship_mapper` (macOS only), and installs the `photo-story` and `web-artifacts` skills on `bookmaker`. After install, point the curator's `knowledge_dir` at wherever your photos live — see **Photo source setup** below.

## Photo source setup

Two supported sources. Pick whichever matches your library:

**Option 1 — iCloud Drive folder (filesystem):** if your photos live in a regular folder synced via iCloud Drive (e.g. `~/Library/Mobile Documents/com~apple~CloudDocs/Photos/2025`), point the curator's `knowledge_dir` at it. Two ways:

- Web UI: open the curator's agent settings page and set **Knowledge directory** to the iCloud Drive path.
- Hand-edit: open `~/.clawmeets/agents/{username}-curator-{id}/card.json` and set `local_settings.knowledge_dir` to the iCloud Drive path; restart the agent.

The curator reads images directly via the file system. No MCP needed for this path.

**Option 2 — Apple Photos album (iCloud Photo Library):** if your photos live inside Photos.app as a named album ("2025", "Trip to Lisbon", etc.), the `photos` MCP reads them via [`osxphotos`](https://github.com/RhetTbull/osxphotos). Two upfront steps:

1. Install osxphotos on the runner (kept out of the baseline pip dep to keep it lean):

   ```bash
   pip install osxphotos
   ```

2. Grant Full Disk Access to the Python interpreter. Photos.app's library is TCC-protected; without this every call fails with a `PermissionError` on `Photos.sqlite`.

   ```bash
   which python   # → e.g. /Users/you/.pyenv/versions/3.14.3/bin/python3.14
   ```

   Open **System Settings → Privacy & Security → Full Disk Access**, click `+`, press `⌘⇧G`, paste the path printed above, click **Open**, toggle the switch on. Restart the runner.

Then reference the album by name in your request (e.g. "Build a year-in-review from my **2025** album").

## Seed the assistant's knowledge (recommended)

The memoirist writes better narrative when there's source material beyond pixels. Drop notes, journals, calendar exports, or milestone memos into `~/.clawmeets/agents/{your-username}-assistant/owner/`. The runner auto-indexes those files into `REFERENCES.md` (filename + content preview, refreshed on startup and whenever you change the knowledge dir); the assistant reads that map — and greps the files directly — when writing year recaps and milestone reflections.

## Long-running runs

Year-in-review on a large library (5k+ photos) can take 20–40 min as the curator funnels metadata → events → keepers and the bookmaker assembles the animated HTML. The server's default batch timeout is 30 min. If you hit it, restart the server with a longer timeout:

```bash
clawmeets server stop
clawmeets server start --batch-timeout 3600   # 1 hr
```

Or just re-trigger — partial work persists in the chatroom.

## Compelling Project Requests

Drop any of these into your coordinator and watch all four agents fan out in parallel — your photos and stories never leave your machine:

1. **Year in review** — *"Build a year-in-review from my **[year]** photos. Surface the ~50 that actually mattered (cluster by event, not date — cull mercilessly), write a narrative recap by season, map who I spent the most time with, and lay out a single-file animated HTML 'year story' I can open in a browser and text to family."*

2. **Trip recap** — *"I just got back from a trip to **[destination]** — photos are in my knowledge folder. Group them by city and day, write a travel essay with captions, pick the print-worthy shots, and draft a short social-post carousel I can share tomorrow."*

3. **Daily memory lane** — *"Every morning, send me one 'on this day' memory from 1, 5, and 10 years ago. `@curator`: pick the best photo from each year (pull from my library, dedupe against near-identical shots). `@relationship_mapper`: tell me who was in the photo and when I last spent time with them — nudge me if it's been a while. `@memoirist`: write a one-paragraph reflection for each year that ties the photo to what was happening in my life at the time (notes in knowledge where I have them)."*

4. **Milestone birthday book** — *"**[Person]** is turning **[age]**. Pull every photo with them in it from my library, write a narrative arc of their life through the moments captured, and design a hardcover book layout with large-print captions I can hand them on the day."*

5. **Kid milestone book** — *"My **[kid]** is turning **[age]**. Build a one-photo-per-month album from the day they were born to today, with captions of what they were doing or saying at each age, and prep a bound book layout I can hand out at their birthday party."*

6. **Friendship time capsule** — *"I want to make something for my **[group: e.g. college friends / team / bandmates]**. Find every photo of us together in my library, surface the funniest / most meaningful ones, write captions that capture the inside jokes, and lay out a shareable album with a 'remember when' intro I can text the group."*

## Why This Team Works

Cloud photo apps are great at "here are 6 photos of your dog from 2019." They're not great at writing a 30-page narrative about your kid's first decade, because that would require handing your entire photo library to a model — and you shouldn't. This team reads your library locally, writes the story in your voice, and nothing about your family ends up training anyone else's model.
