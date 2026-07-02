---
name: social-engagement
description: Daily social-distribution cycle across HN, Reddit, Quora, LinkedIn, X, dev.to, GFG, Hashnode, Substack, Vocal, Facebook. Owns per-crew persona rotations, engagement drafts, and per-platform recon → post → carryover flow. Sub-skill of growth-marketing.
when_to_load: |
  Load when ANY of the following:
  - A cron routine is firing: marketing-recon, marketing-morning, marketing-evening, gtm-weekly-pick, biweekly-shoutouts
  - The user asks about: social posts, comment drafts, persona accounts, weekly rotation, engagement replies, thread hunting, HN / Reddit / Quora / LinkedIn / X / dev.to / GFG / Hashnode / Substack / Vocal / Facebook copy
  - The active channel is #marketing-automation (C0BBQ7PV34N)
voice_source: ../../../profile.md
---

# social-engagement

The daily social-distribution spine of `growth-marketing`. Everything that reads a sprint template, expands it against a crew member's persona rotation, and posts (or drafts for the crew to post) on a social platform lives here.

For higher-level umbrella concerns (brand voice per-product, cross-sub-skill invariants), read the parent [`../SKILL.md`](../SKILL.md).

## Sub-skill map (since 2026-07-02)

social-engagement is itself an orchestrator over three per-product sub-skills. LLM-facing product voice lives in each sub-skill; shared mechanics (persona rotation, sprint parsing, task-template rendering) stay here.

| Sub-skill | Read when… |
|---|---|
| [`social-engagement-rapidnative/`](social-engagement-rapidnative/SKILL.md) | Today's sprint has a `### RapidNative` block · user asks about RN social copy · marketing-recon scrapes for RN |
| [`social-engagement-applighter/`](social-engagement-applighter/SKILL.md) | Today's sprint has a `### Applighter` block · user asks about Applighter social copy · marketing-recon scrapes for Applighter |
| [`social-engagement-letsdeployit/`](social-engagement-letsdeployit/SKILL.md) | Today's sprint has a `### LetsDeployIt` block · user asks about LDI social copy · marketing-recon scrapes for LDI |

**Loading rule for the orchestrator:** read THIS SKILL.md first (shared mechanics), then read the sub-skill(s) for the product(s) in today's slate. Don't load sub-skills you don't need — token cost adds up when the sprint touches all 3.

**Loading rule for ad-hoc user asks:** if the user names one product, load that sub-skill only. If they name multiple or say "our socials", load all three plus this parent.

Nested SKILL.md files aren't auto-discovered by the Claude Code harness — they surface only when this parent points at them (via the map above) or when the invoking routine reads them directly.

## Runtime status (Phase 1 vs. Phase 2)

- **Phase 1 (2026-07-02):** the 3 sub-skill SKILL.md files exist as LLM-facing docs. The daily fire is still done by `gen-marketing-morning.py` reading `references/products/<slug>.md` directly. No behavior change in cron — this is a docs-only structural split.
- **Phase 2 (planned):** shell wrappers `create-social-eng-task.sh --product <slug>` and `create-blog-task.sh` invoke the Python engine per product AND persist each generated task to sqlite via `tasks.sh add ... --category=marketing --product=<slug> --notify` (or batched summary). Marketing tasks become sqlite-native; marketing-evening reads sqlite for done-claims instead of parsing Slack threads.

## Read these before doing any work

The skill itself is a thin orchestrator. Real content lives in scoped reference files — load only what the current task needs.

1. **Always:** [`../../../COMPANY.md`](../../../COMPANY.md) and [`../../../profile.md`](../../../profile.md) (already loaded by bootstrap)
2. **Per product** (only the one(s) the task touches):
   - RapidNative → [`references/strategies/rapidnative.md`](references/strategies/rapidnative.md)
   - Applighter → [`references/strategies/applighter.md`](references/strategies/applighter.md)
   - LetsDeployIt → [`references/strategies/letsdeployit.md`](references/strategies/letsdeployit.md)
3. **Per-product config (since 2026-07-02)** — each product has its own topics, search-query templates, community URLs, brand-monitor terms, mailboxes, and SEO URLs:
   - [`references/products/rapidnative.md`](references/products/rapidnative.md)
   - [`references/products/applighter.md`](references/products/applighter.md)
   - [`references/products/letsdeployit.md`](references/products/letsdeployit.md)
4. **For the daily distribution cycle (marketing-morning / evening / recon):**
   - [`references/accounts.md`](references/accounts.md) — per-crew named persona accounts, plus each crew's `products:` list (which products they cover)
   - [`references/rotation.md`](references/rotation.md) — weekly 3-account-pool formula
   - [`references/config.md`](references/config.md) — cross-product config only (channel routing, dedupe rules, Medium subdomains). Per-product SEO/mailboxes/topics live in `products/*.md`.
   - [`references/sprint.md`](references/sprint.md) — 7-day rolling template plan; each date has `### RapidNative / ### Applighter / ### LetsDeployIt` sub-headings driving product fan-out
   - [`references/task-templates.md`](references/task-templates.md) — TPL-* prefix → platform + bullet body (product-agnostic)
5. **Per platform** (only the platform(s) today's slate needs) → TPL-* sections in [`references/task-templates.md`](references/task-templates.md).

## Multi-product model (v2, 2026-07-02)

- **Sprint fan-out**: for each product listed in today's sprint × each crew member whose `products:` list includes that product × each `TPL-*` template → one task.
- **Recon fan-out**: `marketing-recon` runs once per product with that product's own topic + search queries + community URLs. Cross-product URL-dedupe applied (first product to claim a thread keeps it).
- **Enrichment**: findings/drafts are per-product; only tasks tagged with product X get enrichment from recon's product-X block.
- **Backwards compat**: legacy flat sprint sections (no `### Product` sub-headings) are treated as `rapidnative`-only. Legacy single-product recon JSON (no product-keyed top level) is auto-wrapped as `rapidnative`.

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
│   marketing/     │  │   automation            │  │   recap                  │
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

## Runtime state (writes)

Files the routines write daily — these are outputs of this skill, kept under `marketing/` (scheduled to move to sqlite per Phase 3 of the architecture refactor):

- `marketing/morning-tasks.md` + `marketing/evening-tasks.md` — daily outputs of the AM/EOD routines
- `marketing/tracker.md` — running ledger appended each evening
- `marketing/.state/` — recon JSON cache + per-day sentinels + blog-amplification cache
