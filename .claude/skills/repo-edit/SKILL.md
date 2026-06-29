---
name: repo-edit
description: Procedural guidance for editing any linked site repo under `sites/`. Owns the sites-prepare → branch → commit → PR workflow. Delegates the actual content work to per-site `.claude/skills/`.
when_to_load: |
  Load when ANY of the following:
  - User asks to change / edit / fix / add something in a sites/<X> repo
  - User asks to open a PR against any product website
  - The bot is about to mutate any file under sites/<X> (any X)
voice_source: ../../profile.md
---

# repo-edit

Pure procedural skill. The substantive work lives in the site's own `.claude/skills/`; this skill just enforces the safe-mutation workflow so two teammates don't race on the same repo and so nothing pushes to `main`.

## The procedure (do every time)

```
1. Identify the target site: <X> in {rapidnative-website, applighter-website,
   letsdeployit-website (when symlinked), tasks, branding}.

2. Confirm the symlink resolves. If sites/<X> is a pointer .md file (not a symlink),
   STOP — that site isn't wired up yet. Surface the issue with the path to the
   pointer file.

3. Source-prep — ALWAYS, even if "you just need to check something":
     accountability/routines/sites-prepare.sh <X>
   This swaps the symlink to a per-thread worktree at
   ~/rapidclaw-site-worktrees/<thread_ts>/<X>/ on branch thread/<thread_ts>.
   Idempotent — safe to call every time. (Cron routines intentionally bypass and
   use the shared dir; only thread-scoped work needs this.)

4. cd into the prepped worktree.

5. Load the site's own context:
   - Read sites/<X>/CLAUDE.md (if present) — site-specific conventions
   - Read sites/<X>/AGENTS.md (if present) — for branding/ this is strict
   - For brand-related edits: Read sites/<X>/DESIGN.md (Phase 4 — may not exist yet)
   - For specific tasks: load relevant skill from sites/<X>/.claude/skills/

6. Do the work. Edit files, run tests if applicable.

7. Commit on the thread-branch:
   git add <specific paths — never `git add .` or `git add -A`>
   git commit -m "..."
   (DO NOT --no-verify; let pre-commit hooks run)

8. Push the branch (the thread-branch, NOT main):
   git push -u origin thread/<thread_ts>  OR  a clean branch you cut from main

9. Open a draft PR:
   gh pr create --draft --base main --title "..." --body "..."

10. Post the PR URL back to the source Slack thread:
    accountability/routines/slack-post.sh <channel_id> <thread_ts> <<EOF
    PR opened: <pr_url>
    EOF

11. Wait for review. Don't auto-merge.
```

## Hard rules — no exceptions

1. **NEVER push to `main`** on any sites/<X>. Always a branch.
2. **NEVER merge a PR yourself.** Even if the sender is the owner. The point of a PR is the second-pair-of-eyes gate; merging requires explicit "merge" approval after the PR is open + reviewed.
3. **NEVER `git add .` or `git add -A`.** Stage specific paths only. Prevents accidentally committing secrets / build artifacts / unrelated dirty state.
4. **NEVER bypass pre-commit hooks** (`--no-verify` is banned unless the sender explicitly asks for it).
5. **NEVER force-push to a shared branch** (anything not your own thread branch).
6. **NEVER amend a commit on a remote branch.** Always a new commit.
7. **NEVER edit another teammate's in-progress drafts/** in sites/<X> unless they handed off explicitly.

## When the user asks for "just a quick fix"

Same procedure. The hard rules exist precisely because "quick fix" is when things break.

## Per-site overrides

Each site may have its own additional rules. Read first:

| Site | Override file | Notes |
|---|---|---|
| `rapidnative-website` | `sites/rapidnative-website/CLAUDE.md` | Main product code; ~30 site skills available |
| `applighter-website` | `sites/applighter-website/CLAUDE.md` (if present) | Brand canonical pending |
| `letsdeployit-website` | (not yet wired — see `sites/letsdeployit-website.md` pointer) | |
| `tasks` | `sites/tasks/CLAUDE.md` | Sprint repo. Use the notification queue at `sites/tasks/intake/unsent-notifications.md`. |
| `branding` | `sites/branding/AGENTS.md` | **Strict workflow.** Read AGENTS.md before any change. |

## When the user asks "open a PR fixing X" and the work is non-trivial

Two paths (per the subagent design in `drafts/2026-06-25-architecture-refactor/subagents.md`):

- **Sync (default)** — main coach itself does the work via this skill. User stays in the Slack thread; conversation continuity preserved.
- **Async (only for >2-min work that the user explicitly asked to be backgrounded)** — drop a task JSON into the site's agent inbox; the centralised heartbeat (Phase 7 — not built yet) picks it up. Bot replies "queued — will post PR URL when done."

Today, only sync exists. Use it for everything.

## Migration status

- This skill is procedural — codifies existing CLAUDE.md "Linked projects" guidance.
- Phase 7 (deferred): when async heartbeat infrastructure lands, this skill grows a "drop into agent inbox" branch.

## Related skills

- Every per-site skill (e.g. `sites/rapidnative-website/.claude/skills/content-studio*`) — repo-edit is the wrapper; site skills do the substantive work.
- `creator-studio` (Phase 4) — reads `sites/<X>/DESIGN.md` for brand-related edits.
