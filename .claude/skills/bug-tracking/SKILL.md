---
name: bug-tracking
description: Capture bug reports from any signal source (Slack channels, user-testing observations, customer DMs surfaced by teammates) as `--category=bug` rows in the sqlite `tasks` table via `tasks.sh`. Thin projection over the `tasks` skill — this skill defines bug-specific field mapping, priority defaults, and the UX-vs-bug split; the `tasks` skill owns the CRUD contract.
when_to_load: |
  Load when ANY of the following:
  - User says "report a bug" / "log a bug" / "this is a bug"
  - A `user-testing` observation is classified as a bug (not a UX nit)
  - The 12:15 tasks-cleanup scan finds a bug-flavoured signal
  - Someone replies to a bug-tracker proposal in a thread
voice_source: ../../profile.md
---

# bug-tracking

Thin skill. Since 2026-07-02 the actual bug DB is the sqlite `tasks` table (rows with `category='bug'`), accessed via the `tasks` skill. This skill defines what "bug-shaped" looks like and how it maps into `tasks` columns.

## Read these before doing any work

1. **`.claude/skills/tasks/SKILL.md` § "For skills that call `tasks.sh`"** — the CRUD contract this skill obeys. Do not repeat any of it here.
2. `definitions/people.md` — for assignment.
3. `definitions/products.md` — to map a bug to a product → default lead.

## Bug fields → sqlite columns

Bugs are `tasks` rows with `category='bug'`. Field mapping:

| Bug concept | sqlite column | Example |
|---|---|---|
| Short title | `title` | `Pricing toggle doesn't render on mobile` |
| Priority | `priority` | `blocker` (=P0) · `high` (=P1) · `normal` (=P2) · `low` (=P3) |
| Product | `product` | `rapidnative` · `applighter` · `letsdeployit` |
| Assignee | `assignee` (Slack ID) | resolved via `lookup_slack_id @handle` |
| Reproduction detail | `description` | one-line repro + optional stack trace snippet |
| Where it came from | `source` | `slack:1720000000.123` · `user-testing:2026-07-02-row3` · `dm:<person>` |
| First reported date | `created_at` | auto-set by sqlite |

## Priority defaults

- `blocker` (P0) — production broken, blocking users, revenue at risk
- `high` (P1) — user-facing feature broken, repro'd by ≥2 people
- `normal` (P2) — repro'd once, minor breakage, has workaround
- `low` (P3) — edge case, hard to repro, low impact

If unsure → `normal`. Better to under-rank and let the owner upgrade than over-rank.

## When a new bug is captured

Follow the `tasks` skill's dedupe rule (§"For skills that call `tasks.sh`" item 4). The bug-specific query:

```bash
tasks.sh list --category bug --status open
```

If a match is present, update the existing row's `description` (append repro count + latest source) via `tasks.sh update <id> --notify`. Otherwise, propose a new row:

```bash
tasks.sh add @<lead> <due-date> "<title>" \
  --category bug --priority normal \
  --product <slug> \
  --source slack:<ts> \
  --description "<one-line repro>" \
  --notify
```

- **`<lead>`:** map product → lead via `definitions/products.md`. If product unclear, leave `--assignee` off and flag "needs triage" in the proposal narrative.
- **`<due-date>`:** default `today + 3 working days` for `normal`, sooner for `high`/`blocker`, `today + 2 weeks` for `low`.
- **Approval:** teammate reporters go through the `tasks` skill's proposal + super-admin approval flow. Owner / super-admin reports apply directly.

## When the daily scan (tasks-cleanup) finds bug-flavoured signals

Pattern (handled by the `tasks` skill, which calls this skill for the bug subset):

- `#user-testing` observation classified as bug (per `user-testing` skill's split rule)
- Slack messages elsewhere containing patterns like "this is broken", "throws an error", "can't <verb>"
- Stack traces in any channel
- Customer DMs forwarded by a teammate

Each becomes a proposed `tasks.sh add ... --category=bug ... --notify` invocation in the tasks-cleanup proposal; approval applies all (or a selected subset).

## When the user explicitly reports a bug

1. Capture inline if the report is complete (description + repro + product + reproducibility).
2. If incomplete, ask 1 sharp clarifier: "which product?" or "can you repro from <state>?" Don't ask multiple — annoying.
3. Confirm the captured row back to the reporter with the sqlite id + assignee handle.

## Bug-specific guards

The CRUD contract (dedupe, roster lookups, leave guard, `--notify`, etc.) lives in the `tasks` skill's anchor section. Bug-tracking adds these:

1. **Don't classify something as a bug without explicit signal.** "I don't like this color" is not a bug. "This button doesn't fire onClick" is.
2. **Don't invent a stack trace or error message** to make a bug feel concrete. Quote what the user said.
3. **Don't dedupe based on superficial similarity.** Two bugs with similar UI but different root causes are two bugs — `--category=bug` rows can coexist for parallel repros of ostensibly the same thing.

## Related skills

- `tasks` — owns the CRUD contract this skill obeys; also calls this skill for the bug subset of cleanup proposals
- `user-testing` — feeds bug signals via its bug-vs-UX split rule
- `repo-edit` — once a bug is being worked, repo-edit owns the branch + PR mechanics for the code fix (NOT for the bug-tracker row itself)
