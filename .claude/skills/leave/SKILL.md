---
name: leave
description: Team leave / OOO management. CRUD over sqlite `leave_entries` + `holidays` via shell scripts. Authoritative for "is @X on leave today" lookups used by every team-facing routine.
when_to_load: |
  Load when ANY of the following:
  - User asks "who's on leave today?" / "is @X out?" / "when is @Y back?"
  - User says "@X is on leave from <date> to <date>" or "log a holiday on <date>"
  - A routine needs to check leave/holiday status programmatically (use `_lib.sh` helpers — they don't need to load this skill)
  - User asks to remove/correct an entry
voice_source: ../../profile.md
---

# leave

Single source of truth for *who's out* and *when the team is off*. Every team-facing routine consults this before pinging anyone.

## Where the data lives

Sqlite DB at `~/.config/claude/rapidnative-coach.sqlite`, two tables:

| Table | What it holds |
|---|---|
| `leave_entries` | Per-person OOO. Cols: `slack_id`, `start_date`, `end_date`, `note`, `status` (`active` \| `past`). Unique on `(slack_id, start_date, end_date)`. |
| `holidays` | Team-wide holidays (national / company). Cols: `date` (PK), `name`, `region`, `status` (`upcoming` \| `past`). |

Dates are IST, inclusive on both ends. Removals are soft (`status='past'`) — never `DELETE`. The 2026-06-30 cutover removed the markdown projection files; sqlite is the only store.

## Shell wrappers (use these — do not hand-write SQL)

All in `accountability/routines/`:

| Script | Purpose |
|---|---|
| `leave-add.sh <SLACK_ID> <start> <end> [note]` | Insert active leave entry. Accepts `<@U…>`, bare `U…`, or `@handle` (resolved via people.md). |
| `leave-rm.sh <SLACK_ID> <start>` | Soft-delete: mark active entry as `past`. |
| `leave-list.sh [--all | --on YYYY-MM-DD]` | Print active entries (default), all entries, or entries covering a date. |
| `holiday-add.sh <date> <name> [region]` | Insert upcoming holiday. |
| `holiday-rm.sh <date>` | Soft-delete: mark upcoming as `past`. |
| `holiday-list.sh [--all]` | Print upcoming (default) or all. |

## Shell helpers (already in `_lib.sh`) — for routines that just need a yes/no

```bash
source accountability/routines/_lib.sh

is_on_leave "<@U09LL9JTDM5>"          # → exit 0 if covered by today's IST date
is_on_leave "<@U09LL9JTDM5>" 2026-06-12  # check specific date
is_holiday                            # → exit 0 if today is a holiday
is_holiday 2026-08-15
is_working_day                        # → exit 0 if weekday AND not a holiday
guard_working_day my-routine          # exit 0 (skip) if not a working day; prints "skipping — …"
n_working_days_ago 5                  # → print the date N working days back
```

All sqlite-backed since 2026-06-30. Same exit-code contract as before; six v2 routines (`eod-streak-check`, `tasks-cleanup`, `friday`, `biweekly-shoutouts`, `collabs-tuesday-update`, `gtm-weekly-pick`) call them at Step 0.

## When the user asks "who's on leave today?"

```bash
accountability/routines/leave-list.sh
```

If nobody's out: say "Nobody on leave today." Don't pad with filler.

## When the user logs a new leave entry

1. Resolve the teammate to a Slack ID (use `lookup_slack_id @handle` if needed).
2. Convert any relative dates to absolute YYYY-MM-DD IST.
3. Run:
   ```bash
   accountability/routines/leave-add.sh <SLACK_ID> <start> <end> "<note>"
   ```
4. Confirm back in the source thread with the parsed dates + duration ("logged @famitha out Jun 11-12, 2 days").
5. *Don't* mark the person inactive in any other file (e.g. `marketing/team.md`'s `active=true|false`). Short leave is the leave table only. `active=false` in `marketing/team.md` is reserved for permanent crew changes.

## When a new holiday is announced

```bash
accountability/routines/holiday-add.sh <date> "<name>" [region]
```

For multi-day breaks, call once per day. `region` is free text like "India" or "company"; null means global.

## When the user wants to remove or correct an entry

Soft-delete then re-add:
```bash
accountability/routines/leave-rm.sh <SLACK_ID> <start>     # mark past
accountability/routines/leave-add.sh <SLACK_ID> <new_start> <new_end> "<note>"
accountability/routines/holiday-rm.sh <date>
```

Soft-delete preserves audit trail. If the user explicitly asks for a hard delete, you can run `db_exec "DELETE FROM leave_entries WHERE …"` — but check with them first.

## Voice when reporting leave status

- Specifics only. "@famitha out Jun 11-12" beats "Famitha is on leave for a couple of days".
- IST dates always. If the user asks in a different TZ, convert + label.
- Don't speculate why someone's out unless the note explicitly says.

## Related skills

- `eod-nudges` — reads `is_on_leave` before pinging missing-EOD teammates
- `growth-marketing` — morning routine silently skips on-leave crew via `is_on_leave`
- `task-management` — tasks-cleanup skips assignments to anyone on leave
- `scheduler` — owns the `reminders` table in the same DB
