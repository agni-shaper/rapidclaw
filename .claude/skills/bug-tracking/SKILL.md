---
name: bug-tracking
description: Capture bug reports from any signal source (Slack channels, user-testing observations, customer DMs surfaced by teammates) into `sites/tasks/intake/bugs.md`. Lightweight skill — most of the heavy lifting is done by `task-management` and `user-testing`; this skill is the bug-specific projection.
when_to_load: |
  Load when ANY of the following:
  - User says "report a bug" / "log a bug" / "this is a bug"
  - A `user-testing` observation is classified as a bug (not a UX nit)
  - The 12:15 tasks-cleanup scan finds a bug-flavoured signal
  - Someone replies to a bug-tracker proposal in a thread
voice_source: ../../profile.md
---

# bug-tracking

Thin skill. The actual bug DB is `sites/tasks/intake/bugs.md`; this skill ensures the right things land there in the right format and that the right teammate gets pinged.

## Read these before doing any work

1. **`sites/tasks/CLAUDE.md`** — bullet format conventions for `intake/bugs.md`.
2. `sites/tasks/intake/bugs.md` (if present) — existing bug list (to avoid dupes).
3. `definitions/people.md` — for assignment + ping resolution.

## Bug-format spec

Reuses the tasks-repo bullet format from `sites/tasks/CLAUDE.md`:

```
- [[<bug-slug>|<short description>]] - <priority> - [[@assignee]] - reported <YYYY-MM-DD> #bug [#frontend|#backend|#mobile|#infra]
  Details: <one-line reproduction summary>
  Source: <link to Slack thread or user-testing log row>
```

Priority defaults:
- `P0` — production broken, blocking users, revenue at risk
- `P1` — user-facing feature broken, repro'd by ≥2 people
- `P2` — repro'd once, minor breakage, has workaround
- `P3` — edge case, hard to repro, low impact

If unsure → P2 (better to under-rank and have the owner upgrade than over-rank).

## When a new bug is captured

1. **De-dupe.** Read existing `bugs.md`. Does this match anything open? If yes, increment "Reported by" / "Last seen" on the existing row; don't create a new one.
2. **Slug.** Generate a kebab-case slug from the description (e.g. "pricing-toggle-doesn't-render-on-mobile"). Match the tasks-repo task-page rule.
3. **Assign.** Use `definitions/products.md` to map the bug to a product → lead handle. If unclear, leave unassigned and flag for triage.
4. **Append to `sites/tasks/intake/bugs.md`** with the format above.
5. **Append a notification entry** to `sites/tasks/intake/unsent-notifications.md` (per `sites/tasks/CLAUDE.md`) so the assignee gets pinged when the next sync drain runs.
6. **Source-prep first.** `sites-prepare.sh tasks` before any edit (per CLAUDE.md "Linked projects").

## When the daily scan (tasks-cleanup) finds bug-flavoured signals

Pattern (handled by `task-management` skill, which calls this skill for the bug subset):

- `#user-testing` observation classified as bug (per `user-testing` skill's split rule)
- Slack messages elsewhere containing patterns like "this is broken", "throws an error", "can't <verb>"
- Stack traces in any channel
- Customer DMs forwarded by a teammate

Each becomes a proposed row in the tasks-cleanup proposal; approval applies all (or selected subset).

## When the user explicitly reports a bug

1. Capture inline if the report is complete (description + repro + which product).
2. If incomplete, ask 1 sharp clarifier: "which product?" or "can you repro it from <state>?". Don't ask multiple — annoying.
3. Confirm the captured row back to the reporter with the slug + assignee.

## Anti-hallucination guards

1. **Don't classify something as a bug without explicit signal.** "I don't like this color" is not a bug. "This button doesn't fire onClick" is.
2. **Don't invent a stack trace or error message** to make the bug feel concrete. Quote what the user said.
3. **Don't assign to anyone not in `definitions/people.md`.**
4. **Don't dedupe based on superficial similarity.** Two bugs with similar UI but different root causes are two bugs.

## Migration status

- **Today:** runs as part of `tasks-cleanup` (no separate routine). `sites/tasks/intake/bugs.md` is the existing DB.
- **Phase 3:** sqlite `bug_reports` table; `bugs.md` becomes a projection.

## Related skills

- `task-management` — calls this skill for the bug subset of cleanup proposals
- `user-testing` — feeds bug signals
- `repo-edit` — once a bug is being worked, repo-edit owns the branch + PR mechanics
