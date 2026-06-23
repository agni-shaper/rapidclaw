# Marketing crew

The 4 people who execute the daily distribution rotation. Drives who gets a section in `morning-tasks.md`.

Format: `<@SLACK_ID>` · handle · active (true|false) · notes

> This file is **scoped to the marketing-automation crew**. The org-wide roster lives in `~/.claude/projects/-Users-agni-Documents-rapidclaw/memory/project_team_roster.md`. Slack IDs below are pulled from that roster.

## Active

- `<@U09DFJJGS1X>` · @russel · active=true · video-cut adjacent posts + community replies

## Inactive (kept for history)

> **TEST MODE — 2026-06-22**: only @russel is active while we validate the per-task layout, enrichment, and blog-routing changes. The other 3 crew will be re-enabled once @russel's flow is verified working end-to-end. Edit the `active=` flag back to `true` to re-add them.

- `<@U09DC8L7PCZ>` · @sanket · active=false · super-admin; covers strategic posts + approvals (re-enable after russel test)
- `<@U09CUJ9ATM1>` · @rishav · active=false · technical posts (engineering depth) (re-enable after russel test)
- `<@U09LL9JTDM5>` · @famitha · active=false · design/asset-driven posts + visual platforms (re-enable after russel test)

## How leave works

Don't mark someone `active=false` for short leave — use `accountability/leave.md` instead. The morning routine calls `is_on_leave <@SLACK_ID>` per crew member and silently skips anyone covered by today's IST date. Long-term reassignment (someone permanently leaves the crew) → flip `active=true` to `active=false` here.
