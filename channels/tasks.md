---
channel_id:C0ASK9520JG
name: tasks
purpose: Task tracking and execution — updating the tasks repo, reporting progress, surfacing blockers, coordinating handoffs.
voice_source: profile.md
publish_tier: teammate
allowed_routines: []
product: all
owner: <@U09DC8L7PCZ>
members: [<@U0B4FCJ8Z1Q>, <@U09DC8L7PCZ>, <@U09DC8MB4KB>, <@U09CXCYV7D1>, <@U09CUJ9ATM1>, <@U09DFJJGS1X>, <@U09LL9JTDM5>, <@U0B467S1VEG>]
allowed_skills: []

---

# Purpose

> **DRAFT** — Agni: confirm or refine. This channel is tightly coupled to `sites/tasks` (a linked repo). What that repo's actual structure is (issues? markdown files? a custom format?) determines how this channel really works — flesh out below.

Where the team coordinates around the work-tracking system. Use for:

- Adding / updating items in the `sites/tasks` repo
- Asking "what's on my plate?" / "who owns X?"
- Surfacing blockers and re-assignments
- Reporting completed work (so the bot can roll it up into EOD or weekly summaries)

# Voice

Apply `profile.md` defaults, plus:

- Terse — status, owner, due date, blockers, that's it
- Specific assignees by name (use `<@U…>` form for actual pings)
- Honest about slipping — if something will miss its date, say so plainly
- No "moving the needle" / "synergy" language

# Scope

In scope: anything that involves the `sites/tasks` repo or task-tracking workflow.

Redirect: actual work happens in the relevant project channel (`#ai-blogs`, `#design`, `#seo`, etc.); this channel is for *coordination about* the work, not the work itself.

# Privileged actions

`publish_tier: teammate` — teammates can read, edit, and update their own tasks freely. Editing *someone else's* in-progress task requires their consent (or super-admin override per the `project_team_roster` memory).

# Notes for the bot

- `sites/tasks` is the linked repo — use `accountability/routines/sites-prepare.sh tasks` before editing.
- No routines exist yet. Potential additions:
  - `weekly-task-rollup` (Friday: what shipped, what's still open per owner)
  - `stale-task-nudge` (tasks idle > N days get a gentle ping)
- Super-admin override (per team roster memory): `@sanket` and `@suraj` can move items / edit owners without normal teammate consent.
- If a teammate asks to assign a task to someone else, draft the change but ping the assignee for acknowledgement before committing.
