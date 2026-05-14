# rapidclaw

> A macOS template for building long-running personal AI agents that live in Slack, run on cron, and operate the surfaces you care about — social, blog, reminders, browser, anything you can script.

Each bot is a self-contained instance of this template. You can run many side-by-side on one machine: each gets its own slug, launchd labels, sqlite databases, Slack channel, identity files, and chrome profile mapping. They don't collide.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              your Slack channel                              │
│                          (#<bot> in your workspace)                          │
└──────────────────────┬──────────────────────────────┬───────────────────────┘
                       │                              │
                  message events                 cron fires
                       │                              │
                  ┌────▼──────────────────────────────▼─────┐
                  │  Slack listener (Socket Mode, launchd)  │
                  │       — backfill, sleep/wake-safe       │
                  │       — periodic resync every 3min      │
                  │       — flap detection, inflight save   │
                  └────┬────────────────────────────────────┘
                       │
              spawns claude -p per message
                       │
                  ┌────▼──────────────────────────────────┐
                  │  claude reads CLAUDE.md + profile.md  │
                  │  + skills/, picks tools, acts:        │
                  │   - shell helpers (Slack, browser)    │
                  │   - your linked projects (sites/)     │
                  │   - your repo (drafts, log, goals)    │
                  └───────────────────────────────────────┘
```

## Why

If you've built a Claude Code agent for a specific purpose (personal branding, customer feedback, OSS maintenance, content distribution), you've probably copy-pasted the same scaffolding several times: Slack Socket Mode listener, cron prompts, helper scripts, launchd plists. rapidclaw extracts that scaffolding so the next bot takes you 15 minutes — and bots #2 and #3 don't drift from #1 as you improve the framework upstream.

## What you get

| | |
|---|---|
| **Slack listener** | Socket Mode, spawns `claude -p` per owner message, streams tool-call trace back to Slack as a live status message. Crash-safe: inflight job recovery, backfill on cold start, periodic resync every 3min so silent socket drops don't lose messages. |
| **5 cron routines** | daily (morning git scan + drafts) · noon (post-standup check-in) · friday (build-in-public + video-floor check) · sunday (weekly review against goals.md) · engagement (3x/day, scans X / LinkedIn / Reddit and drafts candidates) |
| **Shell helpers** | `slack-post/upload/status/read-thread/download-file.sh`, `x-intent.sh` (Twitter intent URLs), `browser-open.sh` (browser-use wrapper with per-platform Chrome profile mapping, Gemini-side-panel sweep, ad-blocker detection), `render-html.sh`, `gen-image.sh` |
| **Ops CLI** (`coach.sh`) | `status` (full JSON snapshot), `events` (per-thread tool-call timeline), `restart-listener`, `stop-job <ts>`, `reset-thread <ts>`, `kill-all` (panic button) |
| **Routing** | Default: `claude -p` on the Anthropic subscription. Flip `USE_OPENROUTER=1` in `.env` the day Anthropic disables subscription automation — claude CLI routes through OpenRouter to any model you pick (`anthropic/claude-haiku-4-5`, `z-ai/glm-4.7`, `deepseek/deepseek-v4-pro`, etc.) with per-route overrides. |
| **Setup wizard** | 12-step interactive prompts, resumable via `.bot-setup-state.json`. Substitutes `__SLUG__`, `__OWNER__`, etc. into every template file. Saves Slack tokens mode-600 to `~/.config/claude/<slug>-slack-{bot,app}-token`. |
| **Decommission script** | `bot-uninstall.sh` (basic / `--purge` / `--nuke`) cleanly tears down launchd, state files, and optionally the project + claude memory dirs. |

## Quick start

```bash
# Create a new bot from this template
gh repo create my-bot --template sanketsahu/rapidclaw --clone
cd my-bot
./bot-init.sh
```

Re-running `./bot-init.sh` resumes from where you left off — state in `.bot-setup-state.json`. Each step is idempotent.

## What the wizard asks (~15 questions, ~10 min)

1. **Bot slug** (e.g. `sanket-coach`) — propagates to launchd labels, sqlite filenames, log paths
2. **Owner** — macOS user account + email
3. **Slack basics** — workspace subdomain, channel ID, channel name, your Slack user ID, the bot's Slack user ID
4. **Slack tokens** — bot token (`xoxb-`) + app token (`xapp-`); saved mode 600 to `~/.config/claude/`
5. **OpenRouter** (optional) — key + whether to use it on day one
6. **Chrome profiles** — which Chrome profile is signed in to X / LinkedIn / Instagram / GitHub / Reddit (defaults to `Default`)
7. **Identity** — top-level goal (1-2 sentences), voice rules (multi-line paste), topic pillars
8. **Cron times** — daily / noon / friday / sunday + 3 engagement scans (defaults: 10:30 / 12:00 / Fri 17:00 / Sun 12:00 / 11:30 / 14:30 / 18:00)
9. The wizard then **substitutes placeholders**, writes `.env` + `profile.md` + renames launchd plists, optionally installs them, optionally fires a smoke-test Slack message.

## File layout (~37 files)

```
.
├── README.md
├── AGENTS.md                       # for AI tools to understand the template state
├── CLAUDE.md                       # written by wizard, project guidance for claude
├── .env.example                    # secrets + per-route model overrides
├── .gitignore
├── bot-init.sh                     # the setup wizard
├── bot-uninstall.sh                # decommission (basic / --purge / --nuke)
│
├── accountability/
│   ├── goals.md                    # weekly cadence floor (TBDs by default)
│   ├── engagement-strategy.md      # editorial mix + cron schedule
│   ├── listener/
│   │   ├── listener.js             # Slack Socket Mode → claude -p
│   │   ├── bootstrap-prompt.md     # prompt template for new threads (runtime substitution)
│   │   ├── resume-prompt.md        # prompt template for continuations
│   │   └── package.json
│   └── routines/
│       ├── daily.md noon.md friday.md sunday.md engagement.md
│       ├── _lib.sh                 # shared env-loading / token-path helpers
│       ├── run.sh                  # cron wrapper (loads .env, gates OpenRouter)
│       ├── slack-{post,upload,status,read-thread,download-file}.sh
│       ├── browser-open.sh         # browser-use wrapper, per-host Chrome profile
│       ├── render-html.sh
│       ├── gen-image.sh            # OpenRouter image gen (any model)
│       ├── x-intent.sh             # Twitter intent URL builder
│       └── coach.sh                # ops CLI
│
└── launchd/
    ├── __SLUG__-{listener,daily,noon,friday,sunday,engagement}.plist
    └── install.sh
```

## Routing models (subscription → OpenRouter)

Default: `claude -p` uses your Anthropic subscription with whatever model `~/.claude/settings.json` resolves to. Zero cost per call.

Flip one switch in `.env` the day you need OpenRouter:

```sh
USE_OPENROUTER=1
OPENROUTER_API_KEY=sk-or-v1-...
LISTENER_MODEL=anthropic/claude-haiku-4-5      # used by the Slack listener
DAILY_MODEL=z-ai/glm-4.7                       # cheaper for templated tasks
NOON_MODEL=z-ai/glm-4.7-flash                  # cheapest for status posts
FRIDAY_MODEL=anthropic/claude-haiku-4-5
SUNDAY_MODEL=anthropic/claude-haiku-4-5
ENGAGEMENT_MODEL=anthropic/claude-haiku-4-5    # voice + judgment-sensitive
```

The cron wrapper + listener export `ANTHROPIC_BASE_URL=https://openrouter.ai/api` + `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_MODEL` before invoking `claude -p`. OpenRouter exposes an Anthropic-compatible endpoint at `/api/v1/messages` — claude CLI talks to it natively.

Caching works automatically for Anthropic models routed through OpenRouter (Haiku 4.5 hits 100% cache after the first call ≈ $0.004/call). For non-Anthropic models, caching varies by provider — GLM 4.7 caches ~63%, DeepSeek caches 0% on the default OpenRouter routing.

## Decommissioning a bot

Three escalating modes. Pick the smallest one that does what you want.

```bash
./bot-uninstall.sh           # stop launchd, unload + delete plists, kill claude -p
                             # state files (tokens, sessions, events) PRESERVED

./bot-uninstall.sh --purge   # above + delete ~/.config/claude/<slug>-* (tokens,
                             # processed log, thread sessions, inflight, events)
                             # and /tmp/<slug>-*.log

./bot-uninstall.sh --nuke    # above + offer to delete claude's per-project memory
                             # dir + the project directory itself
```

Idempotent — safe to interrupt and resume. Confirms at the top level before doing anything. The Slack app at `api.slack.com/apps` is never touched by the script (delete it there manually if you want it gone).

## Design principles

- **One bot = one repo = one slug.** No multi-tenant routing inside a bot. Two bots on one machine = two clones, two slugs.
- **Sessions live in the user's Anthropic account** (claude CLI's `--resume` handles state). The bot just keeps a `thread_ts → session_id` map.
- **Slack channel = bot's home.** Everything routes through one channel for one bot. Approvals happen in threads.
- **Stay read-only on social.** The bot reads logged-in feeds via the owner's Chrome through browser-use. Posting is the owner's action — bot drafts and provides intent URLs / copy-paste blocks.
- **Browser-use opens new tabs.** It does not disturb the owner's active tab. `browser-use tab close` removes only the tab the bot opened — never `browser-use close` (that closes the owner's real Chrome).
- **Crash-safe by default.** Inflight job recovery + backfill window + periodic resync mean missing messages is rare. Laptop sleep, daemon flaps, silent socket drops — all handled.

## Requirements

- macOS (uses launchd for cron; Linux port would need a small adapter)
- `claude` CLI — `npm i -g @anthropic-ai/claude-code` or your install
- `node` 22+
- `gh` CLI (authenticated)
- `browser-use` — `pip install browser-use` (only required if your bot uses social scans)
- A Slack app you control: Socket Mode enabled, `xoxb-` bot token + `xapp-` app token (`connections:write` scope), invited to one channel

## Status

This is the framework I extracted while building [sanket-coach](https://github.com/sanketsahu/) — a personal-branding bot. It's been live in production for ~3 weeks on one bot at the time of release. Multiple-bot deployment hasn't been battle-tested yet; expect rough edges on `coach.sh` when two bots' processes overlap.

## License

MIT — see [LICENSE](LICENSE).
