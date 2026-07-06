# Routines

Cron-fired routines, 1:1 with `~/Library/LaunchAgents/com.agni.rapidnative-coach-*.plist`. Each routine is a `.md` prompt at `accountability/routines/<name>.md` that `run.sh` pipes into `claude -p`.

> **Goal of the refactor (Phase 6):** every routine ≤80 lines. Today many are 200-438 lines. Excess goes into skills (see [`skills.md`](skills.md)).

## Schedule grid (IST, weekday key: 0=Sun, 1=Mon, …, 5=Fri, 6=Sat)

| Routine | Schedule | Posts to | Status |
|---|---|---|---|
| `listener` | KeepAlive (always running, Socket Mode WebSocket) | n/a — drives in-thread responses | (no migration) |
| `daily` | 11:30 daily | `#rapidnative-coach` | v1 (owner-accountability; not bloated) |
| `noon` | 12:00 daily | `#rapidnative-coach` | v1 (same) |
| `friday` | 17:00 Fri | `#rapidnative-coach` | v1 (week recap) |
| `sunday` | 12:00 Sun | `#rapidnative-coach` | v1 (week ahead) |
| `eod-streak-check` | 19:00 Mon–Fri | `#eod-updates` | ✅ loads `eod-nudges` + `leave` |
| `engagement` | 11:30 / 14:30 / 17:30 daily (3x) | `#rn-coach-social` | v1 (social-engagement skill not yet scaffolded) |
| `user-testing-capture` | 10:00 daily | `#user-testing` + `#rapidnative-coach` | ✅ loads `user-testing` |
| `tasks-cleanup` | 12:15 Mon–Fri | `#rapidnative-coach` (approval flow) | ✅ loads `tasks` + `bug-tracking` + `leave` |
| `blog-internal` | 12:00 daily | `#marketing-automation` (via $SLACK_CONTENT_CHANNEL_ID) | v1 (thin wrapper around generate-blog.sh; no benefit from v2) |
| `blog-external` | 11:00 daily | `#ai-blog` | v1 (same) |
| `marketing-recon` | 06:00 Mon–Fri | (cache file only — no Slack) | ✅ loads `growth-marketing` |
| `marketing-morning` | 07:00 Mon–Fri | `#marketing-automation` | ✅ loads `growth-marketing` + `leave` |
| `marketing-evening` | 19:30 Mon–Fri | `#marketing-automation` | ✅ loads `growth-marketing` |
| `gtm-weekly-pick` | 09:00 Mon (+ Fri 17:00 recap) | `#marketing` | ✅ loads `growth-marketing` + `tasks` |
| `biweekly-shoutouts` | 18:00 every other Fri | `#marketing` | ✅ loads `growth-marketing` |
| `collabs-tuesday-update` | 09:00 Tue | `#collabs-and-partnerships` | ✅ no dedicated collabs skill yet; thin orchestrator |
| `resurface-logo-update` | 10:03 daily (one-off — already shipped) | `#design` | v1 (retire candidate) |

## Wrapper

All cron-fired routines are launched via `accountability/routines/run.sh <name>`:

```bash
# inside run.sh
PROMPT="accountability/routines/${ROUTINE}.md"
cd /Users/agni/Documents/rapidclaw
cat "$PROMPT" | claude -p --dangerously-skip-permissions --add-dir "$PWD"
```

The listener (`accountability/listener/listener.js`) is a separate launchd job — KeepAlive socket-mode WebSocket that spawns `claude -p --resume <session_id>` per Slack message.

## Working-day guards

Team-facing routines call `guard_working_day <name>` from `accountability/routines/_lib.sh`, which skips runs on weekends + holidays. The owner-facing routines (`daily`, `noon`, `sunday`) deliberately run regardless — personal accountability doesn't take holidays.

Currently guarded: `eod-streak-check`, `tasks-cleanup`, `friday`, `biweekly-shoutouts`, `collabs-tuesday-update`, `gtm-weekly-pick`.

## Conventions

- **One prompt file per routine.** No shared bodies — each `.md` is self-contained.
- **Post-refactor:** every routine reads (at most) `COMPANY.md` + the active channel persona + the relevant skill(s) listed above. The prompt itself becomes a thin orchestrator: guards → load skill → run → post.
- **Idempotency:** routines that produce state should write a per-day cache file (e.g. `marketing/.state/recon-YYYY-MM-DD.json`) and exit early if it exists. Phase 3 moves these caches into sqlite.
- **Logs:** `/tmp/rapidnative-coach-<routine>.log` per routine. launchd stdout/err at `/tmp/rapidnative-coach-<routine>-launchd-{out,err}.log`.

## Operational control

`accountability/routines/coach.sh` is the operator's swiss-army knife:

```
coach.sh status                       — listener + jobs + threads JSON
coach.sh events [thread_ts] [limit]   — events log tail
coach.sh restart-listener             — kickstart -k
coach.sh stop-listener                — bootout
coach.sh start-listener               — bootstrap
coach.sh stop-job <event_ts>          — kill specific claude child
coach.sh reset-thread <thread_ts>     — clear saved session (next msg = fresh)
coach.sh kill-all                     — emergency stop everything
```
