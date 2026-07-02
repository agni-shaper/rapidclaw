---
name: growth-marketing
description: Umbrella skill for distribution / growth ops across all 3 Shaper Studio products (RapidNative, Applighter, LetsDeployIt). Dispatches to sub-skills for the specific mode of growth work — social-engagement, newsletter, weekly-wrap, blogs. Owns cross-cutting brand voice + anti-hallucination rules.
when_to_load: |
  Load when ANY of the following:
  - The active channel is #marketing (C09F377FGFK) or #marketing-automation (C0BBQ7PV34N)
  - A cron routine is firing that touches growth work — see the sub-skill table below for which routine maps to which sub-skill.
  - The user asks about: distribution, growth, marketing copy, ad copy, GTM picks, marketing strategy, brand voice
  - The user asks "where should we promote X" or names a specific channel of growth (social, newsletter, blog, weekly recap, PR / awards / directories)

  After loading THIS umbrella, immediately Read the sub-skill(s) that match the request — this file is a dispatcher, not the working instructions.
voice_source: ../../profile.md
---

# growth-marketing (umbrella)

The parent skill for **everything distribution + growth** across Shaper Studio Inc's 3 products. Replaces the scattered `marketing/` directory.

This SKILL.md is deliberately a **dispatcher** — it tells you which sub-skill to read for the task at hand. The real workflow content lives in the sub-skill `SKILL.md` files.

## Sub-skill map

| Sub-skill | Read when… | Loaded by (cron / manual) |
|---|---|---|
| [`social-engagement/`](social-engagement/SKILL.md) | Daily social distribution — HN, Reddit, Quora, LinkedIn, X, dev.to, GFG, Hashnode, Substack, Vocal, Facebook. Persona rotations, engagement drafts, sprint templates. | `marketing-recon` (06:00), `marketing-morning` (07:00), `marketing-evening` (19:30) Mon–Fri · `gtm-weekly-pick` · `biweekly-shoutouts` |
| [`newsletter/`](newsletter/SKILL.md) | Cross-product newsletter cycle — prep, draft, approve, send. Sources from `drafts/newsletter-next/items.md`. | manual (no cron yet — pending Sanket's answers on cadence + send tool) |
| [`weekly-wrap/`](weekly-wrap/SKILL.md) | Friday recap composer — what shipped + key metrics across all 3 products. | `cross-channel/weekly-wrap.md` (invoked on-demand from Slack) |
| [`blogs/`](blogs/SKILL.md) | Blog authoring + amplification (currently placeholder; real routines still ad-hoc). | `blog-internal` (12:00), `blog-external` (11:00) Mon–Fri |

## Cross-cutting rules (apply to every sub-skill)

**Always load** [`../../COMPANY.md`](../../COMPANY.md) and [`../../profile.md`](../../profile.md) first (bootstrap already does this).

### Per-brand voice (across all sub-skills)

- **RapidNative** voice: technical, builder-to-builder, anchored in React Native + AI coding tooling. See [`social-engagement/references/strategies/rapidnative.md`](social-engagement/references/strategies/rapidnative.md).
- **Applighter** voice: ship-fast-to-revenue, full-stack template seller. See [`social-engagement/references/strategies/applighter.md`](social-engagement/references/strategies/applighter.md) (stub — brand audit pending).
- **LetsDeployIt** voice: pain-of-mobile-deploy, fastlane/EAS/TestFlight angle. See [`social-engagement/references/strategies/letsdeployit.md`](social-engagement/references/strategies/letsdeployit.md) (stub).

Cross-brand defaults from `profile.md`: no em-dashes, no hashtags-the-user-didn't-ask-for, no corporate buzzwords, no "let me know if I can help", concise, specifics over generics.

> Note: `strategies/` currently lives under `social-engagement/` because social was the first sub-skill to need them. If a future sub-skill (blogs, newsletter) needs the same per-brand strategies, we'll hoist `strategies/` up to `growth-marketing/references/strategies/` at that point. Reachable from any sub-skill via relative paths.

### Anti-hallucination invariants

1. **Never invent a persona account.** Look up in [`social-engagement/references/accounts.md`](social-engagement/references/accounts.md). If missing, ask.
2. **Never invent a Slack ID or handle.** Use `lookup_slack_id` / `lookup_handle` from `_lib.sh`. Roster: `definitions/people.md`.
3. **Never invent a product strategy claim.** If the strategy file is a stub, say so in the draft.
4. **Never burn the same account two days in a row** on the same platform. Use the rotation formula in [`social-engagement/references/rotation.md`](social-engagement/references/rotation.md).
5. **Always cite source URL** when drafting a comment or reply.

## What this umbrella does NOT own

- **Brand assets** (banners, logos, social cards) — that's `creator-studio` (Phase 4) + per-site `content-studio*` skills.
- **Tasks / assignments** — that's `task-management` + `sites/tasks/`.
- **Long-form blog drafting mechanics** — currently in the `blog-internal` / `blog-external` routine bodies + `sites/rapidnative-website/.claude/skills/content-studio-*` skills; blogs sub-skill is a placeholder for future migration.

## Skill loader note (why the nesting)

Claude Code auto-discovers `.claude/skills/<name>/SKILL.md` at the top level only. Nested `SKILL.md` files under sub-skill directories are NOT surfaced in the harness's `<available-skills>` list. That's deliberate: sub-skills are loaded **via this umbrella**, not directly. If you need to force-load a specific sub-skill, Read its SKILL.md path directly.
