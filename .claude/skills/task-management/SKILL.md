---
name: task-management
description: Feed `sites/tasks/` (the team's sprint DB) from Slack channels + git logs. Runs the 12:15 IST cleanup proposal flow that turns standup MoMs + EOD posts + user-testing observations + repo commits into proposed sprint mutations the super-admin can approve in #rapidnative-coach.
when_to_load: |
  Load when ANY of the following:
  - Cron routine `tasks-cleanup` fires (12:15 IST Mon-Fri)
  - User asks "what's on my plate today?" / "show me sprint" / "what's blocked?"
  - User asks to add / move / close a task
  - The bot detects a "done T01, T03" claim in a Slack thread reply
voice_source: ../../profile.md
---

# task-management

The skill that owns the bot's relationship with `sites/tasks/`. Two-tier interaction:

> *Tier A — feeder:* this skill watches the world (Slack channels + git logs) and proposes mutations.
> *Tier B — DB:* `sites/tasks/` is the database. Its own scripts (`bin/send-notifications.py`, etc.) emit Slack notifications when tasks change. This skill DOESN'T do that — it just edits the markdown files in the right format.

## Read these before doing any work

1. **`sites/tasks/CLAUDE.md`** — authoritative for sprint sections, bullet format (aliased wikilinks), task-page rule, notification queue conventions. *Required read.* Run `sites-prepare.sh tasks` first if you're going to edit there.
2. `sites/tasks/roles.md` — team handles (cross-check against `definitions/people.md`).
3. `definitions/people.md` — for Slack ID lookups when proposing assignments.
4. `definitions/channels.md` — to know which channel a proposal should post to.
5. `accountability/state/tasks-cleanup-last-run.txt` (and the JSON proposals dir) — for idempotency between runs.

## The daily 12:15 IST cleanup flow

Four signals feed the proposal:

1. **Standup channel** (`C09DF90CQ8Z`) — new MoMs / task assignments / transcripts since last run. Propose new tasks for the sprint.
2. **#eod-updates** (`C0A8Q9HM5BN`) — "done" signals since last run. Propose moves to the sprint's *Done* section.
3. **Git logs** for every linked site under `sites/` since last run. Map commit messages to sprint bullets → propose Done moves (or new tasks if a commit doesn't match anything in flight).
4. **#user-testing** (`C09EU7C87BM`) — new observations since last run. Propose new bug/UX tasks (loops in `bug-tracking` skill).

Step-by-step:

```
0. guard_working_day tasks-cleanup
1. Read accountability/state/tasks-cleanup-last-run.txt → LAST timestamp (default: 36h back).
2. Fetch each signal source for messages/commits since LAST.
3. Compose a structured proposal:
   - <NEW> bullets to add (with slug + handle + priority + tag)
   - <DONE> bullets to move to Done
   - <BLOCKED> bullets to mark blocked
4. Post the proposal to #rapidnative-coach as a TOP-LEVEL message with a clear header:
   *Tasks clean up* <date>
   (this marker is what the channel persona uses to route the reply path)
5. Save the structured proposal to accountability/state/tasks-cleanup-proposal-<reply_ts>.json
6. WAIT for approval reply in the same thread. Default super-admin: <@U09DC8L7PCZ> (Sanket);
   fallback to <@U09DC8MB4KB> (Suraj) if Sanket is on leave (use `is_on_leave`).
7. On approval ("go" / "approve all" / "approve 1,3,5" / "defer"), the listener re-invokes
   this skill with the thread context. Then APPLY:
   - sites-prepare.sh tasks
   - Edit sites/tasks/planning/sprint.md per the approved changes
   - Append entries to sites/tasks/intake/unsent-notifications.md (sites/tasks/CLAUDE.md
     explains this convention — Phase 6's `task-management` cleanup may move this into
     sqlite, but for now keep the markdown-queue contract intact)
   - git add + commit + push on the tasks repo (branch + PR per CLAUDE.md)
   - Post a sync notification to the standup channel
```

## When the user asks "what's on my plate?"

1. `sites-prepare.sh tasks` (idempotent — safe to call every time).
2. Read `sites/tasks/planning/sprint.md`.
3. Filter bullets whose assignee wikilink matches `[[@user_handle]]` (resolve handle from Slack ID via `lookup_handle <U…>`).
4. Group by section (active / blocked / review). Show priorities (P0/P1/P2/P3).
5. Don't include items in the *Done* section unless explicitly asked.

## When the user asks to mutate a task ad-hoc

For ad-hoc changes outside the 12:15 cleanup (e.g. "move T07 to done"):

1. Apply the same flow as Step 7 above (sites-prepare → edit → notification queue → commit + PR).
2. Skip the proposal step IF the sender is owner or superadmin (they implicitly self-approve).
3. Teammate-tier senders → propose + ask for approval from owner / superadmin.

## Anti-hallucination guards

1. **Never invent a task slug.** The slug format is wikilink-aliased: `[[<slug>|<description>]]`. Use existing slugs from `sites/tasks/tasks/` if they exist; create new ones only if there's no match.
2. **Never invent a handle.** Use `definitions/people.md`. If a name shows up in standup MoMs that's not in the roster, ask before assigning.
3. **Never push to `main` on the tasks repo.** Branch + PR per `sites/tasks/CLAUDE.md`. Even if the change is trivial.
4. **Never bypass the notification queue.** Every task-affecting action must append an entry to `sites/tasks/intake/unsent-notifications.md` — that's the only way teammates get pinged. The tasks repo's own cron drains the queue.
5. **Don't auto-apply proposals.** Always wait for explicit approval. Even if the proposal looks trivial.
6. **Don't propose moves to Done without git evidence.** If EOD says "done T03" but git history doesn't show a corresponding commit, flag the discrepancy in the proposal.

## Migration status

- **Today:** runs via `accountability/routines/tasks-cleanup.md` (289 lines). That routine should shrink to ≤80 lines and load this skill (replacement pending — needs side-by-side testing for one cron cycle to verify proposal parity).
- **Phase 3:** sqlite `tasks_cleanup_proposals` table replaces `accountability/state/tasks-cleanup-proposal-*.json`. Routine_runs table tracks invocations.

## Related skills

- `bug-tracking` — `#user-testing` observations that are bugs feed both this skill and bug-tracking
- `leave` — used by Step 6 (fallback approver when Sanket is OOO)
- `eod-nudges` — fires later in the day with leave awareness
- `weekly-wrap` — pulls "what shipped" from `sites/tasks/` Done section + git logs
