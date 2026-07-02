---
name: social-engagement-applighter
description: Applighter-specific social distribution — full-stack templates / SaaS boilerplate / expo-supabase-auth / Claude-code-RN threads on HN, Reddit, Quora, LinkedIn, X, dev.to, GFG, Hashnode. One of three per-product sub-skills under `social-engagement` (siblings: `-rapidnative`, `-letsdeployit`). Loaded by the orchestrator when today's sprint has an Applighter block, OR ad-hoc when the user asks about Applighter social copy.
when_to_load: |
  Load when ANY of the following:
  - marketing-morning orchestrator dispatches to the Applighter product (sprint.md has a `### Applighter` block today)
  - marketing-recon is scraping for Applighter (`products_scraped` includes `applighter`)
  - The user asks about Applighter social copy, Applighter engagement drafts, template/boilerplate positioning
  - The user names a platform + Applighter context ("dev.to article on shadcn boilerplate", "Reddit r/SaaS template share")
voice_source: ../../../../profile.md
---

# social-engagement-applighter

Applighter's flavour of the daily social-engagement cycle. Everything Applighter-specific — topics, brand terms, community URLs, per-brand voice — lives here (or is pointed at from here).

For orchestration + shared mechanics (persona rotation, sprint parsing, cross-product dedupe rules), read the parent [`../SKILL.md`](../SKILL.md).

## Read these before doing any work

1. **Always:** [`../../../../COMPANY.md`](../../../../COMPANY.md) + [`../../../../profile.md`](../../../../profile.md) (bootstrap already loaded them)
2. **Product config** — topics, search-query templates, community URLs, brand terms:
   [`../references/products/applighter.md`](../references/products/applighter.md)
   *(TODO in the file: community URLs + mailboxes not yet provisioned; recon degrades gracefully.)*
3. **Brand voice + positioning:**
   [`../references/strategies/applighter.md`](../references/strategies/applighter.md)
   *(stub — brand audit pending; drafts should explicitly say "Applighter positioning is still TBD" until this lands.)*
4. **Shared refs (product-agnostic):**
   - [`../references/accounts.md`](../references/accounts.md)
   - [`../references/rotation.md`](../references/rotation.md)
   - [`../references/task-templates.md`](../references/task-templates.md)
   - [`../references/sprint.md`](../references/sprint.md) — today's `### Applighter` block

## Voice cheat-sheet (for LLM drafts)

- **Ship-fast-to-revenue positioning.** Applighter sells time — a template that gets you from "starter idea" to "customer-paying" in a weekend, not a quarter.
- **Anchor on the tech stack the templates actually use.** Expo · Supabase · Stripe · shadcn · Tailwind · Next.js — say what's inside, don't hand-wave.
- **AI-generated code angle is fair game.** Claude-code / Cursor / Continue integrating with Applighter starters — this is a genuine differentiator vs. bare templates.
- **Don't overclaim uniqueness.** There are 100 SaaS boilerplates. The claim is faster + more current + AI-friendly, not "the only one."
- **No em-dashes / no "leverage" / no "seamless"** — see profile.md.

## Platforms (working list — refine as strategies/applighter.md fills in)

Applighter's audience overlaps heavily with the RN dev pool (topics are RN-flavoured). Recon dedupes at thread-URL level, so an HN thread claimed by the RN sub-skill's scrape won't re-appear for Applighter.

Priority (provisional — needs @sanket brand audit):

1. Reddit — r/reactnative, r/nextjs, r/reactjs, r/SaaS, r/webdev
2. dev.to — /t/nextjs, /t/saas, /t/supabase, /t/reactnative
3. Quora — "best React Native starter" / "SaaS boilerplate" questions
4. HackerNews — Show HN when a template ships something genuinely new
5. LinkedIn — indie-hacker / templates-for-founders audience
6. X (Twitter) — build-in-public / indie-hacker community
7. Hashnode / Medium — long-form comparisons and integration guides

## When invoked by the orchestrator

The `create-social-eng-task.sh --product applighter` runtime (Phase 2 — not yet wired) will follow the same shape as the RN sub-skill: read today's `### Applighter` block → per-crew fan-out → `tasks.sh add ... --category=marketing --product=applighter --notify` (or batched).

Until Phase 2 lands, `gen-marketing-morning.py` continues to do this deterministically.

## Anti-hallucination

Inherits the parent SKILL.md's guards. Product-specific additions:

- **Never invent a template name.** If drafting a post that mentions an Applighter template, verify it's listed in the strategy file first. If the strategy is a stub, say so ("Applighter starter names TBD; using placeholder for now").
- **Never claim template count / customer count / revenue** without a verified source. These are the metrics that get called out.
- **When the topic pool feels too RN-flavoured** (topics like `expo supabase auth` overlap with RN), lean the reply on the *templates / AI-quality* angle, not the *RN dev* angle — that's the Applighter differentiator.
