---
name: task-management
description: The bot's task pipeline. Watches Slack channels + git logs, proposes task mutations, and on super-admin approval applies them via `tasks.sh` to the sqlite `tasks` table. Also serves ad-hoc requests ("assign X to @Y", "what's on my plate?", "mark #42 done").
when_to_load: |
  Load when ANY of the following:
  - Cron routine `tasks-cleanup` fires (12:15 IST Mon-Fri)
  - User asks "what's on my plate today?" / "show me my tasks" / "what's blocked?"
  - User asks to add / assign / move / close / cancel a task
  - The bot detects a "done #42" / "done T01" claim in a Slack thread reply
voice_source: ../../profile.md
---

# task-management

The skill owns the bot's relationship with the **sqlite `tasks` table** (single source of truth for all tasks since 2026-07-02). Two-tier interaction:

> *Tier A — feeder:* this skill watches the world (Slack channels + git logs) and proposes mutations.
> *Tier B — DB:* the sqlite `tasks` table at `~/.config/claude/rapidnative-coach.sqlite`, accessed via the dispatcher `accountability/routines/tasks.sh`.

**All writes go through `tasks.sh`.** Never hand-write SQL. Never edit anything under `sites/tasks/` (that markdown DB is archival — see "Migration" at the bottom).

## Read these before doing any work

1. **`accountability/routines/tasks.sh help`** — the CRUD API surface. Six subcommands (add / list / get / update / done / rm) plus global flags (`--json` / `--notify` / `--channel` / `--force`).
2. `definitions/people.md` — Slack ID ↔ @handle lookups. Source of truth.
3. `definitions/channels.md` — where a proposal should post (default: `#rapidnative-coach` `C0B4HG16QP3`).
4. `bin/init-tasks.sh` — the sqlite schema (12 columns + CHECK constraints on status/priority). Read to know what fields exist.
5. `sqlite ~/.config/claude/rapidnative-coach.sqlite` `routine_runs` — last successful `tasks-cleanup` run for idempotency between fires.

## The daily 12:15 IST cleanup flow

Four signals feed the proposal:

1. **Standup channel** (`C09DF90CQ8Z`) — new MoMs / task assignments / transcripts since last run. Propose new tasks.
2. **#eod-updates** (`C0A8Q9HM5BN`) — "done" signals since last run. Propose `tasks.sh done <id>`.
3. **Git logs** for every linked site under `sites/` since last run. Map commit messages to open tasks by title → propose Done moves (or new tasks if a commit doesn't match anything in flight).
4. **#user-testing** (`C09EU7C87BM`) — new observations since last run. Propose new bug-shaped tasks with `--category=bug` (loops in `bug-tracking` skill).

Step-by-step:

```
0. guard_working_day tasks-cleanup
1. Read last successful run window from sqlite `routine_runs` (default: 36h back).
2. Fetch each signal source for messages/commits since that window.
3. Look up existing open tasks: tasks.sh list --status open --json  (needed for done/update matching).
4. Compose a structured proposal, each line as a concrete tasks.sh invocation:
   NEW:    tasks.sh add @handle DUE "title" --category X --priority X --notify
   DONE:   tasks.sh done <id> --notify
   UPDATE: tasks.sh update <id> field=value --notify
5. Post the proposal to #rapidnative-coach as a TOP-LEVEL message:
   *Tasks clean up* <date>
   (the header marker is what the channel persona uses to route the reply path)
6. Save the structured proposal to sqlite: INSERT INTO tasks_cleanup_proposals (reply_ts, proposal_json, status) VALUES (...);
7. WAIT for approval reply in the same thread.
   Default super-admin: <@U09DC8L7PCZ> (Sanket).
   Fallback to <@U09DC8MB4KB> (Suraj) if Sanket is on leave (check via `is_on_leave`).
8. On approval ("go" / "approve all" / "approve 1,3,5" / "defer"), the listener re-invokes
   this skill with the thread context. Then APPLY by running each approved tasks.sh
   command verbatim. Each --notify emits a Slack summary to the same channel.
9. Update the proposal row: UPDATE tasks_cleanup_proposals SET status='applied' WHERE reply_ts=...
10. Post a one-line applied-summary reply in the same thread.
```

## When the user asks "what's on my plate?"

```bash
tasks.sh list --assignee @<user> --status open
```

- Group by priority (blocker → high → normal → low)
- Highlight overdue (due_date < today)
- Don't include `done` / `cancelled` unless explicitly asked (`--all` on list)
- For a single-task deep-dive use `tasks.sh get <id>`

## When the user asks to mutate a task ad-hoc

For ad-hoc requests like *"Assign create banner to @famitha for Aug 8"* or *"Mark #42 done"*:

1. **Infer defaults** from message context. Ask if any are ambiguous:
   - **Due date** — parse ("Friday", "next week", "Aug 8", "asap"). Default: 1 week from today if unspecified.
   - **Priority** — parse ("urgent" → high or blocker; "when you get a chance" → low). Default: normal.
   - **Category** — infer from the request (design/marketing/sprint/bug/adhoc). Default: adhoc.
   - **Product** — parse ("for RN", "on Applighter"). If unclear and product-context matters (e.g. design work), ASK before proposing.
2. **Tier-check the sender:**
   - Owner / super-admin → apply directly via `tasks.sh add @X DUE "title" --category X --priority X --notify`
   - Teammate → propose in-thread, wait for super-admin approval, then apply
3. **Look up existing tasks first** when the message references an existing task:
   - "mark #42 done" → `tasks.sh done 42 --notify`
   - "reassign #42 to @rishav" → `tasks.sh update 42 assignee=@rishav --notify`
   - "cancel that banner task" → `tasks.sh list --status open` → find matching → `tasks.sh rm <id> --notify`

## Anti-hallucination guards

1. **Never invent a handle.** Use `definitions/people.md`. If a name in a message isn't in the roster, ASK before assigning.
2. **Never invent a task ID.** Run `tasks.sh list` (with appropriate filters) to look one up. If the title match is ambiguous (multiple open tasks match), ask which.
3. **Don't skip the approval gate for teammate-tier senders.** Even if the mutation looks trivial. The gate exists to prevent unilateral dumps.
4. **Don't propose Done based on title guesses.** If EOD says "done banner" and there are two open banner tasks, list both and ask before proposing done on either.
5. **Don't propose Done without git evidence** for commit-derived done moves. Flag the discrepancy in the proposal if the commit message names a task that has no matching sqlite row.
6. **Never bypass the leave guard silently.** `tasks.sh` refuses to assign on a leave date (exit 2); if you want to override, pass `--force` and explain in the proposal WHY.
7. **Never DELETE from sqlite directly.** Cancellation is soft (`status='cancelled'`). Preserves audit trail.

## Migration status (since 2026-07-02)

- **Old:** `sites/tasks/` markdown DB (aliased-wikilink bullets, task pages, branch + PR per change, `intake/unsent-notifications.md` queue). Replaced.
- **New:** sqlite `tasks` table + `tasks.sh` dispatcher + `--notify` for Slack. This file.
- **What happens to `sites/tasks/`:** archival. No new writes. Existing task pages stay in the repo as history but are NOT synced to sqlite. Bulk migration is a possible follow-up.
- **What went away:**
  - Task-page markdown scaffolding
  - Aliased wikilinks (`[[slug|title]]`)
  - `sites/tasks/intake/unsent-notifications.md` queue (replaced by `--notify`)
  - Branch + PR per task change (replaced by direct sqlite writes)

## Sqlite schema quick-reference

```
tasks table columns:
  id INTEGER PK        title TEXT NOT NULL
  description TEXT     assignee TEXT (Slack ID)
  status TEXT          (open | in_progress | done | carried | cancelled)
  priority TEXT        (low | normal | high | blocker)
  category TEXT        (adhoc | sprint | bug | marketing | …)
  product TEXT         (rapidnative | applighter | letsdeployit | …)
  source TEXT          (slack:<ts> | git:<sha> | adhoc | marketing-morning | …)
  due_date TEXT        (YYYY-MM-DD IST)
  created_at TEXT      updated_at TEXT
  metadata TEXT        (JSON blob for category-specific fields)
```

See `bin/init-tasks.sh` for authoritative schema (with CHECK constraints).

## Related skills

- `bug-tracking` — `#user-testing` observations that are bugs feed both this skill (as `--category=bug` tasks) and bug-tracking's projection
- `leave` — used by Step 7 (fallback approver when Sanket is OOO)
- `eod-nudges` — fires later in the day with leave awareness
- `weekly-wrap` — pulls "what shipped" from `tasks.sh list --status done --due …` + git logs
