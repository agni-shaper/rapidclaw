---
name: scheduler
description: Reminders + routine-run history. Owns the sqlite tables `reminders` and `routine_runs` in `~/.config/claude/rapidnative-coach.sqlite`. CRUD via shell scripts in `accountability/routines/`.
when_to_load: |
  Load when ANY of the following:
  - User says "remind me to X on <date>" / "set a reminder for X"
  - User asks "what reminders do I have?" / "what's scheduled?"
  - User asks why a routine didn't fire / when did X last run
  - User wants to cancel or list past reminders
voice_source: ../../profile.md
---

# scheduler

Cross-cutting skill. Owns two tables in the bot's sqlite DB:

| Table | What it holds |
|---|---|
| `reminders` | Future-dated message bodies that fire as Slack posts on `fire_date`. Picked up by `daily.md` Step 0 each morning. |
| `routine_runs` | Audit trail of every cron-fired routine — `started_at`, `ended_at`, `exit_code`, log path, optional notes. |

DB path: `~/.config/claude/rapidnative-coach.sqlite`. Both tables sqlite-only since 2026-06-30 (the markdown reminder files at `accountability/reminders/` were removed in the same cutover).

## Shell wrappers — reminders

| Script | Purpose |
|---|---|
| `accountability/routines/reminder-add.sh <fire_date> "<body>" [--time HH:MM] [--channel <id>] [--thread <ts>] [--by <SLACK_ID>]` | Schedule a reminder. Defaults: channel `C0B4HG16QP3` (#rapidnative-coach), created_by `bot`. |
| `accountability/routines/reminder-list.sh [--all \| --today \| --on YYYY-MM-DD]` | Print scheduled reminders. Default: pending today onwards. |
| `accountability/routines/reminder-cancel.sh <id>` | Soft-cancel a pending reminder (`status='cancelled'`). |

The daily routine (`daily.md` Step 0, 11:30 IST) picks up every `pending` row whose `fire_date = today`, posts the body to the row's channel/thread, and marks it `fired`.

## Shell helpers — routine_runs (already in `_lib.sh`)

```bash
source accountability/routines/_lib.sh

ID=$(log_routine_start "my-routine")    # → INSERT, returns row ID
# ... do the work ...
log_routine_end "$ID" "$?" "summary"    # → UPDATE ended_at, exit_code, notes

last_run "my-routine"                   # → most recent started_at (ISO)
```

Other generic helpers:
- `db_path` — echo DB path
- `db_query "SELECT …"` — read query
- `db_exec "INSERT …"` — write query

## When the user says "remind me to X on <date>"

1. Resolve the date to absolute YYYY-MM-DD IST (today is in `today_ist`).
2. Default channel: the channel the request came from. Default thread: none (top-level on the fire date).
3. Run:
   ```bash
   accountability/routines/reminder-add.sh <date> "<body>" --by <sender_slack_id>
   ```
4. Confirm back with the parsed date + the returned reminder ID so the user can cancel by id later.

## When the user asks "what reminders do I have?"

```bash
accountability/routines/reminder-list.sh
```

## When the user asks "when did X last run?" / "did X fire today?"

```bash
last_run "X"                                                 # most recent
db_query "SELECT COUNT(*) FROM routine_runs WHERE routine='X' AND DATE(started_at)=DATE('now');"
```

## Anti-hallucination guards

1. **Don't claim a routine fired without checking `routine_runs`** (or `/tmp/<bot>-<routine>.log` mtime as a backup).
2. **Don't assume a reminder will fire if it's not in the DB.** Query sqlite — never trust memory.
3. **All times are IST** unless the user explicitly asks for UTC.

## Schema reference (live)

```sql
CREATE TABLE reminders (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  fire_date   TEXT NOT NULL,                  -- YYYY-MM-DD IST
  fire_time   TEXT,                           -- HH:MM IST, optional
  channel_id  TEXT,                           -- default C0B4HG16QP3 if NULL
  thread_ts   TEXT,                           -- optional, for thread reply
  body        TEXT NOT NULL,                  -- Slack mrkdwn
  created_by  TEXT,                           -- Slack user ID or 'bot'
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  fired_at    TEXT,                           -- ISO ts once fired
  status      TEXT NOT NULL DEFAULT 'pending' -- 'pending' | 'fired' | 'cancelled'
);
CREATE INDEX idx_reminders_pending ON reminders(fire_date, status);

CREATE TABLE routine_runs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  routine     TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  ended_at    TEXT,
  exit_code   INTEGER,
  log_path    TEXT,
  notes       TEXT
);
CREATE INDEX idx_routine_runs_recent ON routine_runs(routine, started_at DESC);
```

## Related skills

- `leave` — also writes to the same DB (`leave_entries`, `holidays`)
- All cron-fired routines — read and write `routine_runs` via the helpers above
