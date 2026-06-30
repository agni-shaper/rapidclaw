---
channel_id:C0AMG7SE1FF
name: ai-blogs
purpose: AI/ML/agents/devtools blog content for rapidnative-website — ideation, drafting, review, and publication coordination.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: [blog-internal, blog-external]
product: rapidnative
owner: <@U09DC8L7PCZ>
members: [<@U0B4FCJ8Z1Q>, <@U09DC8L7PCZ>, <@U09DC8MB4KB>, <@U09CUJ9ATM1>]
allowed_skills: []

---

# Purpose

> **DRAFT** — Agni: confirm or refine.

Where the team works on AI-focused blog content that lands on `sites/rapidnative-website`. Two pipelines already exist:

- **Internal blog**: `accountability/routines/blog-internal.md` (cron: 12:00 daily) → uses the `blog-tracker.md` internal queue
- **External blog**: `accountability/routines/blog-external.md` (cron: 10:00 + 15:00 daily) → uses the external queue

This channel is for the human side of that pipeline: topic suggestions, draft review, post-publication adjustments, and ad-hoc deep-dives outside the cron queues.

# Voice

Apply `profile.md` defaults. Additionally:

- Technical accuracy over breadth — get one thing right rather than five things vague
- Original POV; no rehashing of generic "what is an AI agent" content
- Code samples in `tsx`/`ts` or `bash` only (the site's primary stacks)
- No em-dashes, no AI-perfect punctuation, no hashtags the requester didn't ask for

# Scope

In scope:

- Suggesting blog topics for either queue
- Drafting an ad-hoc post that doesn't fit the cron flow
- Reviewing a blog draft before it ships
- Coordinating internal/external blog cadence

Redirect: SEO/keyword strategy → `#seo`; design assets for the post → `#design`; cross-channel launch announcement → `#marketing`.

# Privileged actions

Publishing a blog post to `sites/rapidnative-website` (via PR-merge or direct push) requires owner or super-admin approval. Drafting + opening the PR is fine for any teammate.

# Notes for the bot

- `sites/rapidnative-website` is the linked repo — use `accountability/routines/sites-prepare.sh rapidnative-website` before editing.
- The blog-tracker queue files live inside that repo under `scripts/blog-automation/`. Edits to the queue need to land on the main rapidnative-website branch via PR, not just in your per-thread worktree.
