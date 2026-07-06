---
name: tasks
description: Owns the tasks CRUD contract (`.claude/skills/tasks/bin/tasks.sh` → sqlite `tasks` table) AND the daily task-cleanup pipeline. All other skills that touch tasks (bug-tracking, user-testing, task-assistance, growth-marketing) go through this skill's `tasks.sh` contract — see §"For skills that call `tasks.sh`".
when_to_load: |
  Load when ANY of the following:
  - Cron routine `tasks-cleanup` fires (12:15 IST Mon-Fri)
  - User asks "what's on my plate today?" / "show me my tasks" / "what's blocked?"
  - User asks to add / assign / move / close / cancel a task
  - The bot detects a "done #42" / "done T01" claim in a Slack thread reply
  - Another skill needs to read or mutate the `tasks` table
voice_source: ../../profile.md
---

# tasks

Owns the bot's relationship with the **sqlite `tasks` table** (single source of truth for all tasks since 2026-07-02). Two-tier interaction:

> *Tier A — feeder:* this skill watches the world (Slack channels + git logs) and proposes mutations.
> *Tier B — DB:* the sqlite `tasks` table at `~/.config/claude/rapidnative-coach.sqlite`, accessed via the dispatcher `.claude/skills/tasks/bin/tasks.sh`.

**All writes go through `tasks.sh`.** Never hand-write SQL. Never edit anything under `sites/tasks/` (archival — see "Migration" at the bottom).

## Read these before doing any work

1. **`.claude/skills/tasks/bin/tasks.sh help`** — the CRUD API surface. Six subcommands (add / list / get / update / done / rm) plus global flags (`--json` / `--notify` / `--channel` / `--force`).
2. `definitions/people.md` — Slack ID ↔ @handle lookups. Source of truth.
3. `definitions/channels.md` — where a proposal should post (default: `#rapidnative-coach` `C0B4HG16QP3`).
4. `bin/init-tasks.sh` — the sqlite schema (12 columns + CHECK constraints on status/priority). Read to know what fields exist.
5. `sqlite ~/.config/claude/rapidnative-coach.sqlite` `routine_runs` — last successful `tasks-cleanup` run for idempotency between fires.

## For skills that call `tasks.sh`

Stable anchor for other skills (bug-tracking, user-testing, task-assistance, growth-marketing/social-engagement, etc.). Link here rather than duplicating.

1. **Entry point is `.claude/skills/tasks/bin/tasks.sh`.** Never bare SQL. Never call the sibling `task-<verb>.sh` scripts directly — they're implementation detail.
2. **`--notify` is mandatory on real writes** (`add` / `update` / `done` / `rm`). Without it the row lands in sqlite but the `#tasks` ledger stays silent, and teammates get no signal. Omit only when the caller explicitly wants a silent write (e.g. batched summary posted separately).
3. **`--channel` follows the routing rules in §"Task-channel routing" below.** Default is `#tasks` (`C0ASK9520JG`); only override when a routing rule applies (e.g. marketing-morning tasks land in `#rn-coach-social`). Ad-hoc user requests should NOT override the channel — the ledger post always goes to the rule-selected channel, never to the requesting thread. If you also need to confirm back to the user's originating thread, use the **two-write pattern**: `--notify` sends the ledger post to the routed channel; a separate `slack-post.sh` sends the confirmation reply to the origin thread (include the sqlite id + `slack_message_url` from the row so the user can click through).
4. **Dedupe with `list` before `add`.** Scope with `--category` and/or `--product`. A same-title open row → update the existing task (append repro/context), don't create a duplicate.
5. **Roster lookups go through `definitions/people.md`.** Never invent a handle or Slack ID. If a name in a message isn't in the roster, ASK before assigning.
6. **Respect the leave guard.** `tasks.sh add` refuses (exit 2) to assign a task whose due date lands on a leave day for the assignee. Override with `--force` only when you can explain WHY in the proposal.
7. **Cancellation is soft.** `tasks.sh rm <id>` sets `status='cancelled'` — never a hard DELETE. Preserves the audit trail.
8. **Category is the namespace.** Marketing → `--category=marketing`; bugs → `--category=bug`; sprint items → `--category=sprint`; default `adhoc`. Query with `tasks.sh list --category X --status open` to scope.
9. **Never invent a task ID.** Look one up via `tasks.sh list` (filtered). If the title match is ambiguous, ask which.
10. **Approval gate applies to teammate-tier senders** for any mutation. Owner / super-admins can apply directly.

## Task-channel routing

The `--notify` ledger post goes to `#tasks` by default. Some source routines need it to land elsewhere — the routing table below is the authoritative source. Callers pass `--channel <ID>` when invoking `tasks.sh` to override.

### Allowed override channels

| Channel | ID | When it's the target |
|---|---|---|
| `#tasks` | `C0ASK9520JG` | **Default** — all mutations unless a rule overrides |
| `#rn-coach-social` | `C0B6Q8TUVL2` | Marketing-morning tasks for the 4-person crew (Sanket, Famitha, Russell, Rishav) |

### Routing rules (in priority order)

1. **`marketing-morning:*` source** → `#rn-coach-social` (`C0B6Q8TUVL2`). Every task generated by `accountability/routines/gen-marketing-morning.py` regardless of product (RN + AL + LDI all land in the same channel — the crew triages from one ledger).
2. **Everything else** → default `#tasks`. Ad-hoc adds, bug rows, tasks-cleanup applies, blog amplification updates, etc.

### For skills that add rules

- Add a row to the "Allowed override channels" table + a rule in the numbered list above.
- Update the source routine's shell/python to pass `--channel <ID>` when the rule applies.
- Ensure the destination channel's persona (`channels/<name>.md`) lists this routine in `allowed_routines` — the listener uses that to gate downstream reactions.
- Ensure the destination channel has (a) the bot as a member, (b) all intended assignees as members. Missing either → the ledger post silently fails or is invisible.

### Verification before shipping a new rule

```bash
# 1. Bot in channel?
tokens=$(cat ~/.config/claude/rapidnative-coach-slack-bot-token)
curl -s -H "Authorization: Bearer $tokens" \
  "https://slack.com/api/conversations.members?channel=<ID>&limit=200" | jq '.members'

# 2. Test post (use --dry-run first on the calling routine)
```

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
   command verbatim. Each --notify posts to `#tasks` (see §"For skills that call `tasks.sh`").
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
3. **After a successful `tasks.sh add`, post a short confirmation reply in the ORIGINATING thread** — NOT a second `tasks.sh add` and NOT a channel override. Fetch the task's `slack_message_url` from sqlite so the user can click through:
   ```bash
   URL=$(sqlite3 ~/.config/claude/rapidnative-coach.sqlite \
     "SELECT slack_message_url FROM tasks WHERE id=$NEW_ID;")
   accountability/routines/slack-post.sh <origin_channel> <origin_thread_ts> \
     "Assigned T${NEW_ID} → <@${sid}> · due ${due} · ${cat}/${prod} · ${prio}. See ${URL}"
   ```
   This preserves the two-write pattern (see §"For skills that call `tasks.sh`" item 3).
4. **Look up existing tasks first** when the message references an existing task:
   - "mark #42 done" → `tasks.sh done 42 --notify`
   - "reassign #42 to @rishav" → `tasks.sh update 42 assignee=@rishav --notify`
   - "cancel that banner task" → `tasks.sh list --status open` → find matching → `tasks.sh rm <id> --notify`

## Cleanup-flow-specific guards

Beyond the CRUD contract in §"For skills that call `tasks.sh`", the daily cleanup flow has its own guards:

1. **Don't skip the approval gate** for teammate-tier senders. Even for trivial mutations. The gate exists to prevent unilateral dumps.
2. **Don't propose Done based on title guesses.** If EOD says "done banner" and there are two open banner tasks, list both and ask before proposing done on either.
3. **Don't propose Done without git evidence** for commit-derived done moves. Flag the discrepancy in the proposal if the commit message names a task that has no matching sqlite row.

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

## Migration status (since 2026-07-02)

- **Old:** `sites/tasks/` markdown DB (aliased-wikilink bullets, task pages, branch + PR per change, `intake/unsent-notifications.md` queue). Replaced.
- **New:** sqlite `tasks` table + `tasks.sh` dispatcher + `--notify` for Slack. This file.
- **What happens to `sites/tasks/`:** archival. No new writes. Existing task pages stay in the repo as history but are NOT synced to sqlite. Bulk migration is a possible follow-up.

## Related skills

- `bug-tracking` — bug-shaped signals become `--category=bug` rows via `tasks.sh`. Follows §"For skills that call `tasks.sh`".
- `user-testing` — feeds bug signals; observations that are bugs also flow through `bug-tracking` → `tasks.sh`.
- `task-assistance` — reads tasks (`tasks.sh get <id> --json`) to help assignees; never mutates.
- `growth-marketing` (social-engagement) — creates marketing tasks via `tasks.sh add --category=marketing`.
- `leave` — used by Step 7 above (fallback approver when Sanket is OOO); also enforces the leave guard in `tasks.sh add`.
- `eod-nudges` — fires later in the day with leave awareness.
- `weekly-wrap` — pulls "what shipped" from `tasks.sh list --status done --due …` + git logs.
