---
name: leave
description: Team leave / OOO management. CRUD over `accountability/leave.md` + `accountability/holidays.md`. Authoritative for "is @X on leave today" lookups used by every team-facing routine.
when_to_load: |
  Load when ANY of the following:
  - User asks "who's on leave today?" / "is @X out?" / "when is @Y back?"
  - User says "@X is on leave from <date> to <date>" or "log a holiday on <date>"
  - A routine needs to check leave/holiday status programmatically (use `_lib.sh` helpers — they don't need to load this skill)
  - User asks to move expired entries to the Past section
voice_source: ../../profile.md
---

# leave

Single source of truth for *who's out* and *when the team is off*. Every team-facing routine consults this before pinging anyone.

## Files this skill owns

| File | What it holds | Format |
|---|---|---|
| `accountability/leave.md` | Per-person OOO entries | `<@SLACK_ID> · YYYY-MM-DD to YYYY-MM-DD · note` (inclusive dates, IST) |
| `accountability/holidays.md` | Team-wide holidays (national / company) | `- YYYY-MM-DD · short name` (IST, one date per line) |

Both files have *Active* / *Upcoming* and *Past* sections. New entries go in *Active* / *Upcoming*; move to *Past* when convenient (no auto-prune).

## Shell helpers (already in `_lib.sh`)

Skills + routines that just need a yes/no answer should use these — no need to read this SKILL.md:

```bash
source accountability/routines/_lib.sh

is_on_leave "<@U09LL9JTDM5>"     # → exit 0 if covered by today's IST date
is_on_leave "<@U09LL9JTDM5>" 2026-06-12   # check specific date
is_holiday                       # → exit 0 if today is in holidays.md
is_holiday 2026-08-15
is_working_day                   # → exit 0 if weekday AND not a holiday
guard_working_day my-routine     # exit 0 (skip) if not a working day; prints "skipping — …"
n_working_days_ago 5             # → print the date N working days back (skips wknd + holidays)
```

`is_on_leave` is the contract every routine that pings teammates honours. The morning routine, `eod-streak-check`, `tasks-cleanup`, `friday`, `biweekly-shoutouts`, `collabs-tuesday-update`, `gtm-weekly-pick` all call it (or `guard_working_day`) at Step 0.

## When the user asks "who's on leave today?"

1. `source accountability/routines/_lib.sh` — gives access to `today_ist` + `is_on_leave`.
2. For each person in `definitions/people.md` (roster), call `is_on_leave <@SLACK_ID>`.
3. List those returning 0 with their leave note (parse the right line from `accountability/leave.md`).
4. If nobody's out, say so plainly: "Nobody on leave today." Don't pad with filler.

## When the user logs a new leave entry

1. Format: `- <@SLACK_ID> · YYYY-MM-DD to YYYY-MM-DD · note (per @sanket | self)`
2. Insert under `## Active` in `accountability/leave.md`. Keep entries date-ordered (earliest start date first).
3. **Don't** mark the person inactive in any other file (e.g. `marketing/team.md`'s `active=true|false`). Short leave is `leave.md`-only. `active=false` in `marketing/team.md` is reserved for permanent crew changes.
4. Confirm back in the source thread with the parsed dates + duration ("logged @famitha out Jun 11-12, 2 days").

## When a new holiday is announced

1. Format: `- YYYY-MM-DD · short name (region if relevant)`
2. Insert under `## Upcoming` in `accountability/holidays.md`, date-ordered.
3. Multi-day breaks → one line per day.

## Phase 3 migration target — sqlite

Per `drafts/2026-06-25-architecture-refactor/plan.md`, both files become sqlite tables in Phase 3:

```sql
-- ~/.config/claude/rapidnative-coach.sqlite (proposed schema)

CREATE TABLE leave_entries (
  slack_id  TEXT NOT NULL,
  start_date TEXT NOT NULL,  -- YYYY-MM-DD IST
  end_date   TEXT NOT NULL,
  note       TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_leave_dates ON leave_entries(start_date, end_date);

CREATE TABLE holidays (
  date  TEXT PRIMARY KEY,  -- YYYY-MM-DD IST
  name  TEXT NOT NULL,
  region TEXT  -- e.g. "India", "company", null = global
);
```

After Phase 3:

- `_lib.sh` helpers (`is_on_leave`, `is_holiday`) query sqlite directly (faster, atomic, no grep over markdown).
- `accountability/leave.md` and `accountability/holidays.md` become *projections* — auto-generated read-only views the team can eyeball. Source of truth is sqlite.
- This SKILL.md updates to add `INSERT` / `UPDATE` examples in addition to markdown editing.

## Voice when reporting leave status

- Specifics only. "@famitha out Jun 11-12" beats "Famitha is on leave for a couple of days".
- IST dates always. If the user asks in a different TZ, convert + label.
- Don't speculate why someone's out unless the note explicitly says.

## Related skills

- `eod-nudges` — reads `is_on_leave` before pinging missing-EOD teammates
- `growth-marketing` — morning routine silently skips on-leave crew via `is_on_leave`
- `task-management` (Phase 2) — tasks-cleanup skips assignments to anyone on leave
