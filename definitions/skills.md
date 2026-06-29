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
| `growth-marketing` | **SCAFFOLDED (Phase 2 start, 2026-06-29)** — SKILL.md + 3 brand strategies + accounts.md + rotation.md + config.md pointer all created at `.claude/skills/growth-marketing/`. Routine .md replacement pending (one routine at a time, side-by-side test). | Distribution / growth ops across all 3 products. Per-brand strategies + per-account references. | `marketing/` directory + `marketing-morning`/`evening`/`recon` routines body | `#marketing-automation`, `#marketing` |
| `task-management` | TODO | Feed `sites/tasks/` from #standup, #eod, #user-testing, git logs. 12:15 IST cleanup proposal. | `tasks-cleanup` routine body | `#tasks`, `#rapidnative-coach` |
| `leave` | **SCAFFOLDED (Phase 2, 2026-06-29)** — `.claude/skills/leave/SKILL.md`. Documents current grep-based behavior + Phase 3 sqlite migration schema. Helpers in `_lib.sh` already canonical; SKILL.md is the human-readable contract. | Sqlite leave_entries + holidays CRUD. `is_on_leave`, `is_working_day`. | `accountability/leave.md` + `accountability/holidays.md` (kept as projections) | any team-facing |
| `eod-nudges` | **SCAFFOLDED (Phase 2, 2026-06-29)** — `.claude/skills/eod-nudges/SKILL.md`. Composes with `leave` skill; sketches Phase 3 sqlite eod_streaks schema. Routine .md replacement pending. | Detect missing EOD posts, ping with leave-awareness. | `eod-streak-check` body | `#eod-updates` |
| `user-testing` | TODO | Daily diff of `#user-testing`, projection to `accountability/user-testing/issues-log.md`. | `user-testing-capture` body | `#user-testing` |
| `weekly-wrap` | **SCAFFOLDED (Phase 2, 2026-06-29)** — `.claude/skills/weekly-wrap/SKILL.md`. Defers brand-voice/structure to the RN site's existing `content-studio-generate-weekly-wrap` skill. Cross-channel approval-gate routine still owns workflow. | Cross-channel composer for marketing-team Friday recap. | `accountability/routines/cross-channel/weekly-wrap.md` + `sites/rapidnative-website/.claude/skills/content-studio-generate-weekly-wrap` | source thread → `#marketing` |
| `newsletter` | TODO | Drafts/newsletter-next/ cycle (prep, draft, approve, send). | ad-hoc `drafts/newsletter-next/` dir | (target channel TBD) |
| `bug-tracking` | TODO | 12:15 scan feeds `sites/tasks/intake/bugs.md`. | (currently part of tasks-cleanup) | `#rapidnative-coach`, `#tasks` |
| `scheduler` | TODO | Sqlite reminders + routine_runs CRUD. plists still fire cron; state moves to DB. | `accountability/reminders/*.md` + `accountability/state/*.json` | (utility, not channel-bound) |
| `creator-studio` | TODO | Thin reader. Given a target site, runs `sites-prepare.sh`, Reads `sites/<X>/DESIGN.md`, then generates the requested artifact (banner, social card, deck). Defers brand decisions to the site's DESIGN.md. | (none — new) | wherever |
| `repo-edit` | TODO | Procedural guidance for `sites-prepare.sh` → branch → PR. Defers actual work to per-site skills. | (CLAUDE.md "Linked projects" section) | wherever |

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
