# Business Data Team

Three sync workers that pull your **actual** business data — databases, Google Drive folders, partner APIs — into local stores on a schedule, plus a `data_scientist` who reads that data, runs hypothesis tests, builds features, runs lightweight models, and turns it all into business answers — revenue dashboards, cohort analyses, pricing memos, anomaly drill-downs, exec briefs — under `deliverables/`.

Every scheduled job follows an **SOP** — a stored, reusable procedure in your My Desk SOP library, addressed to the agent that runs it. The SOP says what to pull; the agent chooses (and writes into the SOP) where it keeps the data, how it dedups, and how each run fetches only what's new. When an analysis matures into something worth re-running on schedule, the data scientist turns it into an SOP too.

## The Team

| Agent | What they do |
|-------|--------------|
| `@database` | Runs its sync SOP: executes read-only SQL queries (credentials as runner env vars) with whatever client the runner has (`psql`, `mysql`, `sqlite3`, Python) and keeps one dataset per query |
| `@gdrive` *(google-drive skill)* | Runs its sync SOP: pulls Drive folders, specific files, or single Sheet tabs via `clawmeets gdrive search` / `get`; text bodies inline, binary files link-only |
| `@api` *(http-api skill)* | Runs its sync SOP: pages through REST endpoints via `clawmeets http-api get|post`; auth secrets in runner env vars only |
| `@data_scientist` | Reads the syncers' datasets (each keeps a short format note next to its data), explores, tests hypotheses, builds features, runs lightweight models, and turns findings into business answers. Ships single-file interactive HTML via the bundled `web-artifacts` skill. Default output is `deliverables/`; recurring analyses become SOPs. |

Syncers are pure ingest + dedup; tagging, classification and aggregation are the data scientist's job. Sync is read-only.

## Install

```bash
clawmeets init --from-url https://<your-server>/templates/data/setup.json
clawmeets start
```

`clawmeets init` registers the four agents but **does not** finish their setup.

## Manual setup steps (after `clawmeets init`)

### 1. Credentials and auth

- **`database`** — install the DB client or Python driver your database needs on the runner (`psql`, `pip install psycopg`, `pip install pymysql`; SQLite is built in), and export the connection secrets as runner env vars (e.g. `PG_PWD`). Use `clawmeets env set` to keep them in the agent's runner-local env store.
- **`api`** — export each API's secret as a runner env var (e.g. `STRIPE_KEY`); the SOP references it as `${STRIPE_KEY}` in a header.
- **`gdrive`** — authenticate the `google-drive` skill (**Agent Settings → Skills → google-drive → Authenticate**). The token stays on the runner.

### 2. Give each syncer a sync SOP

DM each syncer **Draft my sync SOP** (a sample request on its DM launchpad) with what you want pulled — queries, Drive folders / files / Sheet tabs, or endpoints. It proposes where it will keep each dataset (path + format, with a format note), how it dedups (an id column), and whether each dataset is fetched incrementally (a since-timestamp it persists) or re-pulled as a snapshot. Once you approve, it saves the SOP to your My Desk SOP library addressed to itself.

### 3. Run once, then schedule

Ask each syncer to **Run your sync SOP now**, then schedule the SOPs from My Desk (or ask your assistant to) — hourly or nightly, offset by a few minutes per agent. To backfill history, ask the agent to run its SOP with a longer lookback; it resets whatever incremental marker it keeps.

## Deliberate non-features

- **No tagging / classification / aggregation in syncers** — that's the data_scientist's job.
- **No write-back to source.** Sync is read-only by convention — `api` may use POST for read endpoints that require it, but nothing is pushed back.
- **No credentials in SOPs or stores.** Secrets are referenced as `${VAR}` placeholders that resolve from the runner's environment.
- **No writes into another agent's store.** Each syncer is the only writer to its own datasets; the data scientist writes recurring views only by running their SOPs.
