---
name: social-engagement-rapidnative
description: RapidNative-specific social distribution — React Native / Expo / EAS / mobile-dev threads on HN, Reddit, Quora, LinkedIn, X, dev.to, GFG, Hashnode. One of three per-product sub-skills under `social-engagement` (siblings: `-applighter`, `-letsdeployit`). Loaded by the orchestrator when today's sprint has a RapidNative block, OR ad-hoc when the user asks about RN social copy.
when_to_load: |
  Load when ANY of the following:
  - marketing-morning orchestrator dispatches to the RN product (sprint.md has a `### RapidNative` block today)
  - marketing-recon is scraping for RN (`products_scraped` includes `rapidnative`)
  - The user asks about RN social copy, RN engagement drafts, RN persona picks, "what should we post for RN today"
  - The user names a platform + RN context ("HN thread on React Native builds", "Quora RN payment answer")
voice_source: ../../../../profile.md
---

# social-engagement-rapidnative

RapidNative's flavour of the daily social-engagement cycle. Everything RN-specific — topics, brand terms, community URLs, per-brand voice — lives here (or is pointed at from here).

For orchestration + shared mechanics (persona rotation, sprint parsing, dedupe rules), read the parent [`../SKILL.md`](../SKILL.md).

## Read these before doing any work

1. **Always:** [`../../../../COMPANY.md`](../../../../COMPANY.md) + [`../../../../profile.md`](../../../../profile.md) (bootstrap already loaded them)
2. **Product config** — topics, search-query templates, community URLs, brand terms, mailboxes, SEO URLs:
   [`../references/products/rapidnative.md`](../references/products/rapidnative.md)
3. **Brand voice + positioning:**
   [`../references/strategies/rapidnative.md`](../references/strategies/rapidnative.md)
4. **Shared refs (product-agnostic — same for all 3 products):**
   - [`../references/accounts.md`](../references/accounts.md) — per-crew personas
   - [`../references/rotation.md`](../references/rotation.md) — weekly 3-account-pool formula
   - [`../references/task-templates.md`](../references/task-templates.md) — TPL-* → bullet body
   - [`../references/sprint.md`](../references/sprint.md) — today's `### RapidNative` block drives which platforms fire

## Voice cheat-sheet (for LLM drafts)

- **Technical, builder-to-builder.** Specifics beat generics: name the lib, the version, the error, the commit.
- **Show, don't claim.** Code snippet or screenshot > marketing copy.
- **Honest about tradeoffs.** RN isn't magic. Say what bit you.
- **No corporate buzzwords** — see profile.md rules.
- **Mention `rapidnative.com` sparingly** — only when the comment can naturally bridge to it. Most comments should not mention the brand — add value first.

## Platforms in priority order

Per [`../references/strategies/rapidnative.md`](../references/strategies/rapidnative.md):

1. HackerNews — Show HN / Tell HN on real builds + comments on RN threads
2. Reddit — r/reactnative (primary), r/expo, r/indiedev, r/iOSProgramming, r/Frontend
3. X (Twitter) — RN community (Evan Bacon / Brent Vatne / Nader Dabit clusters); build-in-public chronicle
4. dev.to / Hashnode — long-form technical posts
5. LinkedIn — selectively, for engineering-leadership audiences
6. Quora — "how do I build a mobile app?" / "React Native vs Flutter?"
7. Medium / Substack — re-publish blog posts

## When invoked by the orchestrator

The `create-social-eng-task.sh --product rapidnative` runtime (Phase 2 — not yet wired) will:

1. Read today's sprint `### RapidNative` block from `../references/sprint.md`
2. For each crew member whose `accounts.md` `products:` list includes `rapidnative`:
   - Check `is_on_leave` and `is_working_day` (via `_lib.sh`)
   - For each TPL-* in today's RN block × the crew's persona rotation → build one task
3. For each generated task, invoke `tasks.sh add @<sid> <due> "<title>" --category=marketing --product=rapidnative` (with `--notify` or batched summary depending on config)
4. Recon findings (from `recon-YYYY-MM-DD.json.rapidnative`) attach as thread-reply enrichments per task

Until Phase 2 lands, `gen-marketing-morning.py` continues to do this deterministically. This SKILL.md documents the *intent* so the LLM can reason about RN social work when asked ad-hoc.

## Anti-hallucination

Inherits the parent SKILL.md's guards. Product-specific additions:

- **Never claim RN "beats" Flutter/native in general.** Frame as tradeoffs, not verdicts. See profile.md tone rules.
- **Never invent an EAS SDK version.** Current is SDK 53 as of 2026-07 — check `products/rapidnative.md`'s topics list for what the bot is expected to know about.
- **When drafting Quora answers, cite the specific question URL** from `recon-YYYY-MM-DD.json.rapidnative.original_posts.Quora.drafts[].linked_question_url`.
