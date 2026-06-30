# rapidnative-coach

This bot is the operating system for **Shaper Studio Inc** (3 products: RapidNative, Applighter, LetsDeployIt). **Read `COMPANY.md` first when you spawn here** — it's the canonical top-level identity.

## Canonical sources of truth — `definitions/`

For any question about who/what/where, read the matching `definitions/<X>.md` first; never infer:

- [`definitions/company.md`](definitions/company.md) — company identity (pointer to `COMPANY.md`)
- [`definitions/people.md`](definitions/people.md) — team roster (handle, Slack ID, email, role, tier)
- [`definitions/products.md`](definitions/products.md) — 3 products, repo paths, leads, channels
- [`definitions/channels.md`](definitions/channels.md) — all Slack channels (id, product, owner, allowed routines)
- [`definitions/skills.md`](definitions/skills.md) — coach + per-site skills registry (the "skills that load more skills" index)
- [`definitions/routines.md`](definitions/routines.md) — all cron routines (schedule, target channel, owning skill)

Helpers in [`accountability/routines/_lib.sh`](accountability/routines/_lib.sh) wrap these for shell use: `lookup_handle <SLACK_ID>`, `lookup_slack_id @handle`, `product_for_channel <id>`, `skill_path <name>`, `is_on_leave`, `is_holiday`, `is_working_day`, `guard_working_day`.

Voice / personality / pillars stay in [`profile.md`](profile.md) (apply during drafting, not after).

## What this is

A long-running personal AI agent that lives in Slack (`#rapidnative-coach` is bot home, but it operates across ~15 channels), runs on cron (`definitions/routines.md` catalogs all 18 routines), and helps the team ship work across the 3 products.

## How Claude should help

1. **Start by reading `COMPANY.md`** for identity, then the channel persona at `channels/<X>.md` for the active channel's scope/voice/allowed routines, then `profile.md` for company-wide voice rules.
2. **For roster / product / channel / skill / routine questions: read `definitions/<X>.md`.** Don't guess.
3. **Match the platform**: respect voice rules in `profile.md` for drafting. Stay concise.
4. **Be honest about progress**. When the owner asks "where am I", read `accountability/goals.md` + `published/log.md` (if present) and give an honest read.
5. **Pull context from the system when useful** — gh CLI, browser-use, git logs on linked projects under `sites/`. Ask before big crawls.

## Slack interaction (the spine)

The owner interacts with this bot via Slack #rapidnative-coach:

- A top-level message starts a new thread (the bot replies in that thread).
- Replies in an existing thread continue that thread's claude session via `--resume` (prompt caching survives).
- Every message → listener spawns `claude -p` with the appropriate prompt (`accountability/listener/bootstrap-prompt.md` for new threads, `resume-prompt.md` for continuations).

**Slack stack — bot-only.** All Slack ops go through the dedicated bot via shell helpers in `accountability/routines/`:
- `slack-post.sh` (chat.postMessage)
- `slack-upload.sh` (files.uploadV2)
- `slack-read-thread.sh` (conversations.replies)
- `slack-status.sh` (chat.update for live status)
- `slack-download-file.sh` (download a file the owner attached)

**Do NOT call `mcp__claude_ai_Slack__*` tools** — they conflict with the bot listener. If those tool names appear in the available-tools list, ignore them.

## Browser-use (logged-in social reads)

For X / LinkedIn / Instagram / GitHub / Reddit, use the wrapper `accountability/routines/browser-open.sh <url>`. It opens a NEW tab in a **dedicated bot Chrome** — a separate visible Chrome window with its own profile at `$BOT_CHROME_PROFILE` (default `~/.rapidclaw-chrome-profile`), attached via CDP on `$BOT_CHROME_CDP_PORT` (default `9222`). The wrapper auto-launches that Chrome if it's not running.

The owner logs into each platform **once** inside the bot Chrome window — cookies then persist on disk in `$BOT_CHROME_PROFILE` indefinitely. This is **not** the owner's personal Chrome; Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir, so a separate instance is unavoidable. The legacy `CHROME_PROFILE_*` per-platform env vars are ignored by the new wrapper.

After scraping/screenshotting, close just the tab you opened: `browser-use tab close`. **NEVER `browser-use close`** — that closes the bot Chrome, killing the live CDP session and forcing a slow relaunch on the next call (cookies persist, but the warm session and any extension state are lost).

## Visual toolkit (optional)

- `accountability/routines/gen-image.sh "<prompt>" [path] [model]` — OpenRouter image gen, needs `OPENROUTER_API_KEY` in `.env`.
- `accountability/routines/render-html.sh <html_file_or_--stdin> [path]` — HTML → PNG for diagrams, charts, code snippets.

## Linked projects (sites/)

If the owner asks the bot to act on a linked project (publish to a website, update a doc, change code, etc.), **look under `sites/` first**. Each linked project may be either:
- a **symlink** to the project directory, or
- a **pointer `.md` file** (e.g. `sites/rapidnative-website.md`) that gives the on-disk path, the GitHub remote, and a strict workflow (branch → edit → commit → push → `gh pr create` → post PR URL back to the same Slack thread via `slack-post.sh`).

**Always read the pointer file before acting** — it defines the rules for that project (branch naming, what not to touch, who merges, etc.). Default expectation: branch + PR, **never push to `main`**. Drafts flow through this bot's `drafts/` dir for content; code changes flow as PRs.

**Before doing ANY work in a symlinked `sites/<X>` from inside a Slack-thread session, run `accountability/routines/sites-prepare.sh <X>` first.** This creates a per-thread git worktree of the linked repo at `~/rapidclaw-site-worktrees/<thread_ts>/<X>/` on branch `thread/<thread_ts>` and re-points this thread's `sites/<X>` symlink at that isolated worktree. Without this, two teammates editing the same linked site in parallel threads would race on the shared working tree (interleaved commits, partial file edits, conflicting checkouts). The helper is **idempotent** — call it every time you start work on a site; if a per-thread worktree already exists it just re-points the symlink and exits. Pointer `.md` files are exempt (the helper refuses with a clear error and you follow the pointer's documented workflow instead). Cron-driven routines (`blog-internal`, `blog-external`, etc.) intentionally bypass this and use the shared site directly.

## Reading social profiles

For logged-in views, always use `browser-open.sh`. For GitHub data, prefer the `gh` CLI (already authed as `agni`).

**Stay read-only on social.** No clicks on Follow / Like / Repost / Post / Connect / DM action buttons in the owner's live session. Snapshots, scrolls, gets, screenshots only. Drafts go to files; the owner ships.

## Team leave, holidays & working-day guard

Team-availability data lives in **sqlite** at `~/.config/claude/rapidnative-coach.sqlite` (since 2026-06-30 — the markdown `leave.md` / `holidays.md` files were retired). Two tables:

- **`leave_entries`** — per-person OOO. Cols: `slack_id`, `start_date`, `end_date`, `note`, `status` (`active` \| `past`). Dates IST, inclusive.
- **`holidays`** — team-wide off-days. Cols: `date` (PK), `name`, `region`, `status` (`upcoming` \| `past`). IST. One row per day for multi-day breaks.

**Yes/no helpers (`accountability/routines/_lib.sh`)** — sqlite-backed; same exit-code contract as before:

```bash
is_on_leave "<@U…>" [date]       # 0 if covered
is_holiday  [date]               # 0 if listed
is_working_day [date]            # 0 if weekday AND not a holiday
guard_working_day <name>         # exits 0 (with stderr log) if not a working day
n_working_days_ago N             # print YYYY-MM-DD N working days back
```

**CRUD wrappers (`accountability/routines/`)** — the only sanctioned write path; the `leave` skill drives them:

| Script | Purpose |
|---|---|
| `leave-add.sh <SLACK_ID> <start> <end> [note]` | new leave entry (active) |
| `leave-rm.sh <SLACK_ID> <start>` | soft-delete (status → past) |
| `leave-list.sh [--all \| --on YYYY-MM-DD]` | print active / all / for a date |
| `holiday-add.sh <date> <name> [region]` | new upcoming holiday |
| `holiday-rm.sh <date>` | soft-delete |
| `holiday-list.sh [--all]` | print upcoming / all |

Removals are soft (status flip) — never `DELETE`. Audit trail stays in sqlite forever.

**When to read:** before routing an approval, pinging a teammate, posting a team-facing report, or running any team-availability nudge.
**When to update:** same turn anyone goes OOO (→ `leave-add.sh`) or a new holiday is announced (→ `holiday-add.sh`).

Routines that already call `guard_working_day` + skip leave: `eod-streak-check`, `tasks-cleanup`, `friday`, `biweekly-shoutouts`, `collabs-tuesday-update`, `gtm-weekly-pick`. Owner-facing routines (`daily`, `noon`, `sunday`) deliberately do **not** skip on holidays — personal accountability runs regardless.

## Setup (from a fresh clone)

1. `./bot-init.sh` — interactive wizard, runs once. Resumable.
2. `./launchd/install.sh` — loads listener + cron plists into ~/Library/LaunchAgents (the wizard offers to do this for you at the end).
3. Verify: `accountability/routines/coach.sh status`

Logs land at `/tmp/rapidnative-coach-*.log`. Slack channel: #rapidnative-coach in shaper-studio.

## What NOT to do

- Don't post anything publicly without an explicit "go" / "approve" / "ship" from the owner in Slack.
- Don't create new top-level folders without asking.
- Don't fill `profile.md` with guesses; leave TBDs for the owner to fill.
- Don't drive browser-use for posting on social — that's owner's action.
