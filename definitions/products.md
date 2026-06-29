# Products

The 3 products Shaper Studio Inc ships. Every product-aware skill, routine, channel, and growth strategy keys off this file.

## RapidNative (primary)

| Field | Value |
|---|---|
| Slug | `rapidnative` |
| Domain | https://rapidnative.com |
| What it is | React Native app builder / boilerplate |
| GitHub | `RapidNative/rapidnative-website` |
| Local clone | `/Users/agni/Documents/rapidnative-website/` |
| Coach symlink | `sites/rapidnative-website` |
| Brand canonical | `sites/rapidnative-website/DESIGN.md` (to be created; see Phase 4) |
| Lead | `@sanket` (CEO) |
| Primary channels | `#rapidnative-coach` (bot home), `#marketing`, `#ai-blogs`, `#bi-reports`, `#seo`, `#user-testing` |
| Per-site skills today | ~30 under `sites/rapidnative-website/.claude/skills/` — content-studio*, bi-*, saas-*, design-system, marketing-design-system, writing-style, etc. See `skills.md`. |

## Applighter

| Field | Value |
|---|---|
| Slug | `applighter` |
| Domain | https://applighter.com |
| What it is | Full-stack templates store |
| GitHub | (private — owned by Shaper Studio Inc) |
| Local clone | `/Users/agni/Documents/applighter-website/` |
| Coach symlink | `sites/applighter-website` |
| Brand canonical | `sites/applighter-website/DESIGN.md` (NOT YET — blocked on @sanket brand audit; Phase 4) |
| Lead | `@sanket` (interim) |
| Primary channels | `#marketing` (cross-product), `#affiliate-marketing` |
| Per-site skills today | `.claude/` directory does not exist yet. Phase 1 scaffolds it. |

## LetsDeployIt

| Field | Value |
|---|---|
| Slug | `letsdeployit` |
| Domain | https://letsdeploy.it |
| What it is | Mobile-app deploy service |
| GitHub | `RapidNative/letsdeployit-website` (https://github.com/RapidNative/letsdeployit-website) |
| Local clone | `/Users/agni/Documents/letsdeployit-website/` (NOT YET CLONED — Phase 1) |
| Coach symlink | `sites/letsdeployit-website` (NOT YET — Phase 1) |
| Brand canonical | `sites/letsdeployit-website/DESIGN.md` (NOT YET; Phase 4) |
| Lead | `@sanket` (interim) |
| Primary channels | `#marketing` (cross-product) |
| Per-site skills today | none. To be created in Phase 4. |

## Shared / cross-product

| Repo | Purpose |
|---|---|
| `sites/branding` → `~/Documents/branding/` | Cross-brand source of truth for logos, palette, type. Per-site `DESIGN.md` files reference this. Strict workflow in its own `AGENTS.md`. |
| `sites/tasks` → `~/Documents/tasks/` | Team-wide sprint repo (planning/, intake/, epics/, programs/). Has its own `CLAUDE.md` + `roles.md` + notification queue (`intake/unsent-notifications.md`). Two-tier interaction: this bot feeds data in; the tasks repo's own scripts (`bin/send-notifications.py`) emit Slack notifications. |

## Bot ↔ product channel mapping

Quick lookup — which channel maps to which product? See [`channels.md`](channels.md) for the full registry with channel IDs.

| Channel | Product(s) |
|---|---|
| `#rapidnative-coach` | rapidnative (bot home; also catch-all) |
| `#ai-blogs`, `#bi-reports`, `#seo`, `#user-testing` | rapidnative |
| `#marketing` | all 3 (general coordination) |
| `#marketing-automation` | all 3 (daily distribution crew — Growth Squad v2) |
| `#affiliate-marketing` | applighter, rapidnative (where affiliates make sense) |
| `#collabs-and-partnerships` | all 3 |
| `#community-building`, `#design`, `#eod-updates`, `#tasks`, `#lead-magnets`, `#rn-coach-social` | cross-product / company-wide |

## How skills + routines should use this

A skill that operates on a specific product (e.g. growth-marketing) should:

1. Read this file to know which 3 brands exist
2. For each brand, load `references/strategies/<slug>.md` inside the skill
3. For brand-specific output, defer to the site's `sites/<slug>-website/DESIGN.md` (and the per-site `.claude/skills/creator-studio/` if present)

A routine fired in `#marketing-automation` should iterate over all 3 products in turn; one fired in `#bi-reports` should only consider `rapidnative`.
