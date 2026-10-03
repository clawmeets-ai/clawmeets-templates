# Personal Data Team

Five workers — four sync agents that keep your real data in local stores
on a schedule **and** answer interactive DMs (search inbox, compose mail,
look up next meeting, list albums, inspect inbox rows), plus a derivation
agent that builds clean, domain-specific tables for downstream
cross-template consumers. Three of the syncers ride **standard,
provider-agnostic protocols** (IMAP+SMTP for mail, CalDAV for calendar,
macOS Photos for photos); `@gdrive_inbox` tails Google Sheets that
external trigger services (IFTTT, Zapier, Google Apps Script) append rows
to — the right shape for ingesting push-driven event streams like Ring
doorbell motion or parcel-delivery notifications without standing up a
webhook server. Your data never leaves your network.

Every scheduled job follows an **SOP** — a stored, reusable procedure in
your My Desk SOP library, addressed to the agent that runs it. The SOP
says what to pull; the agent chooses (and writes into the SOP) where it
keeps the data, how it dedups, and how each run fetches only what's new.

## The Team

| Agent | Protocols | What they do |
|-------|-----------|--------------|
| `@mailbox` | IMAP + SMTP (`mailbox` skill) | Runs its sync SOP over chosen folders; interactive search / get / send |
| `@calendar` | CalDAV (`calendar` skill) | Runs its sync SOP over chosen calendars; interactive list / get / create / update / delete |
| `@photo` | macOS Photos (`osxphotos` skill) | Runs its sync SOP to index photo metadata; interactive list albums / list photos / export |
| `@gdrive_inbox` | Google Sheets push (`google-drive` skill) | Runs its sync SOP over IFTTT/Zapier-fed Sheet tabs; interactive sample / inspect rows |
| `@data_organizer` | — | Surveys what the syncers hold, proposes derivations, and runs derivation SOPs that write domain-specific tables |

Each sync agent runs in **two modes**: a sync run (follow the SOP, one
line per dataset in reply) when asked to run its SOP, or conversational
on any other DM.

## Install

```bash
clawmeets init --from-url https://<your-server>/templates/personal_data/setup.json
clawmeets start
```

`clawmeets init` registers the agents and installs the matching skills.
It does **not** finish their setup — the mailbox + calendar skills each
need a config plus runner env vars for credentials, and each agent needs
a sync SOP. All of that happens after init.

## Manual setup steps (after `clawmeets init`)

### 1. Configure the connections

Each skill reads its connection config from a per-agent file at
`{agent_dir}/skill-hub/configs/<skill>.json`. Edit it from the
**Configure** pill on the skill's row in **Agent Settings → Skills** — the
modal opens a JSON editor pre-filled with the starter template.

#### `mailbox`

```json
{
  "imap": {
    "host": "imap.fastmail.com",
    "port": 993,
    "ssl": true,
    "username": "${MAILBOX_USERNAME}",
    "password": "${MAILBOX_PASSWORD}"
  },
  "smtp": {
    "host": "smtp.fastmail.com",
    "port": 587,
    "starttls": true,
    "username": "${MAILBOX_USERNAME}",
    "password": "${MAILBOX_PASSWORD}",
    "from": "${MAILBOX_USERNAME}"
  }
}
```

#### `calendar`

```json
{
  "caldav": {
    "url": "https://caldav.fastmail.com/dav/calendars/user/me@example.com/",
    "username": "${CALENDAR_USERNAME}",
    "password": "${CALENDAR_PASSWORD}"
  }
}
```

#### `osxphotos`

No config — a single Photos library on the host.

#### `google-drive` (for `gdrive_inbox`)

Auth uses Google OAuth — click **Authenticate** on the `google-drive` row
in **Agent Settings → Skills**. No `${VAR}` env vars required. Which
Sheet tabs to ingest goes in the agent's sync SOP, not in a config file.

### 2. Export credentials as env vars on the runner

```bash
export MAILBOX_USERNAME="me@example.com"
export MAILBOX_PASSWORD="..."          # see provider notes below
export CALENDAR_USERNAME="me@example.com"
export CALENDAR_PASSWORD="..."

clawmeets start
```

The skills resolve `${VAR}` placeholders from `os.environ` at runtime.
Missing vars surface as a clean `unset env vars: [...]` error envelope —
the agent will tell you what to export.

### 3. (Photos only, macOS) Grant Full Disk Access

The `osxphotos` skill reads `~/Pictures/Photos Library.photoslibrary`,
which is TCC-protected. Grant **Full Disk Access** to your Python
interpreter:

```bash
which python3   # → e.g. /Users/you/.pyenv/versions/3.14.3/bin/python3.14
```

Open **System Settings → Privacy & Security → Full Disk Access**, click
`+`, paste the path, toggle on, restart the runner.

Also install osxphotos in the runner's Python:

```bash
pip install osxphotos
```

### 4. Give each agent a sync SOP

DM each sync agent **Draft my sync SOP** (a sample request on its DM
launchpad). It proposes what to keep, where it will store it (path +
format, with a short format note next to each dataset), how it dedups,
and how each run fetches only what's new; once you approve, it saves the
SOP to your My Desk SOP library addressed to itself. Then ask it to
**Run your sync SOP now** once, and schedule the SOP from My Desk (or
ask your assistant to) — hourly for mail and calendar, nightly for
photos, every 10 minutes for Sheet inboxes are sensible defaults.

To backfill history, ask the agent to run its SOP with a longer lookback
(e.g. 90 days); it resets whatever incremental marker it keeps.

## Provider notes

### Gmail (mailbox)
- Enable IMAP in Gmail settings.
- Generate an [App Password](https://myaccount.google.com/apppasswords)
  (requires 2FA) — Google blocks plain password auth.
- `imap.host = imap.gmail.com`, `smtp.host = smtp.gmail.com`.

### iCloud (mailbox + calendar)
- Generate an [App-Specific Password](https://appleid.apple.com/account/manage).
- `imap.host = imap.mail.me.com`, `smtp.host = smtp.mail.me.com`.
- `caldav.url = https://caldav.icloud.com`.

### Fastmail (mailbox + calendar)
- Generate an [App Password](https://www.fastmail.com/settings/security/devicekeys).
- `imap.host = imap.fastmail.com`, `smtp.host = smtp.fastmail.com`.
- `caldav.url = https://caldav.fastmail.com/dav/calendars/user/<your-email>/`.

### Outlook / Microsoft 365 (mailbox)
- Generate an [App Password](https://account.microsoft.com/security)
  (requires 2FA).
- `imap.host = outlook.office365.com`, `smtp.host = smtp.office365.com`.

### ProtonMail (mailbox)
- Run [ProtonMail Bridge](https://proton.me/mail/bridge); use the
  Bridge's local IMAP/SMTP creds (typically `127.0.0.1:1143` / `1025`).

### Nextcloud (calendar)
- Use account password or an app password.
- `caldav.url = https://<host>/remote.php/dav/calendars/<username>/`.

### Self-hosted (Dovecot/Postfix, Radicale, mailcow, Mailu, SOGo)
- Plug in your server's host/port/credentials.

## Push-driven inbox setup (Ring example)

`gdrive_inbox` shines on signals that originate **outside** your machine
and that some upstream service can be coaxed into shipping to a Google
Sheet. The canonical example is a Ring doorbell: motion events fire on
the device, IFTTT (or Zapier) translates them into Sheet rows, and
`gdrive_inbox` ingests rows on a schedule via its sync SOP — no Ring API auth, no
webhook server, no rotating refresh tokens, no battery impact from
periodic `get_snapshot()` calls.

The same pipe absorbs any other webhookable trigger: GitHub starred
repos, Stripe charges, parcel-delivery notifications, smart-lock
unlocks, weather threshold alerts. One dataset per Sheet tab.

### 1. Create the destination Google Sheet

Make a new Sheet (any account that `gdrive_inbox` has OAuth access to).
Add a tab named `ring_motion` with a single header row:

```
event_id    ts    device_name    event_kind    image_url    raw
```

Note the Sheet's file id — it's the path segment after `/d/` in the
Drive URL (`docs.google.com/spreadsheets/d/<file_id>/edit`).

### 2. Configure the IFTTT applet

Ring requires **IFTTT Pro** (~$3.99/mo as of writing). On
[ifttt.com](https://ifttt.com/create):

- **Trigger**: Ring service → "New motion detected" (or "New ring") →
  pick your doorbell.
- **Action**: Google Sheets service → "Add row to spreadsheet" → pick
  the Sheet above and `ring_motion` tab.
- **Ingredient mapping** (tab-separated, in order matching the header):
  - `event_id` → `{{OccurredAt}}`
  - `ts` → `{{OccurredAt}}`
  - `device_name` → `{{DeviceName}}`
  - `event_kind` → `motion` (or `{{Event}}` if the Ring trigger exposes
    it for your applet)
  - `image_url` → leave empty, or `{{ImageUrl}}` if your applet exposes
    it (Ring's signed image URLs are short-lived — usually unusable by
    the time the next sync cycle runs)
  - `raw` → empty or `{{TriggerName}}: {{OccurredAt}}`

Save the applet. Trigger a motion event manually (walk past the
doorbell) and confirm a new row lands in the Sheet within ~1–2 minutes.

### 3. Wire `gdrive_inbox`

Authenticate the `google-drive` skill on the agent (**Agent Settings →
Skills → google-drive → Authenticate**), then DM `@gdrive_inbox`:

```
Add the `ring_motion` tab of Sheet <file_id> to your sync SOP as a
dataset named ring-motion. Dedup rows by event_id.
```

It updates its SOP (or drafts one), runs it once, and replies with the
row count and where it keeps the dataset.

### 4. Schedule it

A 10-minute cycle is a sensible default — sheets are tiny, and the agent
skips the pull when the Sheet's `modifiedTime` hasn't moved. Schedule
the SOP from My Desk.

### Caveats

- **End-to-end latency** is dominated by IFTTT's polling/dispatch and
  the sync cadence — typically motion → stored row in 5–15 min. Not
  real-time alerting.
- **`{{ImageUrl}}` is a short-lived signed URL** and likely expired by
  the time the next sync cycle reads it. If you want a persisted
  thumbnail, have the sync SOP fetch the URL in the same run and save a
  local jpg — or accept metadata-only and skip the image.
- **Dedup by `event_id`.** If IFTTT ever double-fires, the duplicate row
  stays in the Sheet; the agent's store should keep one row per
  `event_id`. Most applets don't double-fire; just be aware.
- **IFTTT Pro tier required** for Ring as a trigger. Free tier caps at
  2 applets and excludes Ring.

## Derivation layer

`@data_organizer` builds domain-specific tables (receipts, tax
statements, food logs, …) from what the sync agents keep. Each
derivation is its own SOP: source datasets, the per-row judgment (or a
deterministic personal skill for rollups), the output schema, and where
the result lives. Ask it to **Survey the synced data**, then **Propose
derivations**; it saves the ones you pick to your SOP library.

| Derived view | Consumer | Used for |
|---|---|---|
| Business receipts | `@budget_analyst` (finance template) | Monthly spend dashboards, anomaly detection, lifestyle-creep tracking |
| Tax statements | `@tax_strategist` (finance template) | Year-end CPA packet, deduction tracking, quarterly estimate inputs |
| Food logs | `@nutritionist` (wellness template) | Eating-pattern analysis, restaurant frequency, macro estimates |

## Deliberate non-features

- **No OAuth for mail/calendar.** Credential-only via runner env vars.
  The Gmail / Google Calendar skills remain the path for users who
  prefer OAuth.
- **No write-back to source during sync.** Sync runs never send mail,
  create events, or export photos. Writes are only valid in interactive
  mode.
- **No cross-source joining in v1.** One source per derivation; joining
  (mail × calendar) comes later.
