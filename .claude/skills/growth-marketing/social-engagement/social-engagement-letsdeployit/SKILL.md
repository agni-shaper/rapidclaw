---
name: social-engagement-letsdeployit
description: LetsDeployIt-specific social distribution — App Store submission / Play Store / TestFlight / EAS Submit / code signing / ASO threads on HN, Reddit, Quora, LinkedIn, X, dev.to, GFG, Hashnode. One of three per-product sub-skills under `social-engagement` (siblings: `-rapidnative`, `-applighter`). Loaded by the orchestrator when today's sprint has a LetsDeployIt block, OR ad-hoc when the user asks about LDI social copy.
when_to_load: |
  Load when ANY of the following:
  - marketing-morning orchestrator dispatches to the LetsDeployIt product (sprint.md has a `### LetsDeployIt` block today)
  - marketing-recon is scraping for LetsDeployIt (`products_scraped` includes `letsdeployit`)
  - The user asks about LDI social copy, LDI engagement drafts, app-store-submission angle
  - The user names an App-Store / Play-Store / deploy-pipeline context
voice_source: ../../../../profile.md
---

# social-engagement-letsdeployit

LetsDeployIt's flavour of the daily social-engagement cycle. LDI's wedge: the pain of shipping mobile apps to App Store / Play Store — rejections, signing, ASO screenshots, privacy declarations, TestFlight, Fastlane, EAS Submit. Everything LDI-specific is documented (or pointed at) from here.

For orchestration + shared mechanics, read the parent [`../SKILL.md`](../SKILL.md).

## Read these before doing any work

1. **Always:** [`../../../../COMPANY.md`](../../../../COMPANY.md) + [`../../../../profile.md`](../../../../profile.md) (bootstrap already loaded them)
2. **Product config** — topics, search-query templates, community URLs, brand terms:
   [`../references/products/letsdeployit.md`](../references/products/letsdeployit.md)
   *(TODO in the file: community URLs + mailboxes not yet provisioned; recon degrades gracefully.)*
3. **Brand voice + positioning:**
   [`../references/strategies/letsdeployit.md`](../references/strategies/letsdeployit.md)
   *(stub — repo not yet located; drafts should explicitly say "LetsDeployIt positioning is still TBD" until this lands.)*
4. **Shared refs (product-agnostic):**
   - [`../references/accounts.md`](../references/accounts.md)
   - [`../references/rotation.md`](../references/rotation.md)
   - [`../references/task-templates.md`](../references/task-templates.md)
   - [`../references/sprint.md`](../references/sprint.md) — today's `### LetsDeployIt` block

## Voice cheat-sheet (for LLM drafts)

- **Anchor on the deploy-lifecycle pain.** Rejections, code signing, provisioning profiles, App Store review timelines, Play Store's 12-testers rule, ASO screenshots, privacy data safety declarations — these are the moments LDI addresses.
- **Talk to the frustrated shipper.** The audience just spent 6 months building an app and hit a 3-week App Store rejection loop. Empathy first.
- **Concrete > abstract.** Name the rejection code (e.g., 2.1 Guideline · 4.3 Design Spam), the specific pipeline (Fastlane match / EAS Submit / manual), the screenshot spec (6.5" / 6.7" per iOS · phone / 7" tab / 10" tab per Android).
- **"vibecoded app publish"** is a genuine topic — LLM-generated apps hit unique review problems (generic UI, no privacy policy, boilerplate metadata). Address these directly.
- **No em-dashes / no corporate voice** — see profile.md.

## Platforms (working list — refine as strategies/letsdeployit.md fills in)

Priority (provisional):

1. Reddit — r/iOSProgramming, r/androiddev, r/reactnative, r/AppStore, r/mobiledev
2. HackerNews — pain-of-shipping-mobile threads, TestFlight/Play Store news
3. Quora — "why did Apple reject my app?" / "how to prepare screenshots for App Store"
4. LinkedIn — indie-devs and small-team CTOs feeling the review pain
5. dev.to — long-form ship-to-store walkthroughs
6. X (Twitter) — indie-hacker + mobile-dev cluster (App Store rejection horror stories go viral here)

## Overlap with RapidNative

Some topics (EAS-related) will surface RN-adjacent threads. Recon dedupes at thread-URL level, so the same thread doesn't fire twice. LDI's angle stays *ship-to-store*, RN's stays *dev-experience* — even when the underlying thread is about EAS, the reply framing differs.

## When invoked by the orchestrator

The `create-social-eng-task.sh --product letsdeployit` runtime (Phase 2 — not yet wired) will follow the same shape as the other sub-skills.

Until Phase 2 lands, `gen-marketing-morning.py` continues to do this deterministically.

## Anti-hallucination

Inherits the parent SKILL.md's guards. Product-specific additions:

- **Never invent an App Store rejection reason code.** If citing one (e.g. Guideline 2.1), verify from Apple's public review guidelines or `strategies/letsdeployit.md`. If uncertain, describe the *class* of rejection ("metadata rejection") rather than a specific code.
- **Never claim LDI supports a platform / service** without a verified source. Fastlane · EAS Submit · Xcode Cloud · manual — say which one LDI wraps; if the strategy is a stub, say so.
- **"12 testers" is a Play Store thing** (closed-testing prerequisite for production release since 2024) — never conflate with TestFlight (Apple, 100 internal / 10K external testers).
