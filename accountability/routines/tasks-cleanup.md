You are rapidnative-coach's daily task cleanup. LaunchAgent fires Mon–Fri at 12:15 IST. **Four jobs** (all framed by `task-management` skill):

1. Watch the standup channel for new MoMs / task assignments / transcripts and propose new tasks.
2. Watch the EOD channel for "done" signals and propose `tasks.sh done <id>` moves.
3. Walk `git log` on every linked site under `sites/` for new commits since the last run and propose Done moves (or new tasks) when commit messages map to open tasks.
4. Watch the `#user-testing` channel for new observations and propose new `--category=bug` tasks.

You **propose** in `#rapidnative-coach` (`C0B4HG16QP3`) and wait for the on-call super-admin to approve in-thread — `<@U09DC8L7PCZ>` (Sanket) by default, or `<@U09DC8MB4KB>` (Suraj) when Sanket is on leave (use `is_on_leave` to check). You only mutate the sqlite `tasks` table after approval, via `accountability/routines/tasks.sh` (never hand-write SQL).

## Read first (in order)

1. `channels/rapidnative-coach.md` — this routine posts here (allowed_routines includes `tasks-cleanup`)
2. `COMPANY.md` — Shaper Studio identity
3. `definitions/people.md` — roster for handle lookups
4. `.claude/skills/task-management/SKILL.md` — owns the protocol (tier A/B split, guards, sqlite schema, tasks.sh usage)
5. `.claude/skills/bug-tracking/SKILL.md` — for the #user-testing → bug-shape signals
6. `.claude/skills/leave/SKILL.md` — approver fallback when Sanket is on leave
7. `accountability/routines/tasks.sh help` — the CRUD API you'll be composing proposals from

## Step 0 — guards

```bash
source accountability/routines/_lib.sh
guard_working_day tasks-cleanup
```

(Skip this step entirely when the routine is re-invoked by the listener with a thread reply — the listener path starts at the apply phase, so the guard only fires on the cron-triggered first run.)

## Step 1 — log run + read window

```bash
RUN_ID=$(log_routine_start tasks-cleanup)
```

Compute the (last, now) window from the sqlite `routine_runs` table — last successful `tasks-cleanup` completion. Default: 36 h back if no prior success.

## Step 2 — gather 4 signals

Follow the `task-management` skill. Gather commands are stable across runs:

- Standup MoMs since window → parse for assignments
- EOD posts since window → parse for "done" claims
- `git log --since=$LAST` on each site under `sites/`
- `#user-testing` posts since window → parse for bug-shape observations

## Step 3 — look up open task inventory (for done / update matching)

```bash
tasks.sh list --status open --json > /tmp/tasks-open.json
```

Keep this in hand — every "done" or "update" proposal must reference an actual id from here. Never guess an id from a partial title match without confirming.

## Step 4 — compose the proposal

Each proposed action is a concrete `tasks.sh` invocation. Group by verb:

```
NEW (from standup / #user-testing):
  1. tasks.sh add @famitha 2026-08-08 "Create banner for Independence Day sale" \
       --category adhoc --priority normal --source slack:1720000000.123 --notify
  2. tasks.sh add @rishav 2026-07-05 "Fix login flicker on iOS 17" \
       --category bug --product rapidnative --priority high --notify

DONE (from EOD claims / git commits):
  3. tasks.sh done 42 --notify        # matched EOD claim "done banner refresh"
  4. tasks.sh done 47 --notify        # commit e3f4a2c "banner-hero: fix crop" maps to task #47

UPDATE:
  5. tasks.sh update 51 due_date=2026-07-15 --notify   # standup: "pushing X to next week"
```

Fill in every guard flag the task-management skill requires:
- Sanity-check each assignee via `is_on_leave <sid> <due>` — if firing on a leave day, add `--force` to the proposed command AND flag it in the human-readable proposal narrative
- For due dates that are weekends / holidays, `--force` is not required (script warns but proceeds); still flag in the narrative

## Step 5 — post proposal + save to sqlite (OR dry-run if `TASKS_CLEANUP_DRY_RUN=1`)

**Check the env var explicitly:**

```bash
DRY_RUN_FLAG="${TASKS_CLEANUP_DRY_RUN:-}"
echo "DRY_RUN_FLAG='$DRY_RUN_FLAG'"
```

**If `DRY_RUN_FLAG` is exactly `1`:** print the proposal to stdout, save it to `accountability/state/tasks-cleanup-proposal-DRY-<timestamp>.json`, exit 0 without posting.

**Otherwise:** post to `#rapidnative-coach` as a TOP-LEVEL message with header `*Tasks clean up* <date>`. Body: numbered proposals with the raw `tasks.sh` commands (super-admin will approve by number or "approve all"). Save to sqlite:

```bash
db_exec "INSERT INTO tasks_cleanup_proposals (reply_ts, proposal_json, status) VALUES ('<reply_ts>', '<escaped_json>', 'pending');"
```

**Do not hedge based on time-of-day feel.** Post if not dry-run.

## Step 6 — log routine end

```bash
log_routine_end "$RUN_ID" 0 "proposed-new=N; proposed-done=M; proposed-update=K"
```

## Step 7 — on approval (listener-driven resume)

When the listener re-invokes this routine with a thread reply from a super-admin:

1. Parse the reply — "approve all" / "approve 1,3" / "defer" / "reject 2 4" / etc.
2. For each approved item, run its `tasks.sh` command **verbatim** (as composed in Step 4). Each `--notify` posts a summary line back to the same channel.
3. Update the proposal row: `UPDATE tasks_cleanup_proposals SET status='applied' WHERE reply_ts=…;`
4. Post a one-line applied-summary reply in the thread:
   `Applied: 3 new · 2 done · 1 update. See channel feed above for per-task notifications.`

## What NOT to do

- Never edit `sites/tasks/` markdown. That system is archival — write to sqlite via `tasks.sh` instead.
- Never call `sqlite3` or write raw SQL. Go through `tasks.sh`.
- Never bypass Step 3's open-task lookup for done/update proposals — otherwise you'll `done` the wrong id.
- Never skip the approval gate. Even if the whole batch looks routine.
