# Skills

Registry of skills the bot can load. Skills are the **primary composition mechanism** for capabilities — per the skills-first reframe (see `drafts/2026-06-25-architecture-refactor/decisions.md`), most work happens in the main coach context with skills loaded inline. Subagents are an escape hatch for one-shot artifact generation.

## How to use this file

When the main coach receives a request, it should:

1. Match the request to one of the **coach skills** below — if found, Read that skill's `SKILL.md` and follow it.
2. If the request touches a specific product, additionally Read the relevant **per-site skill(s)** for that product.
3. A skill may Read further references / templates / sub-skills recursively. That's the "skills that load more skills" pattern.

## Coach skills  (`.claude/skills/<name>/SKILL.md`)

**Not all of these exist yet.** Phase 2 of the architecture refactor creates them in this order (see `drafts/2026-06-25-architecture-refactor/plan.md`).

| Skill | Status | What it owns | Replaces | Channels |
|---|---|---|---|---|
| `growth-marketing` | **LIVE — umbrella (restructured 2026-07-01)** — dispatcher for 4 nested sub-skills. Loaded by marketing-recon, marketing-morning, marketing-evening, gtm-weekly-pick, biweekly-shoutouts (all in cron). Cross-cutting brand voice + anti-hallucination rules live at the umbrella; workflow content is in the sub-skills. | Umbrella for all distribution / growth ops. Sub-skills: `social-engagement/` (daily platform cycle · LIVE), `newsletter/` (scaffolded), `weekly-wrap/` (scaffolded), `blogs/` (placeholder). | `marketing/` directory + `marketing-morning`/`evening`/`recon` routines body + top-level `newsletter/` + top-level `weekly-wrap/` (both moved under this umbrella 2026-07-01) | `#marketing-automation`, `#marketing` |
| `tasks` | **LIVE — sqlite cutover 2026-07-02; renamed from `task-management` + colocated shell dispatcher 2026-07-06** — loaded by tasks-cleanup (in cron) + gtm-weekly-pick (post-approval route flow) + Slack listener for ad-hoc "assign X to @Y" requests. Tier A feeder + Tier B DB (sqlite `tasks` via `.claude/skills/tasks/bin/tasks.sh`) split. Also owns the CRUD contract for other skills — see § "For skills that call `tasks.sh`". Replaces the previous `sites/tasks/` markdown flow (archival). | Feed sqlite `tasks` from #standup, #eod, #user-testing, git logs. 12:15 IST cleanup proposal. CRUD API for bug-tracking / user-testing / task-assistance / growth-marketing. | `tasks-cleanup` routine body + previous `sites/tasks/` write path | `#tasks`, `#rapidnative-coach` |
| `leave` | **LIVE — sqlite-only since 2026-06-30** — used by every team-facing v2 routine via `is_on_leave` / `is_holiday` (both sqlite-backed now). CRUD via `leave-{add,rm,list}.sh` and `holiday-{add,rm,list}.sh` in `accountability/routines/`. Removals are soft (`status='past'`). | Sqlite `leave_entries` + `holidays` CRUD. `is_on_leave`, `is_working_day`. | `accountability/leave.md` + `accountability/holidays.md` (deleted) | any team-facing |
| `eod-nudges` | **LIVE (Phase 2 + plist cutover 2026-06-29)** — loaded by eod-streak-check (in cron). Threshold raised 2→3 wd 2026-06-30. Composes with leave skill. | Detect missing EOD posts, ping with leave-awareness. | `eod-streak-check` body | `#eod-updates` |
| `user-testing` | **LIVE (Phase 2 + plist cutover 2026-06-30)** — loaded by user-testing-capture (in cron). Read-only against #user-testing; write-only against issues-log.md (post-approval). Bug-vs-UX split rule composes with bug-tracking. Sqlite `user_testing_issues` table dropped 2026-06-30 — md stays the source until scale demands it. | Daily diff of `#user-testing`, projection to `accountability/user-testing/issues-log.md`. | `user-testing-capture` body | `#user-testing` |
| `growth-marketing/weekly-wrap` | **SCAFFOLDED — NOT IN CRON (sub-skill of `growth-marketing` since 2026-07-01)** — invoked on-demand via cross-channel routine `accountability/routines/cross-channel/weekly-wrap.md`. Defers to RN site's content-studio-generate-weekly-wrap skill. Not auto-discovered — reached via umbrella dispatch or `Read`. | Cross-channel composer for marketing-team Friday recap. | `accountability/routines/cross-channel/weekly-wrap.md` + `sites/rapidnative-website/.claude/skills/content-studio-generate-weekly-wrap` | source thread → `#marketing` |
| `growth-marketing/newsletter` | **SCAFFOLDED — DESIGN ONLY (sub-skill of `growth-marketing` since 2026-07-01)** — `.claude/skills/growth-marketing/newsletter/SKILL.md`. No cron, no send action; pending Sanket's answers on cadence, send tool (Resend/Loops/Substack/Beehiiv?), audience segmentation, approval tier. Not auto-discovered. | Drafts/newsletter-next/ cycle (prep, draft, approve, send). | ad-hoc `drafts/newsletter-next/` dir | (target channel TBD) |
| `growth-marketing/social-engagement` | **LIVE — orchestrator sub-skill (since 2026-07-01; per-product split 2026-07-02)** — shared mechanics + product-agnostic references. Now dispatches to three nested per-product sub-skills (`-rapidnative` / `-applighter` / `-letsdeployit`) for product-specific voice + config. Runtime (`gen-marketing-morning.py`) still reads per-product config directly from `references/products/*.md` — Phase 2 will move to `create-social-eng-task.sh --product <slug>` invoking the engine per product. | Daily social platform cycle. Holds shared `references/{accounts,rotation,config,sprint,task-templates}.md`. Per-product `products/*.md` + `strategies/*.md` still under this dir; per-product SKILL.md docs live in the nested sub-skills. | (was `growth-marketing/references/*` pre-2026-07-01; sub-skill split adds nested SKILL.md files 2026-07-02) | `#marketing-automation` |
| `growth-marketing/social-engagement/social-engagement-rapidnative` | **LIVE — docs-only nested sub-skill (since 2026-07-02)** — RapidNative-specific voice + platform priority + anti-hallucination guards. Read by the orchestrator + ad-hoc when the user asks about RN social copy. Not auto-discovered. | RN social voice + product-specific guards + platform priority. | (was mixed into `social-engagement/SKILL.md` and `strategies/rapidnative.md` pre-split) | `#marketing-automation` |
| `growth-marketing/social-engagement/social-engagement-applighter` | **LIVE — docs-only nested sub-skill (since 2026-07-02)** — Applighter-specific voice + templates/AI-quality angle + RN-overlap dedupe guidance. Not auto-discovered. | Applighter social voice + product-specific guards. Note: strategy stub — brand audit pending. | (was mixed into parent SKILL.md and `strategies/applighter.md`) | `#marketing-automation` |
| `growth-marketing/social-engagement/social-engagement-letsdeployit` | **LIVE — docs-only nested sub-skill (since 2026-07-02)** — LetsDeployIt-specific voice + deploy-lifecycle angle (App Store rejections, ASO, TestFlight/EAS Submit). Not auto-discovered. | LDI social voice + product-specific guards. Note: strategy stub — repo not yet located. | (was mixed into parent SKILL.md and `strategies/letsdeployit.md`) | `#marketing-automation` |
| `growth-marketing/blogs` | **PLACEHOLDER — sub-skill scaffold (since 2026-07-01)** — real blog authoring still runs through `blog-internal`/`blog-external` routines + `sites/rapidnative-website/.claude/skills/content-studio-*`. This scaffold exists to give future blog voice/templates a home. | Blog authoring + amplification. | (currently ad-hoc in `blog-internal`/`blog-external`) | `#marketing-automation`, `#ai-blog` |
| `bug-tracking` | **LIVE — sqlite cutover 2026-07-02** — referenced by `tasks` skill when bug-shaped signals are detected; no standalone routine. Bugs are sqlite `tasks` rows with `category='bug'`, written via `tasks.sh` per the `tasks` skill CRUD contract. Replaces `sites/tasks/intake/bugs.md` (archival). | 12:15 scan feeds sqlite `tasks` rows with `category='bug'`. | (currently part of tasks-cleanup) | `#rapidnative-coach`, `#tasks` |
| `scheduler` | **LIVE — sqlite-only since 2026-06-30** — owns `reminders` + `routine_runs` tables. CRUD via `reminder-{add,list,cancel}.sh` in `accountability/routines/`. `daily.md` Step 0 queries sqlite each morning + marks rows `fired`. Markdown reminder files retired. | Sqlite `reminders` + `routine_runs` CRUD. plists still fire cron; state lives in DB. | `accountability/reminders/*.md` (deleted) + `accountability/state/*.json` (already migrated) | (utility, not channel-bound) |
| `creator-studio` | TODO | Thin reader. Given a target site, runs `sites-prepare.sh`, Reads `sites/<X>/DESIGN.md`, then generates the requested artifact (banner, social card, deck). Defers brand decisions to the site's DESIGN.md. | (none — new) | wherever |
| `repo-edit` | **SCAFFOLDED — REFERENCE-ONLY (Phase 2)** — procedural guidance loaded inline when site repo edits happen. 7 hard rules called out. | Procedural guidance for `sites-prepare.sh` → branch → PR. Defers actual work to per-site skills. | (CLAUDE.md "Linked projects" section) | wherever |

## Per-site skills

These are owned by the linked-site repos. The main coach reads them directly via `sites-prepare.sh <X>` then `Read sites/<X>/.claude/skills/<skill>/SKILL.md`. The site doesn't get its own subagent unless it has async PR work to do (see Phase 7).

### `sites/rapidnative-website/.claude/skills/` (~30 skills today)

**Content / writing**
- `content-studio` · `content-studio-carousel` · `content-studio-generate-feature-post` · `content-studio-generate-weekly-wrap` · `content-studio-linkedin-post` · `content-studio-x-thread` · `content-studio-video`
- `writing-style` — voice rules for long-form

**Design / brand**
- `design-system` · `marketing-design-system` · `pitch-deck-design-system`
- (Phase 4 will consolidate these under a `sites/rapidnative-website/DESIGN.md` brand canonical that the coach `creator-studio` skill reads.)

**Business intelligence**
- `bi` · `bi-customer-profile` · `bi-ghost-recon` · `bi-latest-projects` · `bi-mrr-overview` · `bi-project-lookup` · `bi-project-screens` · `bi-signup-funnel` · `bi-user-projects`

**SaaS plumbing**
- `saas-add-plan` · `saas-checkout-integration.md` · `saas-credit-buckets.md` · `saas-flow-diagram-review` · `saas-integration-overview.md` · `saas-migrate-subscription-tier` · `saas-schema.md` · `saas-upgrade-downgrade.md` · `saas-webhook-integration.md`

**Other**
- `free-tool` — pattern for free-tool pages
- `supabase-migration` — schema migration patterns
- `remotion-best-practices` · `remotion-patterns` — Remotion (video) patterns
- `debug` · `repository-refactor`

### `sites/applighter-website/.claude/skills/`

**Does not exist yet.** Phase 1 scaffolds it. Initial content lands in Phase 4 (creator-studio + content-studio variants, blocked on brand audit from @sanket).

### `sites/letsdeployit-website/.claude/skills/`

Repo not yet cloned. Phase 1 of the refactor clones from `https://github.com/RapidNative/letsdeployit-website` and symlinks into `sites/`. Skills come later.

### `sites/tasks/.claude/skills/`

Currently empty. The tasks repo's intelligence lives in its `CLAUDE.md` + `agents/bot-god/` + `recurring/` definitions rather than as skills.

### `sites/branding/`

Strict workflow in its own `AGENTS.md`. Future Phase 4 work creates `sites/branding/DESIGN.md` as the cross-brand canonical that per-site DESIGN.md files reference.

## Harness skills (always available)

These come from the Claude Code harness, not this repo. They're loaded by Claude on match without coach intervention:

- `init` · `review` · `security-review` · `simplify`
- `schedule` · `loop`
- `update-config` · `keybindings-help`
- `fewer-permission-prompts` · `claude-api`

(Not the same as coach skills — those are in this codebase. These are at `~/.claude/skills/` or equivalent.)

## Skill authoring conventions

When creating a new skill in Phase 2+:

```
.claude/skills/<name>/
  SKILL.md         # what this skill does, when to load, voice, workflow
  references/      # data files the skill reads (account lists, strategy docs, etc.)
  templates/       # output templates (drafts, posts, table schemas)
  state-schema.md  # sqlite tables this skill owns (if any)
```

`SKILL.md` frontmatter format (Claude Code standard):

```yaml
---
name: growth-marketing
description: Distribution / growth ops across the 3 Shaper Studio products. Owns per-brand strategies and per-account references.
when_to_load: |
  - any request touching marketing, distribution, growth, comments, social copy
  - any cron fire of marketing-morning / marketing-evening / marketing-recon / gtm-weekly-pick / biweekly-shoutouts
---
```
