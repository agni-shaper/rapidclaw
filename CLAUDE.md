# rapidnative-coach

This is a rapidclaw bot. **Identity, voice, goal, and pillars are in `profile.md` — read that file first when you spawn here.**

## What this is

A long-running personal AI agent that lives in Slack (#rapidnative-coach), runs on cron (daily/noon/friday/sunday/engagement), and helps the owner act on their goal.

## How Claude should help

1. **Always start by reading `profile.md`** — that's where identity, voice rules, topic pillars, and the top-level goal live.
2. **Match the platform**: respect the voice rules in profile.md for any drafting. Stay concise.
3. **Be honest about progress**. When the owner asks "where am I", read `accountability/goals.md` + `published/log.md` (if present) and give an honest read.
4. **Pull context from the system when useful** — gh CLI, browser-use, git logs on linked projects under `sites/`. Ask before big crawls.

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

For X / LinkedIn / Instagram / GitHub / Reddit, use the wrapper `accountability/routines/browser-open.sh <url>`. It opens a NEW tab in the owner's real Chrome (the Chrome profile mapping per platform is in `.env`: `CHROME_PROFILE_X`, `CHROME_PROFILE_LINKEDIN`, etc.).

After scraping/screenshotting, close just the tab you opened: `browser-use tab close`. **NEVER `browser-use close`** — that closes the owner's real Chrome window.

## Visual toolkit (optional)

- `accountability/routines/gen-image.sh "<prompt>" [path] [model]` — OpenRouter image gen, needs `OPENROUTER_API_KEY` in `.env`.
- `accountability/routines/render-html.sh <html_file_or_--stdin> [path]` — HTML → PNG for diagrams, charts, code snippets.

## Linked projects (sites/)

If the owner asks the bot to act on a linked project (publish to a website, update a doc, change code, etc.), **look under `sites/` first**. Each linked project may be either:
- a **symlink** to the project directory, or
- a **pointer `.md` file** (e.g. `sites/rapidnative-website.md`) that gives the on-disk path, the GitHub remote, and a strict workflow (branch → edit → commit → push → `gh pr create` → post PR URL back to the same Slack thread via `slack-post.sh`).

**Always read the pointer file before acting** — it defines the rules for that project (branch naming, what not to touch, who merges, etc.). Default expectation: branch + PR, **never push to `main`**. Drafts flow through this bot's `drafts/` dir for content; code changes flow as PRs.

## Reading social profiles

For logged-in views, always use `browser-open.sh`. For GitHub data, prefer the `gh` CLI (already authed as `agni`).

**Stay read-only on social.** No clicks on Follow / Like / Repost / Post / Connect / DM action buttons in the owner's live session. Snapshots, scrolls, gets, screenshots only. Drafts go to files; the owner ships.

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
