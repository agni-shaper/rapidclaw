# Marketing automation (OpenClaw)

Daily distribution-team task automation for the 4-person marketing crew (@sanket, @rishav, @russel, @famitha). Lives alongside the rest of `rapidnative-coach`; reuses the bot's Slack helpers, leave file, working-day guard, and launchd scheduling.

## The daily cycle

```
06:00 IST              07:00 IST                   19:30 IST
┌──────────────────┐  ┌─────────────────────────┐  ┌──────────────────────────┐
│ marketing-recon  │  │ marketing-morning       │  │ marketing-evening        │
│                  │  │                         │  │                          │
│ • scan platforms │  │ • read sprint + carry   │  │ • read sentinel per-crew │
│   - HN (API)     │  │ • skip on-leave         │  │ • per-crew: read thread  │
│   - Reddit (API) │  │ • expand templates      │  │   replies, parse "done   │
│   - Quora (b-u)  │  │ • load recon cache      │  │   T01, T03" claims       │
│   - LinkedIn(b-u)│  │ • distribute findings   │  │ • write evening-tasks +  │
│   - X (b-u)      │  │   round-robin per-platf │  │   per-crew carryover     │
│ • draft comments │  │ • inject blog amplify   │  │ • append tracker rows    │
│ • write          │  │ • post N top-level msgs │  │ • post top-level EOD     │
│   recon-DATE.json│  │   in #marketing-automatn│  │   recap                  │
└──────────────────┘  └─────────────────────────┘  └──────────────────────────┘
       │                       ▲
       │ writes cache          │ reads cache
       ▼                       │
  marketing/.state/recon-YYYY-MM-DD.json

External inputs:
  marketing/.state/blog-amplification-YYYY-MM-DD.md  ← written by blog-internal
                                                       (after auto-publish)
```

**Recon (06:00 IST)** is LLM-heavy and slow (5-10 min). HN + Reddit use public APIs and always succeed. Quora/LinkedIn/X go through `browser-open.sh` + browser-use scraping — these are flaky; recon degrades gracefully if any one platform fails. Output is a JSON cache the morning routine reads.

**Morning (07:00 IST)** is fast and deterministic. Reads sprint, carryover, recon cache, blog cache. Expands templates → builds per-person task lists with embedded thread links + suggested drafts (where recon found findings). Posts one **top-level message per working crew member**, each pinging that person via `<@U…>`. The lack of recon doesn't break morning — tasks just ship plain.

**Evening (19:30 IST)** reads each crew member's own thread (parents are the per-person top-levels from morning) via `conversations.replies`, parses "done with T01, T03" claims, updates `evening-tasks.md` + carryover queue + `tracker.md`. Posts a top-level EOD recap.

Completion capture: each crew member **replies in their own AM post's thread** as they finish tasks. The evening routine parses thread replies. Two reply shapes work:

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
| `.state/morning-ts-YYYY-MM-DD` | Multi-line sentinel (`slack_id ts` per crew) | **Routine** |
| `.state/recon-YYYY-MM-DD.json` | Recon's scrape + drafts cache | **Routine** (`marketing-recon`) |
| `.state/blog-amplification-YYYY-MM-DD.md` | Side-channel from `blog-internal` for tomorrow's amplification task | **Routine** (`blog-internal`) |

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
| Post lands but no `🔗` / `💬` sub-lines | Recon didn't run, or ran and found nothing | Check `marketing/.state/recon-<today>.json` exists; if missing check `/tmp/rapidnative-coach-marketing-recon.log` |
| Some platforms enriched, others not | Recon scrape failed for those platforms (likely Quora/LinkedIn/X login lapsed) | `browser-open.sh https://<platform>/` and log in once; cookies persist |
| "Today's date not found in sprint.md" | Sprint not rolled forward | Edit `sprint.md` to add today's date heading |
| Evening routine says "no AM sentinel today" | Morning routine never ran successfully | Check `/tmp/rapidnative-coach-marketing-morning.log` |
| Blog amplification missing | `blog-internal` didn't write cache (either failed or hasn't run yet) | Check `marketing/.state/blog-amplification-<today>.md` exists; check `/tmp/rapidnative-coach-blog-internal.log` |

## Manual rerun commands

```bash
# Recon only (regenerates cache; safe to re-run, idempotent)
rm -f marketing/.state/recon-$(TZ=Asia/Kolkata date +%F).json
accountability/routines/run.sh marketing-recon

# Morning only (regenerates posts — DELETE existing Slack posts first if you want clean re-post)
rm -f marketing/.state/morning-ts-$(TZ=Asia/Kolkata date +%F)
accountability/routines/run.sh marketing-morning

# Evening only (recomputes EOD from current Slack thread state)
accountability/routines/run.sh marketing-evening
```

## Compatibility notes

This system **reuses** the existing rapidnative-coach plumbing — no new infrastructure:

- Slack: `accountability/routines/slack-post.sh`, bot token at `~/.config/claude/${BOT_SLUG}-slack-bot-token`
- Leave: `accountability/leave.md` (the canonical org-wide file)
- Working-day / holiday: `accountability/routines/_lib.sh` (`guard_working_day`, `is_on_leave`)
- Team roster: `~/.claude/projects/-Users-agni-Documents-rapidclaw/memory/project_team_roster.md`
- Scheduler: launchd plists in `launchd/`, auto-loaded by `launchd/install.sh`

The marketing crew is intentionally **separate from `sites/tasks/`** (the team's canonical tracker). Daily rotation tasks are high-volume and ephemeral; routing each one into `sites/tasks/` would drown the signal. If a marketing task gets escalated (blocked > 1 day, needs PR-level accountability), create a tasks-repo entry by hand.
