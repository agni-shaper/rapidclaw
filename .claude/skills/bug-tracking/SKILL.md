---
name: bug-tracking
description: Capture bug reports from any signal source (Slack channels, user-testing observations, customer DMs surfaced by teammates) as `--category=bug` rows in the sqlite `tasks` table via `tasks.sh`. Lightweight projection — most of the heavy lifting is done by `task-management` and `user-testing`.
when_to_load: |
  Load when ANY of the following:
  - User says "report a bug" / "log a bug" / "this is a bug"
  - A `user-testing` observation is classified as a bug (not a UX nit)
  - The 12:15 tasks-cleanup scan finds a bug-flavoured signal
  - Someone replies to a bug-tracker proposal in a thread
voice_source: ../../profile.md
---

# bug-tracking

Thin skill. Since 2026-07-02 the actual bug DB is the sqlite `tasks` table (rows with `category='bug'`), accessed via `accountability/routines/tasks.sh`. This skill ensures the right things land there in the right shape and that the right teammate gets pinged.

## Read these before doing any work

1. **`accountability/routines/tasks.sh help`** — the CRUD API (bugs use `--category=bug`).
2. `.claude/skills/task-management/SKILL.md` — owns the proposal/approval protocol and sqlite conventions.
3. `definitions/people.md` — for assignment.
4. `definitions/products.md` — to map a bug to a product → default lead.

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

1. **De-dupe first.** Check for a matching open bug:
   ```bash
   tasks.sh list --category bug --status open
   ```
   If a match is present, DON'T create a new row. Update the existing task's `description` (append repro count + latest source), and post a Slack ping via `--notify` so the owner sees the recurrence.
   ```bash
   tasks.sh update <id> description="orig text\n\nRe-reported by @handle on 2026-07-02 (source: slack:…)" --notify
   ```
2. **Otherwise, propose a new bug row:**
   ```bash
   tasks.sh add @<lead> <due-date> "<title>" \
     --category bug --priority normal \
     --product <slug> \
     --source slack:<ts> \
     --description "<one-line repro>" \
     --notify
   ```
   For `<lead>`: map product → lead via `definitions/products.md`. If product unclear, leave `--assignee` off and flag "needs triage" in the proposal narrative.
   For `<due-date>`: default `today + 3 working days` for `normal`, sooner for `high`/`blocker`, `today + 2 weeks` for `low`.
3. **Approval path** — teammate reporters go through the `task-management` proposal + super-admin approval flow. Owner / super-admin reports can be applied directly.

## When the daily scan (tasks-cleanup) finds bug-flavoured signals

Pattern (handled by `task-management` skill, which calls this skill for the bug subset):

- `#user-testing` observation classified as bug (per `user-testing` skill's split rule)
- Slack messages elsewhere containing patterns like "this is broken", "throws an error", "can't <verb>"
- Stack traces in any channel
- Customer DMs forwarded by a teammate

Each becomes a proposed `tasks.sh add ... --category=bug ... --notify` invocation in the tasks-cleanup proposal; approval applies all (or a selected subset).

## When the user explicitly reports a bug

1. Capture inline if the report is complete (description + repro + product + reproducibility).
2. If incomplete, ask 1 sharp clarifier: "which product?" or "can you repro from <state>?" Don't ask multiple — annoying.
3. Confirm the captured row back to the reporter with the sqlite id + assignee handle.

## Anti-hallucination guards

1. **Don't classify something as a bug without explicit signal.** "I don't like this color" is not a bug. "This button doesn't fire onClick" is.
2. **Don't invent a stack trace or error message** to make a bug feel concrete. Quote what the user said.
3. **Don't assign to anyone not in `definitions/people.md`.**
4. **Don't dedupe based on superficial similarity.** Two bugs with similar UI but different root causes are two bugs — `--category=bug` rows can coexist for parallel repros of ostensibly the same thing.
5. **Don't skip `tasks.sh list --category bug --status open` before adding.** That's the dedupe check.

## Migration status (since 2026-07-02)

- **Old:** `sites/tasks/intake/bugs.md` markdown, with wikilinks and separate task pages.
- **New:** sqlite `tasks` rows with `category='bug'`. Queryable via `tasks.sh list --category bug`.
- Archival `sites/tasks/intake/bugs.md` stays for history; NOT synced to sqlite.

## Related skills

- `task-management` — calls this skill for the bug subset of cleanup proposals
- `user-testing` — feeds bug signals via its bug-vs-UX split rule
- `repo-edit` — once a bug is being worked, repo-edit owns the branch + PR mechanics for the code fix (NOT for the bug-tracker row itself)
