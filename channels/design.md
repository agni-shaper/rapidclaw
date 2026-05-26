---
channel_id:C09URB6ACCQ
name: design
purpose: Design coordination — brand assets, UI/UX feedback, design-system work, visual deliverables for marketing/blog/community.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: []
---

# Purpose

> **DRAFT** — Agni: confirm or refine. Famitha is the team's designer (per the roster); this channel likely revolves around her.

Where design work coordinates with the rest of the team. Use for:

- Brand assets (logos, color, type) — see also `sites/branding` (it has its own strict `AGENTS.md`)
- Visual deliverables for blog posts, landing pages, social media
- Feedback rounds on mockups
- Design-system updates affecting `sites/rapidnative-website` or `sites/applighter-website`
- Posting design previews + linking back to other channels' threads for approval

# Voice

Apply `profile.md` defaults, plus:

- Visual-led where possible — attach the mockup; describe the change briefly, don't write essays
- Specific feedback ("nudge the CTA 8px down" beats "feels a little off")
- Honest about constraints (export size, accessibility contrast, mobile breakpoints)

# Scope

In scope: any visual/design deliverable across the rapidnative ecosystem.

Redirect: copy/voice questions → `#marketing` or `#ai-blogs` depending on the surface; analytics on which visual converts better → `#bi-reports`.

# Privileged actions

Modifying `sites/branding` requires reading its `AGENTS.md` first — that repo has its own rules and the design team owns it. Edits there must go through PR per the existing workflow. Same for design-system changes in `sites/rapidnative-website` (PR → super-admin merge).

# Notes for the bot

- For image generation, use `accountability/routines/gen-image.sh "<prompt>" [path] [model]` — requires `OPENROUTER_API_KEY` in `.env`.
- For HTML-to-PNG rendering (diagrams, charts), use `accountability/routines/render-html.sh`.
- `sites/branding` and `sites/rapidnative-website` are linked repos — call `accountability/routines/sites-prepare.sh <name>` before editing.
- Don't propose design changes that touch other teammates' in-progress work in `drafts/` without explicit handoff.
