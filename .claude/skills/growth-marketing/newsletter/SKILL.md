---
name: newsletter
description: Owns the company newsletter cycle — prep, draft, approve, send. Source content from drafts/newsletter-next/items.md + recent published/log.md + git logs across products. Cross-product (covers all 3).
when_to_load: |
  Load when ANY of the following:
  - User says "what's in the newsletter?" / "draft the newsletter" / "send the newsletter"
  - The newsletter cron routine fires (cadence TBD — likely bi-weekly Friday — needs Sanket's decision)
  - Someone adds an item to drafts/newsletter-next/items.md
voice_source: ../../../profile.md
---

# newsletter

Owns the company newsletter — currently no automation; this skill is the design for that automation. Cadence is TBD; needs Sanket's go-ahead.

## Read these before doing any work

1. `drafts/newsletter-next/items.md` (if present) — items teammates have queued for the next issue.
2. `definitions/products.md` — for cross-product attribution + section structure.
3. `accountability/published/log.md` (if present) — what shipped recently.
4. Last few newsletter drafts in `drafts/newsletter-*` for voice + structure carryover.

## What this skill owns

| File | Purpose |
|---|---|
| `drafts/newsletter-next/items.md` | Queue of items teammates have flagged for the next newsletter (already in use). Backlog memory. |
| `drafts/newsletter-next/draft.md` | The draft the skill assembles. Iterated in-place. |
| `drafts/newsletter-next/sent.md` | Once a newsletter ships, the items.md + draft.md content gets archived here with the send date. Old `newsletter-next/` resets for the next cycle. |
| `accountability/state/newsletter-tracker.md` | Sent dates + recipient counts + click-throughs if we track them. |

## Cycle

```
T-7 days (or whatever cadence): bot posts to #rapidnative-coach:
   "Newsletter prep — next issue ships <date>. Current items in queue:"
   <bullet list from items.md>
   "Anything to add?"

T-3 days: bot drafts the newsletter (this skill):
   1. Read items.md
   2. Read published/log.md + git logs for content NOT yet in items.md
   3. Compose the draft (structure below)
   4. Post draft to #rapidnative-coach for review
   5. Save to drafts/newsletter-next/draft.md

T-1 day: bot pings for final approval
   <@SANKET> / <@SURAJ> / <@AGNI> — approve to send?

T-0: on approval, send via external tool (Resend / Loops / Substack — TBD).
     Bot does NOT have credentials for the send tool yet; for now, copy the
     final draft to a place the owner can manually paste into the send tool.
```

## Newsletter structure (provisional)

```
# <Subject line — what made this issue worth opening>

Hey team / <segment>,

<1-2 line intro — what we did this period, what the issue covers>

## What shipped this period

- <bullet> — RapidNative
- <bullet> — Applighter
- <bullet> — LetsDeployIt

## What we're working on

- <bullet>

## Worth reading / using

- <link + 1-line>

## One more thing

<single anchor — a meta-observation, a question for readers, a small gift>

— @sanket + the Shaper Studio team
```

(Cross-promote subtly between products. Don't be all-RapidNative.)

## Anti-hallucination guards

1. **Don't claim a feature shipped without git-log or published/log evidence.** Same as `weekly-wrap`.
2. **Don't link to URLs without checking they resolve** (curl -I).
3. **Don't write subject lines that overpromise.** Concrete > clickbait. "What we shipped this week" beats "🚀 You won't BELIEVE what we just launched".
4. **Don't address-by-name** unless we're segmenting (we're not, yet).
5. **Always include an unsubscribe-friendly footer.** Even for internal-feeling newsletters — habit + legal protection.

## Migration status

- **Today:** No cron, no skill, no automation. `drafts/newsletter-next/` exists as an ad-hoc queue. This SKILL.md is the design — needs Sanket's go-ahead on cadence + send tool.
- **Phase 3:** sqlite `newsletter_issues` table tracking subject line / send date / item count / click metrics.

## Open questions for Sanket

1. **Cadence** — weekly, bi-weekly, monthly?
2. **Send tool** — Resend? Loops? Substack? Beehiiv? Something else? Affects credential setup + Phase 3 schema.
3. **Audience** — newsletter goes to product newsletter list (one per product) or one unified list?
4. **Day of week** — Fridays good?
5. **Internal preview cadence** — bot pings in #rapidnative-coach T-7, T-3, T-1 → too many touchpoints or right?
6. **Approval tier** — superadmin enough or owner-only?

Until these answers exist, the skill is design-only — no cron routine, no send action.

## Related skills

- `weekly-wrap` — same source pool (published/log, git logs) but different audience + cadence. Newsletter is for users; weekly-wrap is for the team.
- `growth-marketing` — newsletters that announce a product launch + the launch's growth plan need coordination.
- `creator-studio` (Phase 4) — hero image / OG image for the newsletter web archive.
