# People

**Single source of truth for the Shaper Studio Inc roster.** Every other file that references a teammate should link back here. When someone joins, leaves, or changes role, edit this file — nothing else.

> Replaces: `.env TEAM_USERS`, auto-memory `project_team_roster.md` (the former `marketing/team.md` was retired in the marketing/ cleanup). Those that still exist should mirror this file.

## Roster

| Handle | Name | Role | Kind | Slack ID | Email | Tier |
|---|---|---|---|---|---|---|
| `@agni` | Agni | Bot operator, builder | human | `U0B4FCJ8Z1Q` | agni@shaper.studio | owner |
| `@sanket` | Sanket Sahu | CEO | human | `U09DC8L7PCZ` | sanket@rapidnative.com | superadmin |
| `@suraj` | Suraj Ahmed | CTO | human | `U09DC8MB4KB` | suraj@rapidnative.com | superadmin |
| `@riya` | Riya Sharma | Developer | human | `U09CXCYV7D1` | riya@rapidnative.com | teammate |
| `@rishav` | Rishav Kumar | Developer | human | `U09CUJ9ATM1` | rishav@rapidnative.com | teammate |
| `@russel` | Russel | Video Editor | human | `U09DFJJGS1X` | russel@rapidnative.com | teammate |
| `@famitha` | Famitha | Designer | human | `U09LL9JTDM5` | famitha@rapidnative.com | teammate |
| `@gracey` | Gracey | Community Intern | human | `U0B467S1VEG` | — | teammate |
| `@bot-god` | Bot God | AI agent — full Slack/code/PR/tasks-API access | agent | — | bot-god@rapidnative.com | (n/a — bot) |

## Conventions

- **For actual Slack pings that should notify someone:** use `<@U…>` member-ID form (e.g. `<@U09DC8L7PCZ>`). Plain `@sanket` text won't notify.
- **In drafts / informal references:** `@handle` text is fine ("ping @riya to review").
- **Don't invent handles or guess Slack IDs.** If someone isn't listed here, ask before referencing them.

## Tier capabilities

| Tier | Privileged actions (post publicly · merge to main · push to main · post elsewhere · modify creds) |
|---|---|
| `owner` | Full authority. |
| `superadmin` | Same as owner. Can self-approve. |
| `teammate` | Can request drafts/reads/plans. Cannot self-approve privileged actions — must be approved by owner or a superadmin in the same Slack thread. |
| `unknown` | Refused. Pointed to owner. |

## Leave

Day-by-day OOO entries and team-wide holidays live in the sqlite DB at `~/.config/claude/rapidnative-coach.sqlite` (tables `leave_entries` and `holidays`). Helpers `is_on_leave <@SLACK_ID>`, `is_holiday`, and `is_working_day` in [`../accountability/routines/_lib.sh`](../accountability/routines/_lib.sh) query the DB.

CRUD via shell wrappers in `accountability/routines/`: `leave-add.sh`, `leave-rm.sh`, `leave-list.sh`, `holiday-add.sh`, `holiday-rm.sh`, `holiday-list.sh`. Driven by the `leave` skill at `.claude/skills/leave/SKILL.md`.

## Maintenance

- **Slack ID lookup:** `curl -s -H "Authorization: Bearer $BOT_TOKEN" "https://slack.com/api/users.info?user=U…"` (uses the bot token from `~/.config/claude/rapidnative-coach-slack-bot-token`).
- **When updating:** also update the `TEAM_USERS` and `SUPERADMIN_USERS` lines in `.env` (until the listener migrates to read this file directly).
- **Auto-memory mirror:** `~/.claude/projects/-Users-agni-Documents-rapidclaw/memory/project_team_roster.md` already references this file as canonical. Keep that mirror in sync when you edit here.
