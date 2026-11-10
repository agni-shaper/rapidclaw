---
name: bug-tracking
description: Capture bug reports from any signal source (Slack channels, user-testing observations, customer DMs surfaced by teammates) as tasker items (tasks.rapidnative.com). Lightweight skill — most of the heavy lifting is done by `task-management` and `user-testing`; this skill is the bug-specific projection.
when_to_load: |
  Load when ANY of the following:
  - User says "report a bug" / "log a bug" / "this is a bug"
  - A `user-testing` observation is classified as a bug (not a UX nit)
  - The 12:15 tasks-cleanup scan finds a bug-flavoured signal
  - Someone replies to a bug-tracker proposal in a thread
voice_source: ../../profile.md
---

# bug-tracking

Thin skill. Bugs are tasker items like any other work (tasks.rapidnative.com, through `accountability/routines/tasker.sh`; see the `task-management` skill for the calls and rules). This skill makes sure the right things become bug items, in the right shape, owned by the right person.

## Read these before doing any work

1. `.claude/skills/task-management/SKILL.md` — tasker calls, where items go, what the coach applies directly.
2. `definitions/products.md` — which product (tasker project) the bug belongs to.
3. `definitions/people.md` — Slack ID → tasker id for the owner.

## Bug item shape

- **Project:** `RapidNative` or `LetsDeployIt` (Applighter → RapidNative).
- **Where:** the project's Inbox, unless an obviously matching track exists (`find_nodes` the surface: e.g. "Agent", "App Builder", "Hosting").
- **Title:** what breaks, for whom, in plain words: `Pricing toggle does not render on mobile Safari`.
- **Body:**
  ```
  What happens: <quote the reporter; no invented errors>
  Repro: <steps or "not yet reproduced">
  Seen by: <who, how many, paying user?>
  Source: <Slack permalink or issues-log row>
  Reported: <YYYY-MM-DD>
  ```
- **Priority** (`P0` … `P5`):
  - `P0` — production broken, blocking users, revenue at risk
  - `P1` — user-facing feature broken, repro'd by ≥2 people
  - `P2` — repro'd once, minor breakage, has a workaround
  - `P3` — edge case, hard to repro, low impact

  Unsure → P2 (better to under-rank and let the owner raise it). The coach never sets P0 on its own; it files P1 and lists "raise to P0?" for Sanket under *Needs a human*.
- **Owner:** the person the standup or reporter named; else unassigned (Rishav or Riya pick up engineering bugs).

## When a new bug is captured

1. **De-dupe.** `find_nodes` with the surface + symptom words, then `find_duplicates` with the proposed title. If it matches an open item, `add_comment` the new sighting (who, when, link) instead of creating a second one.
2. **Create** the item with the shape above (`create_item` via stdin, `--project`).
3. **Tell the reporter** in their thread: item link + owner (or "unassigned, Rishav/Riya to pick up").

## When the daily scan (tasks-cleanup) finds bug-flavoured signals

Signals: a `#user-testing` observation classified as a bug (per the `user-testing` skill's split rule), "this is broken" / "throws an error" / "can't <verb>" messages in the standup, stack traces, customer reports forwarded by a teammate.

Each becomes a new item or a comment on an existing one, applied directly and listed in the `*Tasks update*` digest.

## When the user explicitly reports a bug

1. Capture inline if the report is complete (description + repro + which product).
2. If incomplete, ask 1 sharp clarifier: "which product?" or "can you repro it from <state>?". Don't ask multiple — annoying.
3. Confirm back to the reporter with the item link + owner.

## Anti-hallucination guards

1. **Don't classify something as a bug without explicit signal.** "I don't like this color" is not a bug. "This button doesn't fire onClick" is.
2. **Don't invent a stack trace or error message** to make the bug feel concrete. Quote what the user said.
3. **Don't assign to anyone without a tasker id in `definitions/people.md`.**
4. **Don't dedupe based on superficial similarity.** Two bugs with similar UI but different root causes are two bugs.

## Storage

Tasker only (since 2026-11-10). The old `sites/tasks/intake/bugs.md` lived in the retired markdown tasks repo; don't write there, and don't mirror bugs into the coach's sqlite.

## Related skills

- `task-management` — calls this skill for the bug subset of cleanup proposals
- `user-testing` — feeds bug signals
- `repo-edit` — once a bug is being worked, repo-edit owns the branch + PR mechanics
