---
name: task-management
description: The coach's link to tasker (tasks.rapidnative.com), the team's tracker. Turns standup MoMs, EOD posts, merged PRs and #user-testing observations into tasker changes, applies the evidence-backed ones directly, posts one digest to #tasks, and answers "what's on my plate?" from tasker.
when_to_load: |
  Load when ANY of the following:
  - Cron routine `tasks-cleanup` fires (12:15 IST Mon-Fri)
  - Someone asks "what's on my plate?" / "what's blocked?" / "who owns X?" / "what's left on Y?"
  - Someone asks to add / move / close / reassign a task, or "add it to the tracker"
  - A reply lands in a `*Tasks update*` digest thread (a correction: "undo 3", "that's Riya's", "not done yet")
  - Another routine routes work into the tracker (gtm-weekly-pick approvals, user-testing promotions, bug reports)
voice_source: ../../profile.md
---

# task-management

**Tasker is the team's only tracker.** All planned and ongoing work for RapidNative and LetsDeployIt lives there, and the team works in it every day. The coach reads and writes it through one wrapper; it never keeps tasks in a local file, in sqlite, or in a markdown repo. (The old `sites/tasks` markdown repo, RapidNative/tasks, was retired on 2026-11-10 and is archived. Don't read it or write to it.)

## Calling tasker

```bash
TK=accountability/routines/tasker.sh
$TK tools                                    # every tool, one line each
$TK tools create_item                        # one tool's schema: read it before first use in a session
$TK find_nodes '{"query":"stripe webhook"}'  # search every project by title words or id
$TK get_node '{"id":"item-…"}'               # body, owner, status, comments, links
$TK get_tree '{"project":"RapidNative"}'     # the whole tree (programs → tracks → items, with owner/status)
$TK list_stale '{"days":5}'                  # in-progress or P0/P1 items nobody touched
echo '{"title":"…","body":"…"}' | $TK create_item - --project RapidNative
$TK update_node '{"id":"item-…","status":"done"}'
$TK add_comment '{"nodeId":"item-…","markdown":"Merged in RapidNative/rapidnative-website#2940"}'
```

Pass long JSON on stdin (`-`) and build it with `python3 -c 'import json…'` or a heredoc, never by hand-escaping. Every change shows in tasker as "Claude Code for Agni" with undo, and tasker notifies the item's owner and followers in-app. Item link for Slack: `https://tasks.rapidnative.com/items/<id>`.

## The model

- **Projects:** `RapidNative` and `LetsDeployIt`. Applighter and company-wide work go in `RapidNative`.
- **Tree:** Program → Track → Item. New items go to the project's **Inbox** track (pass `--project` and no parent) unless the source names a track or an obviously matching track exists (`find_nodes` the topic; e.g. user-testing UX issues → track "User testing").
- **Status:** `todo`, `doing`, `research`, `done`, `parked`, `archived`. Waiting on someone outside the tree is `set_waiting_on`, not a status.
- **Priority:** `P0` … `P5` exactly. P0 = this week, drop everything. Default for new work is P2; only a standup "P0 / ship today / drop everything" or a paying-user outage makes P0.
- **Owner:** whoever does the work next. Map Slack → tasker with the `Tasker` column of `definitions/people.md`. Someone without a tasker id: leave unassigned and name them in the body. Never assign "to have an owner".
- **Evidence:** PRs, commits and Slack permalinks go in as links in the body or a comment. Progress is a comment, newest last; tasker dates them.

## Rules (from the team's tracker conventions)

1. **Search before creating.** `find_nodes` with 2-3 distinctive words, then `find_duplicates` with the proposed title. If something matches, comment on it instead of creating a second item.
2. **One item per piece of work.** Why and evidence in the body; progress in comments.
3. **Never delete.** To drop something, comment why, then `update_node status=archived`.
4. **No secrets.** Customer names and details are fine (the workspace is team-only); tokens, passwords and env values are not.
5. **Don't create programs or tracks.** Ask in the digest if an area has no home.
6. **Former members** (`definitions/people.md` → *Former members*) never get assigned or pinged.

## What the coach applies directly vs. leaves for a human

Approved by Sanket on 2026-11-10: tasker has undo and an activity log, so the coach no longer waits for in-thread approval. It applies what the evidence supports and lists the rest for a human.

**Apply directly:**
- A **comment** on the matching item for any EOD bullet, standup mention or PR that clearly refers to it (quote the source, link it).
- **`done`** when a merged PR closes the item (link it), or the item's owner posts a done-verb EOD bullet that restates the item ("shipped", "live", "merged", "deployed", "fixed", "published") — high confidence only.
- **`doing`** when the owner says they started it ("working on", "picked up", "PR up") and it is `todo`.
- **New item** in the product's Inbox for an explicit standup assignment (`<@U…> please …`, a MoM bullet under a person), a reproducible bug, or a user-testing issue past its promotion threshold. Owner = the person named; else unassigned. Body: what, why, source permalink, date.

**List for a human (don't apply):**
- Medium/low-confidence matches ("might be item-X").
- Reassigning or re-prioritising someone else's item, raising anything to P0, archiving, moving between tracks.
- Work that conflicts with what tasker says (EOD says done, item has an open blocker or no PR).
- Decisions surfaced in standup: list them; Sanket records them in a doc.

## The daily 12:15 cleanup (`tasks-cleanup` routine)

The routine prompt (`accountability/routines/tasks-cleanup.md`) owns the steps. In short: gather the four signals since the last run → match each against tasker → apply per the rules above → post **one** `*Tasks update*` digest to `#tasks` (`C0ASK9520JG`) → record the run.

Signals:
1. **Standup** (`C09DF90CQ8Z`): MoMs, assignments, decisions.
2. **#eod-updates** (`C0A8Q9HM5BN`): done / started signals.
3. **Merged PRs** since the last run: `gh search prs --owner RapidNative --merged ">=<date>" --json …` (plus `--owner tinbase`, `--owner lifo-sh`). A PR is the strongest evidence.
4. **#user-testing** (`C09EU7C87BM`): bugs and UX papercuts (loops in `bug-tracking` and `user-testing`).

## Corrections in a digest thread

A reply in a `*Tasks update*` thread is a correction from a teammate. Read the run's record (`db_query "SELECT proposal_json FROM tasks_cleanup_proposals WHERE reply_ts='<thread_ts>';"`), then do what they ask: revert a status (`update_node`), reassign, archive a wrongly created item (comment why first), or apply one of the "needs a human" rows. Reply in the thread with what changed and the item links. Teammates may correct items they own; changes to someone else's item need that person, Sanket or Agni.

## "What's on my plate?" and other reads

1. Resolve the asker: Slack ID → `Tasker` id in `definitions/people.md`.
2. `get_tree` for the relevant project(s) (`{"project":"all"}` if unsure) and filter the outline to their open items (`todo`, `doing`, `research`), grouped by status, P0 first. Include `list_stale` hits that are theirs.
3. Link each item. Don't include `done` unless asked.

"Who owns X?" → `find_nodes` → `get_node`. "What's left on Y?" → `find_nodes` for the program/track, then its open items from `get_tree`.

## Ad-hoc changes asked in Slack

"Add X", "mark item-… done", "move this to Rishav": same rules. A teammate's own item or a new item: apply and confirm with the link. Someone else's item: owner, Sanket or Agni must agree in the thread first.

## Anti-hallucination guards

1. **Never invent an item id.** Only use ids returned by `find_nodes` / `get_tree` / `create_item`.
2. **Never invent a person.** Use `definitions/people.md`; unknown names stay unassigned and get flagged.
3. **Never mark done without evidence** you can link (PR, commit, EOD permalink).
4. **Quote, don't embellish.** Bodies and comments quote the source; no invented scope.

## Related skills

- `bug-tracking` — the bug subset: format and priority rules for bug items
- `user-testing` — promotes `issues-log.md` rows into tasker items
- `leave` — don't assign new work to someone on leave today without flagging it
- `weekly-wrap` — reads the run records + tasker for "what shipped"
