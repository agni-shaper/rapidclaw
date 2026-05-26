---
channel_id:C0ABVGMQ46S
name: lead-magnets
purpose: Lead generation assets — free downloads, ebooks, mini-courses, gated guides, CTA copy, conversion tracking.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: []
---

# Purpose

> **DRAFT** — Agni: confirm or refine.

Where the team designs and ships lead-magnet assets — the things people give an email to download. Use for:

- Drafting the asset itself (PDF guide, mini-course outline, template pack)
- CTA copy and landing-page surface where the asset lives
- A/B test ideas for conversion
- Tracking which magnet pulls best by source
- Post-download nurture sequences (welcome email, follow-up)

# Voice

Apply `profile.md` defaults, plus:

- High-value, actionable content — if the asset doesn't teach something concrete, don't ship it
- No fake urgency, no "limited time only" framing
- Specific outcomes promised in the CTA ("how to set up a Claude Code agent in 15 min" beats "Free AI guide!")
- Honest about who the asset is for (skill level, role, problem)

# Scope

In scope: anything lead-magnet-related from concept to conversion tracking.

Redirect: ongoing email nurture beyond the lead-magnet welcome → likely `#marketing`; SEO for the landing page → `#seo`; design assets for the asset itself → `#design`.

# Privileged actions

Publishing a new lead magnet (landing page live, email captures going to the list) requires owner or super-admin approval. Drafting + reviewing is open to any teammate.

# Notes for the bot

- No routines exist yet. Potential additions:
  - `monthly-lead-magnet-report` (conversion per source/asset)
  - `magnet-refresh-checklist` (quarterly: is this asset still current?)
- Lead-magnet landing pages likely live on `sites/rapidnative-website` or `sites/applighter-website` — use `sites-prepare.sh <name>` before editing.
- Tracking pixels / form endpoints are sensitive — don't change them without owner approval, even if the request seems benign.
