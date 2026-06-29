# Decisions log

Canonical record of architecture-refactor decisions made in thread `1782373569.212709` (#rapidnative-coach).

| # | Question | Decision | Decided by | Reply ts | Date |
|---|---|---|---|---|---|
| 11 | Handoff trigger: explicit command vs proactive offer? | **Explicit only** — main agent MAY ask, user must accept. Slash commands (`/handoff`) do NOT work on Slack; use natural-language or non-slash marker (`handoff: <agent>` / `!handoff <agent>`). | @sanket | 1782381840.683309 | 2026-06-25 |
| 12 | Handback trigger: explicit, auto-on-idle, auto-on-scope-drift? | **Auto + explicit, both.** Subagent self-detects scope drift (emits `HANDBACK_REASON:` sentinel); user can always say "handback". | @sanket | 1782381840.683309 | 2026-06-25 |
| 13 | Handoff visibility? | **Always visible.** Per-reply `*<agent-name>* · handed-off mode` header; explicit marker messages on entry/exit. Listener enforces header even if subagent prompt drifts. | @sanket | 1782381840.683309 | 2026-06-25 |
| 8 | Site subagent default mode (sync vs async)? | **Sync by default.** Async only when task literally spans minutes (open PR while away). | @sanket | 1782382397.400179 | 2026-06-25 |
| 9 | Heartbeat infra ownership (per-site vs centralised)? | **Centralised** in `accountability/routines/agent-heartbeat.sh`. Per-site dirs still hold inbox/state. | @sanket | 1782382397.400179 | 2026-06-25 |
| 10 | Subagent definition format (single-file vs directory)? | **Claude Code's standard** — single file `.claude/agents/<name>.md` with YAML frontmatter. Drop bot-god's directory form when renaming to `tasks-agent`. | @sanket | 1782382397.400179 | 2026-06-25 |
| (was 11 in subagents.md) | Per-subagent auto-memory or coach-level shared? | **Claude Code's standard** — per-project auto-memory by cwd. Site subagents naturally get the site's auto-memory; coach gets coach's. No special mechanism. | @sanket | 1782382397.400179 | 2026-06-25 |

## Architectural reframe (2026-06-25 reply `1782382397.400179`)

> "Subagent would be rarely used, most of the things would happen on a single context, single thread apart from the one-off generations like screenshot, images etc. And that's why I am not too concerned about the subagent model, it would mostly be top-level memory and skills that load more skills recursively."

**Implications:**

1. **Skills are the spine, not subagents.** The 12 capability domains in plan.md §2.3 are skills (`.claude/skills/<goal>/SKILL.md`), not subagents. Main coach reads them inline on match.
2. **Recursive skill loading is the composition mechanism.** Skills reference other skills/files (per-brand strategies, per-account references, voice rules). Claude loads them lazily as needed via Read. No new mechanism — just discipline.
3. **Per-site skills are read directly by main coach** via `sites-prepare.sh` + `Read`. No subagent invocation needed for in-thread iterative dev work. Thread continuity preserved end-to-end.
4. **Subagents reserved for:**
   - One-shot artifact generation: banner, image, screenshot, render-html, gen-image. Spawned sync, return file path/bytes, main coach posts.
   - Async background work: "open this PR while I sleep". Inbox + centralised heartbeat. Rare.
5. **Handoff mode is still designed but rarely invoked.** Only when the user explicitly wants sustained subagent-owned work in a thread. Default is no handoff.
6. **`tasks-agent` (renamed from bot-god) stays** as the canonical async heartbeat example. Other site subagents only exist when needed for artifact gen or PR work.

## Original 7 questions — answered by @sanket on 2026-06-25 reply `1782382986.101679`

| # | Question | Decision |
|---|---|---|
| O1 | LetsDeployIt repo location | **Symlink, matching existing pattern.** Repo: `https://github.com/RapidNative/letsdeployit-website`. Clone to `~/Documents/letsdeployit-website`, symlink into `sites/`. |
| O2 | Applighter brand audit | **Per-repo DESIGN.md.** Each repo will eventually own a `DESIGN.md` at its root. `creator-studio` skill is a thin reader. Don't author brand decisions in coach. |
| O3 | SQLite location | **`~/.config/claude/rapidnative-coach.sqlite`** — confirmed. |
| O4 | Fate of `marketing/` dir | **Keep until everything is migrated**; delete in a final cleanup pass at end of Phase 2. |
| O5 | Channel `members` list | **Hand-maintained.** Consolidate from existing sources (.env TEAM_USERS, marketing/team.md, sites/tasks/roles.md, auto-memory project_team_roster) into `definitions/people.md` during Phase 0. Channel frontmatter references handles from there. **No Slack API sync.** |
| O6 | Index per-site skills in `definitions/skills.md` | **Yes.** Main coach reads them directly post-reframe; the index is the discovery surface. |
| O7 | Migration safety (branch + shadow-cron) | **Deferred — Sanket unsure.** Recommended default: in-place on main, one phase per PR. Phase 0 is no-behaviour-change. Phase 1+ migrations: run new + old path in parallel for 1 cron cycle, smoke-test, then delete old. No full shadow-cron infra unless we hit a regression. |

## All questions closed

Plan.md is executable. Fresh-context Claude Code session can pick up `plan.md` + this file and start Phase 0 immediately.
