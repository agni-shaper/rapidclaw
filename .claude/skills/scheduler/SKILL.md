---
name: scheduler
description: Reminders + routine-run history. Will own the sqlite DB at `~/.config/claude/rapidnative-coach.sqlite` once Phase 3 lands. Until then, this skill is design-only — the existing plist-fired cron + markdown reminders continue to work.
when_to_load: |
  Load when ANY of the following:
  - User says "remind me to X on <date>" / "set a reminder for X"
  - User asks "what reminders do I have?" / "what's scheduled?"
  - User asks why a routine didn't fire / when did X last run
  - Phase 3 sqlite migration begins
voice_source: ../../profile.md
---

# scheduler

Cross-cutting skill. Today: reminders live as markdown in `accountability/reminders/YYYY-MM-DD.md` AND in the sqlite `reminders` table (Phase 3 backfilled both ways). Routine-run history now goes to sqlite `routine_runs` via the `log_routine_start` / `log_routine_end` helpers.

**Phase 3 sqlite is LIVE as of 2026-06-29.** DB at `~/.config/claude/rapidnative-coach.sqlite`. Schema below matches the live tables; the proposed `_lib.sh` helpers in this skill (`add_reminder`, `list_reminders`, etc.) are NOT all built yet — see "Built so far" below.

## Built so far

- `db_path` — echo DB path
- `db_query "SELECT …"` / `db_exec "INSERT …"` — generic wrappers
- `sqlite_is_on_leave` / `sqlite_is_holiday` — read-side parity with markdown helpers
- `log_routine_start <name>` → returns row ID
- `log_routine_end <id> <exit_code> [notes]` — closes the row
- `last_run <name>` — most recent started_at

Not yet built (TODO when first user-facing flow needs them):
- `add_reminder` / `list_reminders` / `cancel_reminder`
- `record_eod_post` / `query_eod_streak`
- Skill-specific table writers for `user_testing_issues`, `bug_reports`, `tasks_cleanup_proposals` mutations

## Read these before doing any work

1. `accountability/reminders/` — current per-day reminder files (markdown).
2. `accountability/routines/daily.md` Step 0 — current reminder pickup mechanism.
3. `definitions/routines.md` — full cron catalog (for "when did X last run" questions).

## What this skill will own (Phase 3+)

```sql
-- ~/.config/claude/rapidnative-coach.sqlite

CREATE TABLE reminders (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  fire_date   TEXT NOT NULL,   -- YYYY-MM-DD IST
  fire_time   TEXT,            -- HH:MM IST, optional (default: morning routine)
  channel_id  TEXT,            -- where to post the reminder
  thread_ts   TEXT,            -- optional, if it's a thread continuation
  body        TEXT NOT NULL,   -- markdown
  created_by  TEXT NOT NULL,   -- Slack user ID
  created_at  TEXT DEFAULT CURRENT_TIMESTAMP,
  fired_at    TEXT,            -- NULL until the reminder fires; then ISO timestamp
  status      TEXT DEFAULT 'pending'  -- pending / fired / cancelled
);
CREATE INDEX idx_reminders_pending ON reminders(fire_date, status);

CREATE TABLE routine_runs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  routine     TEXT NOT NULL,   -- 'daily', 'tasks-cleanup', etc.
  started_at  TEXT NOT NULL,   -- ISO timestamp
  ended_at    TEXT,            -- ISO timestamp on completion, NULL while running
  exit_code   INTEGER,
  log_path    TEXT,            -- /tmp/rapidnative-coach-<routine>.log
  notes       TEXT             -- optional one-line summary
);
CREATE INDEX idx_routine_runs_recent ON routine_runs(routine, started_at DESC);
```

## Phase 3 helpers (proposed, to add to `_lib.sh`)

```bash
# Add a reminder
add_reminder <fire_date> <body> [--time HH:MM] [--channel <id>] [--thread <ts>]
# → INSERT INTO reminders ...

# List pending reminders for today (or a date)
list_reminders [<YYYY-MM-DD>]
# → SELECT FROM reminders WHERE fire_date = ? AND status = 'pending'

# Cancel a reminder
cancel_reminder <id>

# Log a routine run
log_routine_start <name>  # → INSERT INTO routine_runs (started_at, routine) RETURNING id
log_routine_end <id> <exit_code>  # → UPDATE routine_runs SET ended_at, exit_code WHERE id = ?

# Query history
last_run <routine>          # → SELECT MAX(started_at) WHERE routine = ?
runs_today <routine>        # → COUNT(*) WHERE routine = ? AND DATE(started_at) = DATE('now')
```

## How current reminder mechanism works (Today, until Phase 3)

`accountability/routines/daily.md` Step 0:

```bash
REMINDER_FILE="accountability/reminders/$(date +%F).md"
if [ -f "$REMINDER_FILE" ]; then
  {
    echo "📌 *Reminders for today*"
    echo
    cat "$REMINDER_FILE"
  } | accountability/routines/slack-post.sh C0B4HG16QP3 - >/dev/null
fi
```

To add a reminder today, write a file at `accountability/reminders/YYYY-MM-DD.md`. The morning routine pings it.

## Migration plan (Phase 3)

1. Create the sqlite DB at `~/.config/claude/rapidnative-coach.sqlite` (if not already by `leave` migration).
2. Backfill `reminders` from existing `accountability/reminders/*.md` files (one INSERT per existing file).
3. Add the `_lib.sh` helpers above.
4. Update `accountability/routines/daily.md` Step 0 to query sqlite instead of reading the .md file.
5. Update any `add reminder` flow (TBD — needs design for how users add reminders via Slack).
6. Once stable, delete `accountability/reminders/*.md`.

## Anti-hallucination guards

1. **Don't claim a routine fired without checking `routine_runs`** (after Phase 3) or `/tmp/<routine>.log` mtime (before Phase 3).
2. **Don't assume a reminder will fire if it's not in the DB.** Check sqlite (post-Phase 3) or the .md file (pre-Phase 3).
3. **All times are IST.** Don't quote in UTC unless explicitly asked.

## Related skills

- All routines, indirectly — this skill is the substrate
- `leave` — also writes to sqlite (Phase 3); shared DB
