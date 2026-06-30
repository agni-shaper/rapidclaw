---
name: growth-marketing
description: Distribution / growth ops across all 3 Shaper Studio products (RapidNative, Applighter, LetsDeployIt). Owns per-brand strategies + per-crew-member account inventories + the daily distribution cycle. Replaces the current marketing/ directory.
when_to_load: |
  Load when ANY of the following:
  - The active channel is #marketing (C09F377FGFK) or #marketing-automation (C0BBQ7PV34N)
  - A cron routine is firing: marketing-recon, marketing-morning, marketing-evening, gtm-weekly-pick, biweekly-shoutouts
  - The user asks about: distribution, growth, marketing copy, social posts, ad copy, GTM picks, marketing recon, comment drafts, persona accounts, weekly rotation, marketing strategy
  - The user asks "where should we promote X" or names a specific platform (HN, Reddit, Quora, LinkedIn, X, dev.to, Medium, Hashnode, Substack, Vocal)
voice_source: ../../profile.md
---

# growth-marketing

The skill that owns *everything* related to distribution and growth ops for Shaper Studio Inc's 3 products. Designed to replace the scattered `marketing/` directory (still present as the legacy source; will be deleted in Phase 6 of the architecture refactor once migration completes).

## Read these before doing any work

The skill itself is a thin orchestrator. Real content lives in scoped reference files — load only what the current task needs.

1. **Always:** [`../../../COMPANY.md`](../../../COMPANY.md) and [`../../../profile.md`](../../../profile.md) (already loaded by bootstrap)
2. **Per product** (only the one(s) the task touches):
   - RapidNative → [`references/strategies/rapidnative.md`](references/strategies/rapidnative.md)
   - Applighter → [`references/strategies/applighter.md`](references/strategies/applighter.md)
   - LetsDeployIt → [`references/strategies/letsdeployit.md`](references/strategies/letsdeployit.md)
3. **For the daily distribution cycle (marketing-morning / evening / recon):**
   - [`references/accounts.md`](references/accounts.md) — per-crew named persona accounts
   - [`references/rotation.md`](references/rotation.md) — weekly 3-account-pool formula
   - [`references/config.md`](references/config.md) — SEO domains, mailboxes, standing URLs
4. **Per platform** (only the platform(s) today's slate needs):
   - HN, Reddit, Quora, LinkedIn, X, Medium, dev.to, GFG, Hashnode, Substack, Vocal, Facebook → [`references/platforms/<platform>.md`](references/platforms/) (created on demand; today these live as TPL-* sections in [`references/task-templates.md`](references/task-templates.md))

## What this skill does NOT do

- It does not generate brand assets (banners, logos, social cards). That's the `creator-studio` skill (Phase 4). When growth-marketing needs an artifact, it delegates by Reading the relevant site repo's `creator-studio` skill — or invokes a one-shot subagent (`render-html.sh` / `gen-image.sh`) for ad-hoc images.
- It does not manage tasks or task assignments. Tasks-related ops live in the `task-management` skill + `sites/tasks/` repo.
- It does not draft long-form blog content. Internal blogs flow through `blog-internal` / `blog-external` routines + `sites/rapidnative-website/.claude/skills/content-studio-*` skills.

## Daily distribution cycle (the spine)

Three routines fire daily Mon–Fri IST:

```
06:00 IST              07:00 IST                   19:30 IST
┌──────────────────┐  ┌─────────────────────────┐  ┌──────────────────────────┐
│ marketing-recon  │  │ marketing-morning       │  │ marketing-evening        │
│                  │  │                         │  │                          │
│ • scan platforms │  │ • read sprint + carry   │  │ • read sentinel per-crew │
│   for relevant   │  │ • skip on-leave crew    │  │ • per-crew: read thread  │
│   threads/posts  │  │ • expand templates per  │  │   replies, parse "done   │
│ • draft a        │  │   account rotation      │  │   T01, T03" claims       │
│   suggested      │  │ • inject recon findings │  │ • write evening-tasks +  │
│   comment per    │  │ • post per-crew task    │  │   per-crew carryover     │
│   finding        │  │   slate as top-level    │  │ • append tracker rows    │
│ • write to cache │  │   msgs in #marketing-   │  │ • post top-level EOD     │
│   marketing/     │  │   automation             │  │   recap                  │
│   .state/recon-  │  │                         │  │                          │
│   YYYY-MM-DD.json│  │                         │  │                          │
└──────────────────┘  └─────────────────────────┘  └──────────────────────────┘
```

**Crew on the rotation today** (from `references/accounts.md`):

- `@sanket` — strategic posts + approvals
- `@rishav` — technical posts (engineering depth)
- `@russel` — video-cut adjacent posts + community replies
- `@famitha` — design/asset-driven posts + visual platforms

Per the bootstrap rules, `is_on_leave <@SLACK_ID>` and `guard_working_day` from `_lib.sh` gate execution. Crew members on leave are silently skipped for the day; non-working days (weekends, IST holidays) skip the whole cycle.

## Per-brand voice rules (drafting)

All drafts go through this skill's per-brand voice filter BEFORE going to a crew member:

- **RapidNative** voice: technical, builder-to-builder, anchored in React Native + AI coding tooling. See [`references/strategies/rapidnative.md`](references/strategies/rapidnative.md).
- **Applighter** voice: ship-fast-to-revenue, full-stack template seller. See [`references/strategies/applighter.md`](references/strategies/applighter.md) (currently a stub — brand audit pending).
- **LetsDeployIt** voice: pain-of-mobile-deploy, fastlane/EAS/TestFlight angle. See [`references/strategies/letsdeployit.md`](references/strategies/letsdeployit.md) (currently a stub — repo not yet located).

Cross-brand defaults (from `profile.md`): no em-dashes, no hashtags-the-user-didn't-ask-for, no corporate buzzwords, no "let me know if I can help", concise, specifics over generics.

## Anti-hallucination conventions

These exist because the legacy `marketing/` setup was the biggest hallucination source pre-refactor (438-line recon prompt + scattered config + 6 sources of truth for team).

1. **Never invent a persona account.** If a task says "use account X for @sanket", look it up in `references/accounts.md`. If the account isn't listed, ask — don't invent.
2. **Never invent a Slack ID or handle.** Use `lookup_slack_id @handle` / `lookup_handle <U…>` from `_lib.sh`. Single source of truth: `definitions/people.md`.
3. **Never invent a product strategy claim.** If the strategy file is a stub, say so explicitly in the draft ("brand voice for Applighter is still TBD; this draft uses generic SaaS-template defaults").
4. **Never burn the same account two days in a row** on the same platform. Use the rotation formula from `references/rotation.md`.
5. **Always cite source URL when drafting a comment.** Recon cache stores URL + 1-line context per finding; the comment draft must show the source URL the crew member will paste into.

## What still lives outside this skill

Runtime state — files the routines write daily — remains under `marketing/`:

- `marketing/morning-tasks.md` + `marketing/evening-tasks.md` — daily outputs of the AM/EOD routines
- `marketing/tracker.md` — running ledger appended each evening
- `marketing/.state/` — recon JSON cache + per-day sentinels + blog-amplification cache

These are scheduled to move into sqlite (per Phase 3 of the architecture refactor); until then they're the routines' working directory. Treat them as outputs of this skill, not inputs.
