# Products

The 4 products Shaper Studio Inc ships. Every product-aware skill, routine, channel, and growth strategy keys off this file.

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
| GitHub | **UNCONFIRMED.** @sanket gave `https://github.com/RapidNative/letsdeployit-website` 2026-06-25 but `gh repo list RapidNative` shows no such repo on 2026-06-29. Pending confirmation. |
| Local clone | not yet cloned |
| Coach pointer | `sites/letsdeployit-website.md` — pointer file (per CLAUDE.md "Linked projects" rules) until the repo is locatable. When confirmed, this gets swapped for a symlink. |
| Brand canonical | `sites/letsdeployit-website/DESIGN.md` (future; Phase 4) |
| Lead | `@sanket` (interim) |
| Primary channels | `#marketing` (cross-product) |
| Per-site skills today | none |

## Tinbase

| Field | Value |
|---|---|
| Slug | `tinbase` |
| Domain | https://tinbase.dev |
| What it is | Local-Postgres / Supabase-without-Docker: single ~58 MB executable, real Postgres 17 + auth + realtime + edge functions + webhooks + cron, works with `supabase-js` unchanged, ~100 MB RAM (vs Docker Supabase's ~1.6 GB). MIT open source. |
| GitHub | TBD — pending owner handover |
| Local clone | not yet cloned |
| Coach pointer | none yet (no `sites/tinbase-website` linked project). Content production lives in the coach's shared drafting for now. |
| Brand canonical | not yet |
| Lead | `@famitha` (interim — day-to-day marketing owner; social handles + GitHub / mailbox provisioning pending from owner) |
| Social handles | X: TBD · LinkedIn: TBD (owner will provide) |
| Primary channels | `#rn-coach-social` (daily marketing tasks), `#marketing` (cross-product coordination) |
| Marketing crew opted in | `@famitha`, `@russel` only (per `accounts.md` `products:` line). `@sanket` + `@rishav` skip Tinbase. |
| Daily task volume | 10 templates/day × 2 crew = 20 tasks/day (twice the per-product template count of RN/AL/LDI because only 2 crews cover it) |
| Per-site skills today | none |

## Shared / cross-product

| Repo | Purpose |
|---|---|
| `sites/branding` → `~/Documents/branding/` | Cross-brand source of truth for logos, palette, type. Per-site `DESIGN.md` files reference this. Strict workflow in its own `AGENTS.md`. |

## Bot ↔ product channel mapping

Quick lookup — which channel maps to which product? See [`channels.md`](channels.md) for the full registry with channel IDs.

| Channel | Product(s) |
|---|---|
| `#rapidnative-coach` | rapidnative (bot home; also catch-all) |
| `#ai-blogs`, `#bi-reports`, `#seo`, `#user-testing` | rapidnative |
| `#marketing` | all 4 (general coordination) |
| `#marketing-automation` | all 4 (daily distribution crew — Growth Squad v2) |
| `#affiliate-marketing` | applighter, rapidnative (where affiliates make sense) |
| `#collabs-and-partnerships` | all 4 |
| `#rn-coach-social` | all 4 (daily marketing task ledger — cross-product) |
| `#community-building`, `#design`, `#eod-updates`, `#tasks`, `#lead-magnets` | cross-product / company-wide |

## How skills + routines should use this

A skill that operates on a specific product (e.g. growth-marketing) should:

1. Read this file to know which 4 brands exist
2. For each brand, load `references/strategies/<slug>.md` inside the skill
3. For brand-specific output, defer to the site's `sites/<slug>-website/DESIGN.md` (and the per-site `.claude/skills/creator-studio/` if present)

A routine fired in `#marketing-automation` should iterate over all 4 products in turn; one fired in `#bi-reports` should only consider `rapidnative`.
