# Architecture refactor plan

Author: rapidnative-coach (drafted on @sanket's request 2026-06-25, Slack thread `1782373569.212709` in #rapidnative-coach).
Status: **READY TO EXECUTE.** All 11 design questions answered (decisions.md). All 7 original product questions answered (§5). Phase 0 can start.

> **Core design principle (post-reframe by @sanket 2026-06-25 reply `1782382397.400179`):**
> The system is **top-level memory + skills that load more skills recursively.** Main coach handles everything single-thread, single-context. Subagents are an escape hatch for one-shot artifact generation (banners, images, screenshots, renders) and the rare genuinely-async background job. The 12 capability domains are *skills*, not subagents — see §2.3.

---

## 0. How to use this plan in a fresh Claude Code session

This plan is meant to be executed by a fresh `claude` CLI session in `/Users/agni/Documents/rapidclaw/` with no Slack thread context. Before doing any work:

1. **Read in this order:**
   1. `CLAUDE.md` (existing project rules)
   2. `drafts/2026-06-25-architecture-refactor/plan.md` (this file)
   3. `drafts/2026-06-25-architecture-refactor/decisions.md` (canonical decisions log)
   4. `drafts/2026-06-25-architecture-refactor/subagents.md` (only when you reach Phase 7 / subagent work — not needed before that)

2. **Reality-check before any edit:** the plan was written 2026-06-25. If you're running it later, file paths/counts may have drifted. Spot-check with `ls`/`grep` before assuming. Specifically:
   - confirm `sites/` symlinks still resolve
   - confirm the routine .md files in `accountability/routines/` haven't been substantially restructured
   - confirm `~/.config/claude/rapidnative-coach-thread-sessions.json` exists (listener still in use)

3. **Work in phase order (§3).** Each phase has explicit acceptance criteria. Don't skip ahead. Commit one phase at a time.

4. **Approval gates:** this is a no-behaviour-change refactor for Phase 0. Phases 1-6 ship one PR per skill/migration. Don't push to `main` without owner sign-off. If a deletion is irreversible (e.g. removing `marketing/` per O4), make a backup branch first.

5. **Done = all phases complete + every routine in `accountability/routines/` ≤80 lines + `marketing/` deleted + sqlite holds state + `definitions/` is the single source of truth for people/products/channels/skills.**

---

This plan responds to Sanket's brief in #rapidnative-coach thread `1782373569.212709`: re-frame this bot from "rapidnative-coach" to "Shaper Studio Inc operating system", define 12 capability domains, give each its own skill, push state into sqlite, and **stop the hallucinations**.

---

## 1. Current state — what's actually here

### What works (keep)

- **Two-entrypoint model** (listener.js for Slack, run.sh for cron) is sound. Don't change it.
- **Per-thread git worktrees** prevent cross-talk between simultaneous teammates. Keep.
- **Tier-based permission gates** (owner / superadmin / teammate / unknown) work correctly.
- **Tool layer** (slack helpers, browser-open.sh, gh, render-html.sh, gen-image.sh, sites-prepare.sh) is clean and stable. Keep as-is.
- **Cross-channel routine pattern** (e.g. `accountability/routines/cross-channel/weekly-wrap.md` → reads a skill in a site repo → posts on approval) is the right pattern. Generalise it.
- **`sites/rapidnative-website/.claude/skills/`** already has ~30 skills (`content-studio*`, `bi-*`, `saas-*`, `design-system`, `marketing-design-system`, `writing-style`, `repository-refactor`). The skill-per-capability pattern is already proven on the RN side.
- **`sites/tasks/`** has its own mature CLAUDE.md, `roles.md`, notification queue (`intake/unsent-notifications.md`), and `recurring/` definitions. Treat it as the canonical "task DB + management" subsystem — coach should feed it, not duplicate it.

### What's broken (causes of hallucination)

| Problem | Evidence | Effect |
|---|---|---|
| **Six sources of truth for "team"** | `.env TEAM_USERS`, `marketing/team.md`, `marketing/accounts.md`, `sites/tasks/roles.md`, `accountability/leave.md`, auto-memory `project_team_roster.md` | Claude picks one inconsistently → wrong pings, missed leave checks |
| **Routine bloat — too many concerns per prompt** | `marketing-recon.md` 438 lines, `tasks-cleanup.md` 289, `marketing-evening.md` 222, `blog-internal.md` 195 | Prompt mixes voice + accounts + scrape protocol + draft templates + idempotency + output schema → Claude conflates rules |
| **Marketing context lives in three places** | `marketing/` (sprint/accounts/tracker) + `accountability/routines/marketing-*.md` + `sites/tasks/recurring/` | Same domain modelled three different ways; no canonical answer to "where's the marketing plan?" |
| **No skills registry visible from coach** | Site-level skills exist but coach context doesn't index them | Coach can't reliably know "for asset gen, load `sites/rapidnative-website/.claude/skills/content-studio/`" without grepping every turn |
| **State scattered across mediums** | `accountability/state/*.json`, `marketing/.state/*`, `sites/tasks/intake/*.md`, `accountability/reminders/*.md`, `drafts/`, auto-memory | Claude doesn't know which is authoritative; reads outdated state |
| **"sqlite" mentioned in spec but doesn't exist** | `find . -name "*.sqlite*"` returns 0 results | Reminders + leave + streaks live in markdown that Claude has to grep — slow, brittle, no atomic updates |
| **Bootstrap prompt is ~500 lines loaded every turn** | `accountability/listener/bootstrap-prompt.md` | Even a one-liner question loads the entire ambient context; raises base hallucination rate |
| **No formal product/repo definition** | Products implied by sites/ symlinks + scattered marketing/config.md mentions | Claude infers "RapidNative" identity but doesn't know LetsDeployIt exists; Applighter has no .claude/ at all |
| **Per-channel personas mix scope + voice + allowed_routines but not membership/owner** | `channels/<X>.md` files | Claude doesn't know "who lives in this channel" → wrong tone, wrong assumptions about who reads it |

### Channel inventory (what matches what)

| Channel ID | Name | Today's role |
|---|---|---|
| `C0B4HG16QP3` | #rapidnative-coach | Owner + bot home |
| `C09F377FGFK` | #marketing | Marketing team general |
| `C0BBQ7PV34N` | #marketing-automation | Distribution/growth team daily task drops |
| `C09DF90CQ8Z` | (standup) | Standup MoMs (referenced by tasks-cleanup) |
| `C0A8Q9HM5BN` | #eod-updates | Team EOD posts |
| `C09EU7C87BM` | #user-testing | User-testing channel |
| `C0ASK9520JG` | #tasks | Task ops |
| ... | (8 more) | persona'd in `channels/*.md` |

---

## 2. Target architecture

### 2.1 New top-level identity

`profile.md` should become **`COMPANY.md`** (top-level):

```
Company: Shaper Studio Inc
Primary project: RapidNative (rapidnative.com)
Other products:
  - Applighter (applighter.com) — full-stack templates store
  - LetsDeployIt (letsdeploy.it) — mobile-app deploy service
Bot's role: operating system for the company — orchestration, drafting,
tracking, accountability. Routines + skills + memory + channels are the
substrate.
```

`profile.md` stays but shrinks to **voice rules only** (the writing-style guardrails) and is loaded only when drafting.

### 2.2 Canonical definitions folder

A single `definitions/` directory at repo root. Every other file links here.

```
definitions/
  company.md          # Shaper Studio Inc + 3 products (see §2.1)
  people.md           # name, slack id, email, role, products, brand-accounts, leave-link
  products.md         # 3 products + repo path + sites/ symlink + creator-studio path + lead + primary channel
  channels.md         # all channels: id, name, members, owner, products served, allowed routines
  skills.md           # registry of every skill (path, summary, when-to-load), grouped by goal
  routines.md         # registry of every cron routine (schedule, prompt, target channel, goal it serves)
```

**`people.md` becomes the only place to learn about a teammate.** All other team-related files (`marketing/team.md`, `marketing/accounts.md`, `sites/tasks/roles.md`, `accountability/leave.md`, auto-memory) link back. `_lib.sh` helpers (`is_on_leave`, `lookup_handle`) read `people.md`.

### 2.3 12 capability domains → 12 skills

Each goal in Sanket's spec becomes a skill in `.claude/skills/` at coach root (NOT site-level — coach-level). Routines shrink to thin orchestrators (~30 lines each) that just load the skill.

| # | Goal | Skill path | Notes |
|---|---|---|---|
| 1 | Task management | `.claude/skills/task-management/` | Feeds `sites/tasks/` from #C09DF90CQ8Z + #C0A8Q9HM5BN + #C09EU7C87BM + git logs. Tasks repo is the DB. Two-tier interaction codified here. |
| 2 | Distribution/growth | `.claude/skills/growth-marketing/` | Owns #C0BBQ7PV34N. Per-brand strategy files: `growth-marketing/strategies/{rapidnative,applighter,letsdeployit}.md`. Per-person accounts: `growth-marketing/accounts/<handle>.md`. Replaces `marketing/`. |
| 3 | Site repo edits | `.claude/skills/repo-edit/` | Codifies sites-prepare.sh + branch+PR rules. Calls into per-site `.claude/skills/`. |
| 4 | Routine/reminder scheduling | `.claude/skills/scheduler/` | Owns the sqlite (see §2.4). plists still fire cron; reminders/state/runs go to sqlite. |
| 5 | Newsletter | `.claude/skills/newsletter/` | Owns `drafts/newsletter-next/` + recurring routine. |
| 6 | Weekly wrap | `.claude/skills/weekly-wrap/` | Wraps existing cross-channel/weekly-wrap.md + content-studio-generate-weekly-wrap skill. |
| 7 | Social artifacts | (use existing `sites/<X>/.claude/skills/content-studio*`) | Plus new `sites/<X>/.claude/skills/creator-studio/DESIGN.md` per §2.5. |
| 8 | General convo | (no skill — default behaviour) | "Make the most useful interpretation, act" — already in bootstrap. |
| 9 | EOD nudges | `.claude/skills/eod-nudges/` | Reads sqlite eod_streaks table; replaces eod-streak-check.md guts. |
| 10 | Leave management | `.claude/skills/leave/` | Reads sqlite leave table; replaces `accountability/leave.md` + helpers. |
| 11 | User testing | `.claude/skills/user-testing/` | Replaces user-testing-capture.md guts; maintains `accountability/user-testing/issues-log.md`. |
| 12 | Bug reports | `.claude/skills/bug-tracking/` | Feeds `sites/tasks/intake/bugs.md` from 12:15 scan. |

**Per-skill file layout (proposed standard):**
```
.claude/skills/<goal>/
  SKILL.md            # what this skill does + when to load + voice + workflow
  references/         # data files the skill reads (account lists, strategy docs, etc.)
  templates/          # output templates (drafts, posts, table schemas)
  state-schema.md     # which sqlite tables this skill owns (if any)
```

### 2.4 SQLite for state (replaces scattered .json + .md state)

Single DB at `~/.config/claude/rapidnative-coach.sqlite`. Tables:

| Table | Owner skill | Replaces |
|---|---|---|
| `reminders` | scheduler | `accountability/reminders/*.md` |
| `leave_entries` | leave | `accountability/leave.md` |
| `holidays` | leave | `accountability/holidays.md` |
| `eod_streaks` | eod-nudges | (currently re-computed every run) |
| `user_testing_issues` | user-testing | `accountability/user-testing/issues-log.md` (kept as projection) |
| `bug_reports` | bug-tracking | scattered |
| `routine_runs` | scheduler | parse from /tmp/*.log |
| `tasks_cleanup_proposals` | task-management | `accountability/state/tasks-cleanup-proposal-*.json` |
| `marketing_recon` | growth-marketing | `marketing/.state/recon-*.json` |

plists stay for **scheduling** (cron is the right primitive). Skills read/write sqlite via a thin wrapper in `_lib.sh` (`db_query "SELECT …"`, `db_exec "INSERT …"`).

### 2.5 Creator Studio per site

Every linked site repo gets `.claude/skills/creator-studio/`:
```
creator-studio/
  DESIGN.md         # brand: colors, typography, voice, logo usage, do/don't
  banner.md         # banner template + dimensions per platform
  social-card.md    # OG image generation
  pitch-deck.md     # deck template
  references/       # brand assets, logos, color swatches
```

- `sites/rapidnative-website/` already has most of this scattered across `design-system/`, `marketing-design-system/`, `pitch-deck-design-system/`. Consolidate.
- `sites/applighter-website/` needs `.claude/skills/creator-studio/` created from scratch.
- `sites/letsdeploy.it/` needs to be added to `sites/` first (it's not there today), then receive the same.

The growth-marketing skill defers to these per-site creator studios for brand-specific output (e.g. "generate a LinkedIn banner for Applighter" → loads `sites/applighter-website/.claude/skills/creator-studio/`).

### 2.6 Slimmer routines

Every `accountability/routines/<X>.md` shrinks to:

```markdown
You are the <X> routine for rapidnative-coach.

# Step 0 — guards
source accountability/routines/_lib.sh
guard_working_day <X>   # if applicable

# Step 1 — load the skill
Read .claude/skills/<goal>/SKILL.md and follow it.

# Step 2 — post outcome to <channel>
slack-post.sh <channel_id> <<EOF
<output per skill format>
EOF
```

Cap: **80 lines max per routine file**. Anything longer → push into the skill.

### 2.7 Channel metadata gets richer

`channels/<name>.md` frontmatter extended:
```yaml
channel_id: C0BBQ7PV34N
name: marketing-automation
product: rapidnative           # NEW
owner: <@U09DC8L7PCZ>          # NEW
members: [<@U…>, <@U…>, …]     # NEW
allowed_routines: [marketing-morning, marketing-evening, marketing-recon]
allowed_skills: [growth-marketing]   # NEW — what coach is allowed to invoke here
voice_source: profile.md
```

Plus an optional `channels/<name>/memory.md` for per-channel learnings (e.g. "in #marketing, em-dashes are fine — overrides profile.md").

---

## 3. Refactor phases (do in order)

### Phase 0 — Definitions (1 day, no behaviour change)

1. Create `definitions/{company,people,products,channels,skills,routines}.md`. Populate from current scattered sources.
2. Add `_lib.sh` helpers: `lookup_handle`, `product_for_channel`, `skill_path`.
3. Update CLAUDE.md to say "for any team / product / channel / skill question, read `definitions/<X>.md` first; never infer".

**Acceptance:** `grep -r "sanket" .` shows `definitions/people.md` as the only source; other mentions are wikilinks back.

### Phase 1 — Top-level identity (½ day)

1. Create `COMPANY.md` (see §2.1). Add to `accountability/listener/bootstrap-prompt.md` Step 1 reading list AND `accountability/routines/run.sh` (cron also reads it).
2. Shrink `profile.md` to voice rules only. Keep pillars but tag them per-product.
3. **Add LetsDeployIt to `sites/` as a symlink** (matches existing pattern):
   ```bash
   cd ~/Documents && gh repo clone RapidNative/letsdeployit-website
   cd ~/Documents/rapidclaw/sites && ln -s ~/Documents/letsdeployit-website .
   ```
   (Other sites are symlinks too: rapidnative-website, applighter-website, tasks, branding. Pattern: real repo at `~/Documents/<name>/`, symlink at `sites/<name>`.)
4. Create `sites/applighter-website/.claude/skills/` scaffold (directory only — content arrives in Phase 4 when its DESIGN.md is ready).

**Acceptance:** Bot can answer "what does Shaper Studio Inc make?" naming all 3 products with their domains.

### Phase 2 — Skills migration (2-3 days, do one skill per PR)

Order (by hallucination impact):

1. **growth-marketing** (HIGHEST IMPACT — current 438-line recon + scattered marketing/* is the biggest hallucination source). Replaces `marketing/` directory + 4 routines.
2. **task-management** — codifies feed → sites/tasks/ flow + standup/EOD/user-testing scan. Replaces tasks-cleanup.md guts.
3. **leave** + **eod-nudges** (small, easy wins).
4. **user-testing**, **bug-tracking**, **newsletter**, **weekly-wrap** (medium effort).
5. **scheduler**, **repo-edit** (cross-cutting; do last).

Each migration is: write `SKILL.md`, replace routine body with thin loader, verify cron output unchanged for 3 days.

### Phase 3 — SQLite migration (1-2 days)

1. Create schema in `~/.config/claude/rapidnative-coach.sqlite`.
2. `bin/migrate-to-sqlite.py` — one-off backfill from current `.md` / `.json` state.
3. Skills updated to read sqlite (writes already routed via `_lib.sh` helpers from Phase 0).
4. Old state files kept read-only for 2 weeks, then archived.

### Phase 4 — Creator Studio per site (2 days)

**Key clarification from @sanket:** each repo will eventually own a `DESIGN.md` at its root. The coach-side `creator-studio` skill should be a *thin reader* that picks brand info up from `sites/<X>/DESIGN.md`, not a place where brand decisions are made.

1. **Coach side:** create `.claude/skills/creator-studio/SKILL.md` (one skill, not per-site). Its instructions: "given a target site `<X>`, run `sites-prepare.sh <X>`, then Read `sites/<X>/DESIGN.md` (if present) for brand voice/colors/type/logo, then proceed with the requested artifact."
2. **RapidNative:** consolidate the existing `sites/rapidnative-website/.claude/skills/design-system/`, `marketing-design-system/`, `pitch-deck-design-system/` into a `sites/rapidnative-website/DESIGN.md` at repo root. The per-skill dirs can stay for procedural depth; DESIGN.md becomes the brand canonical.
3. **Applighter:** `sites/applighter-website/DESIGN.md` — blocked on Sanket (brand audit). Until then, creator-studio gracefully degrades ("no DESIGN.md found — using generic brand defaults; recommend creating one before next artifact").
4. **LetsDeployIt:** `sites/letsdeployit-website/DESIGN.md` — same pattern, after Phase 1.3.
5. **Branding repo:** `sites/branding/DESIGN.md` if not already there — should be the cross-brand source of truth that per-site DESIGN.md files reference.

### Phase 5 — Channel metadata + memory (1 day)

1. Extend `channels/<name>.md` frontmatter per §2.7.
2. Add optional `channels/<name>/memory.md` files.
3. Update bootstrap to read channel memory in Step 1 (additive, not replacement).

### Phase 6 — Routine slimming + cleanup (1 day)

1. Audit all routines in `accountability/routines/*.md`; enforce ≤80-line cap. Anything over → push into skill.
2. **Delete `marketing/` directory** (per decision O4 — keep until everything is migrated; this is "everything is migrated"). Backup branch first.
3. Archive `accountability/state/*.json` → `accountability/state/.archive/` (read-only). Remove old `.md` projections of state that now live in sqlite, unless a skill still reads them as a projection.
4. Final pass on routine list: confirm `definitions/routines.md` matches `launchd/com.agni.*.plist` 1:1.

**Acceptance:** `wc -l accountability/routines/*.md` shows every file ≤80. `marketing/` is gone. `definitions/routines.md` matches plists.

---

## 4. Anti-hallucination measures (called out explicitly)

These are the levers this refactor pulls:

1. **One canonical source per fact.** Six-team-roster problem disappears.
2. **Lazy skill loading.** Bootstrap stops loading 500 lines on every turn; it loads the index, then skills load on match.
3. **Structured state in sqlite.** No more "is this `.json` or `.md` the source of truth?".
4. **Per-brand strategy files.** Growth-marketing scan for Applighter only loads Applighter's strategy, not all three brands.
5. **Skills with explicit "when to load" frontmatter.** Claude has a decision tree, not a vibes check.
6. **Routine cap at 80 lines.** Forces concerns to live in the right place.
7. **Per-channel `allowed_skills`.** Coach is gated from invoking out-of-scope skills in a channel (e.g. can't run growth-marketing in #user-testing).

---

## 5. Decisions on the original 7 open questions

All resolved by @sanket on 2026-06-25 (reply `1782382986.101679`). Canonical log: `drafts/2026-06-25-architecture-refactor/decisions.md`.

| # | Question | Decision |
|---|---|---|
| O1 | LetsDeployIt repo location | Symlink, matching existing pattern. Repo: `https://github.com/RapidNative/letsdeployit-website`. Clone to `~/Documents/letsdeployit-website`, symlink into `sites/`. |
| O2 | Applighter brand audit | Each repo will eventually own a `DESIGN.md` at its root. `creator-studio` skill is a thin reader that picks brand info up from there. Don't author brand decisions in coach. |
| O3 | SQLite location | `~/.config/claude/rapidnative-coach.sqlite` — confirmed. |
| O4 | Fate of `marketing/` dir | Keep until everything is migrated; delete in a final cleanup pass at the end of Phase 2. |
| O5 | Channel `members` list | Hand-maintained. Use the existing roster sources (.env TEAM_USERS, marketing/team.md, sites/tasks/roles.md, auto-memory project_team_roster) — Phase 0 consolidates them into `definitions/people.md`. Channel frontmatter references handles from there. No Slack API sync. |
| O6 | Index per-site skills in `definitions/skills.md` | Yes. Main coach reads them directly (post-reframe), so the index is the discovery surface. |
| O7 | Migration safety (branch + shadow-cron) | Deferred — Sanket unsure. **Proposed default:** in-place on main, one phase per PR. Phase 0 is no-behaviour-change (zero risk). Phase 1+ migrations: do one skill at a time, run the new path + the old in parallel for 1 cron cycle, smoke-test the new output, then delete the old. No full shadow-cron infrastructure unless we hit a regression. |

---

## 6. What this does NOT change

- Listener.js / Socket Mode setup (untouched until/unless Phase 7 subagent handoff mode is built)
- Per-thread git worktree mechanism
- launchd cron scheduling primitive
- Tool layer (slack-*, browser-open, gh, render-html, gen-image)
- Permission tier model (owner / superadmin / teammate / unknown)
- sites/ symlink pattern
- Auto-memory mechanism (cross-session learnings via `~/.claude/projects/<encoded-cwd>/memory/`)

Those are working. Don't touch.

---

## 7. Phase 7 (deferred — only on concrete need)

Subagent infrastructure: `.claude/agents/<name>.md` files, centralised `accountability/routines/agent-heartbeat.sh`, listener handoff/handback routing. Per the skills-first reframe, this isn't critical path. Build it when a real use case forces it. Full design lives in `subagents.md`.
