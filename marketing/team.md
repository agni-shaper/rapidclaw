# Marketing crew

The 4 people who execute the daily distribution rotation. Drives who gets a section in `morning-tasks.md`.

Format: `<@SLACK_ID>` · handle · active (true|false) · notes

> This file is **scoped to the marketing-automation crew**. The org-wide roster lives in `~/.claude/projects/-Users-agni-Documents-rapidclaw/memory/project_team_roster.md`. Slack IDs below are pulled from that roster.

## Active

- `<@U09DC8L7PCZ>` · @sanket · active=true · super-admin; covers strategic posts + approvals
- `<@U09CUJ9ATM1>` · @rishav · active=true · technical posts (engineering depth)
- `<@U09DFJJGS1X>` · @russel · active=true · video-cut adjacent posts + community replies
- `<@U09LL9JTDM5>` · @famitha · active=true · design/asset-driven posts + visual platforms

## Inactive (kept for history)

(none yet)

## How leave works

Don't mark someone `active=false` for short leave — use `accountability/leave.md` instead. The morning routine calls `is_on_leave <@SLACK_ID>` per crew member and silently skips anyone covered by today's IST date. Long-term reassignment (someone permanently leaves the crew) → flip `active=true` to `active=false` here.
