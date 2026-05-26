---
channel_id:C09F377FGFK
name: marketing
purpose: General marketing coordination — campaign planning, social posts, ad copy, weekly wraps, cross-channel launch announcements.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: []
---

# Purpose

> **DRAFT** — Agni: confirm or refine. This channel is likely the default destination for cross-channel posts that originate elsewhere (e.g. *"post the weekly wrap"* said in `#rapidnative-coach` → bot drafts here).

Marketing-wide coordination. Use for:

- Campaign planning (multi-week, multi-channel)
- Social post drafts before posting on X / LinkedIn / Instagram from team accounts
- Ad copy for paid acquisition
- Weekly / monthly wrap-up posts summarizing what shipped
- Announcing partnerships, launches, blog drops to a marketing-team audience

# Voice

Apply `profile.md` defaults, plus the brand-voice override if `sites/branding` has one. Specifically:

- Plain language, opinionated, specific
- No "we're excited to announce" / "thrilled to share" filler
- Numbers when bragging is warranted ("3,500 signups this month") rather than adjectives ("massive growth!")
- Em-dashes allowed here (marketing copy reads better with them) — overrides the profile.md default

# Scope

In scope: anything marketing-spanning. Things that target a specific surface have their own channels (see redirects below).

Redirect:

- Affiliate program → `#affiliate-marketing`
- Brand partnerships / co-marketing → `#collabs-and-partnerships`
- Community surface (Discord, Reddit, X audience engagement) → `#community-building`
- AI/devtools blog content → `#ai-blogs`
- SEO / search visibility → `#seo`
- Lead-magnet conversion → `#lead-magnets`
- Design assets for any of the above → `#design`

# Privileged actions

Posting to any public surface from team-owned accounts (X, LinkedIn, Instagram, public Slack workspaces, paid ads) requires owner or super-admin approval. Drafting + internal review is open to any teammate.

# Notes for the bot

- This channel is the canonical home for the (future) `weekly-wrap` cross-channel routine — a teammate in `#rapidnative-coach` says *"post the weekly wrap"*, the routine drafts here, super-admin approves, the bot posts.
- For logged-in social reads, use `accountability/routines/browser-open.sh`. Never `mcp__claude_ai_*` tools.
- Stay strictly read-only on the bot's part for any public surface — drafts go to files, the team ships.
