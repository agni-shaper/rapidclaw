# Marketing automation (OpenClaw)

Daily distribution-team task automation for the 4-person marketing crew (@sanket, @rishav, @russel, @famitha). Lives alongside the rest of `rapidnative-coach`; reuses the bot's Slack helpers, leave file, working-day guard, and launchd scheduling.

## The daily cycle

```
07:00 IST (Mon–Fri)                     19:30 IST (Mon–Fri)
┌────────────────────────────┐         ┌─────────────────────────────┐
│ marketing-morning routine  │         │ marketing-evening routine   │
│                            │         │                             │
│ • guard_working_day        │         │ • guard_working_day         │
│ • read sprint.md (today)   │         │ • reactions.get on AM msg   │
│ • read evening-tasks.md    │         │ • mark ✅/⬜ in evening-     │
│   (carryover)              │         │   tasks.md                  │
│ • skip on-leave crew       │         │ • compute carryover queue   │
│ • expand templates per     │         │ • append row to tracker.md  │
│   person × current w-slot  │         │ • post EOD recap in Slack   │
│ • write morning-tasks.md   │         │                             │
│ • post to #marketing-      │         │                             │
│   automation, save ts      │         │                             │
└────────────────────────────┘         └─────────────────────────────┘
```

Completion capture: each crew member **replies in the AM post's thread** as they finish tasks. The evening routine parses thread replies via `conversations.replies`. Two reply shapes work:

- **Specific tasks:** `done with T01, T03` / `finished T02` / `T01-T03 done` — marks those specific T-IDs done; the rest carry over.
- **All-done shortcut:** `all done` / `done everything` / `finished all` — marks the crew member's entire list done.

A reply only counts as a completion claim if it contains a "done" keyword (`done`, `finished`, `complete`, `wrapped`, `shipped`, `posted`, ✅, `:white_check_mark:`). Questions, blockers, and chatter are ignored. The latest claim from each crew member is unioned across multiple thread replies.

Unmarked tasks per crew member roll into tomorrow's carryover queue **at the task level** (not all-or-nothing). A crew member who finishes 3 of 5 only carries 2 forward.

## Files

| File | What it is | Edited by |
|---|---|---|
| `config.md` | Domains, mailboxes, search queries, channel routing | Human |
| `team.md` | The 4 crew Slack IDs + active flag | Human |
| `accounts.md` | Per-person × per-platform × 4 numbered accounts | Human (fill TBDs!) |
| `rotation.md` | How ISO week maps to w1..w4 slot | Human (rare) |
| `task-templates.md` | TPL-* reusable task blocks | Human |
| `sprint.md` | 7-day plan, rolled forward each Friday | Human |
| `morning-tasks.md` | Today's per-person AM list | **Routine** (overwritten) |
| `evening-tasks.md` | EOD snapshot + tomorrow's carryover | **Routine** (overwritten) |
| `tracker.md` | Append-only completion history | **Routine** (appends) |
| `.state/morning-ts-YYYY-MM-DD` | Slack `ts` of today's AM post | **Routine** |

## Common operations

**Add a new crew member.** Edit `team.md` (new line, `active=true`, real Slack ID) → add a section in `accounts.md` for them (4 numbered accounts per platform). Done.

**Update the sprint.** Friday afternoon: open `sprint.md`, replace next week's date headings, list template IDs per day. The routine refuses to run if today's date isn't a heading.

**Mark someone on leave.** Add a line to `accountability/leave.md` (the org-wide leave file, NOT a marketing-local one). The morning routine calls `is_on_leave` and skips them silently.

**Add a new platform.** Edit `task-templates.md` (new `TPL-FOO` block) → add a `FOO` row in every person's `accounts.md` table → reference `TPL-FOO` in `sprint.md` on whichever day it should fire.

**Force-regenerate today's AM list.** Delete `.state/morning-ts-YYYY-MM-DD`, then `accountability/routines/run.sh marketing-morning`.

## Slack message format

The AM post is one top-level message in `#marketing-automation` (`C0BBQ7PV34N`). One subsection per active crew member. Each subsection has a 🔴 Carryover block (if any) then a 🟢 New today block. Skipped (on leave) crew is noted at the top. The bot doesn't `@`-ping each person on the top-level message — that would alert all 4 every morning whether or not they had carryover. Pings live inside per-section threads if escalation is needed.

The EOD post is a thread-reply on the AM message — short recap (N done / M carried / K on leave) and the Slack thread URL of the AM message for context.

## Where things break (and how to tell)

| Symptom | Likely cause | Fix |
|---|---|---|
| 07:00 came + went, no Slack post | Holiday or weekend | Check `accountability/holidays.md`; weekends are intentional |
| Post fires but is full of `TBD` | `accounts.md` not filled | Fill real account handles in `accounts.md` |
| "Today's date not found in sprint.md" | Sprint not rolled forward | Edit `sprint.md` to add today's date heading |
| Evening routine says "no AM post today" | `.state/morning-ts-<today>` missing | Morning routine never ran successfully — check `/tmp/rapidnative-coach-marketing-morning.log` |

## Compatibility notes

This system **reuses** the existing rapidnative-coach plumbing — no new infrastructure:

- Slack: `accountability/routines/slack-post.sh`, bot token at `~/.config/claude/${BOT_SLUG}-slack-bot-token`
- Leave: `accountability/leave.md` (the canonical org-wide file)
- Working-day / holiday: `accountability/routines/_lib.sh` (`guard_working_day`, `is_on_leave`)
- Team roster: `~/.claude/projects/-Users-agni-Documents-rapidclaw/memory/project_team_roster.md`
- Scheduler: launchd plists in `launchd/`, auto-loaded by `launchd/install.sh`

The marketing crew is intentionally **separate from `sites/tasks/`** (the team's canonical tracker). Daily rotation tasks are high-volume and ephemeral; routing each one into `sites/tasks/` would drown the signal. If a marketing task gets escalated (blocked > 1 day, needs PR-level accountability), create a tasks-repo entry by hand.
