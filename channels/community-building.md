---
channel_id:C0B4ZA0N2G2
name: community-building
purpose: Growing the rapidnative community — Discord/forum activity, audience engagement, member spotlights, event coordination.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: []
product: all
owner: <@U0B467S1VEG>
members: [<@U0B4FCJ8Z1Q>, <@U09DC8L7PCZ>, <@U0B467S1VEG>]
allowed_skills: []

---

# Purpose

> **DRAFT** — Agni: confirm or refine.

Internal coordination space for community work. The community itself lives elsewhere (Discord? Reddit? X?); this channel is where the team plans and reviews community-facing activity. Use for:

- Drafting community announcements before posting in Discord / X / etc.
- Planning AMAs, demos, workshops, member spotlights
- Reviewing community feedback / common questions
- Coordinating who is "on" community duty this week
- Member recognition / thank-yous

# Voice

Apply `profile.md` defaults, plus:

- Friendly, inclusive, community-first — talk *with* members, not *at* them
- Specific recognition by handle when crediting community contributions
- No corporate-speak. No "we're excited to announce!" filler
- Plain language; assume a wide skill range in the audience

# Scope

In scope: anything that touches the public community — drafts, planning, reactive responses to community questions/issues.

Redirect: paid affiliate work → `#affiliate-marketing`; brand partnerships → `#collabs-and-partnerships`; marketing campaigns aimed at acquisition → `#marketing`.

# Privileged actions

Posting in any external community surface (Discord announcement, public X post, Reddit comment from a team account) requires owner or super-admin approval. Drafting and internal review are open to any teammate.

# Notes for the bot

- No routines exist yet. Potential additions:
  - `weekly-community-pulse` (summary of community activity, surfaced internally)
  - `member-spotlight-suggest` (bot finds notable contributions, drafts a spotlight)
- For logged-in social reads (Reddit, X, etc.), use `accountability/routines/browser-open.sh` — never `mcp__claude_ai_*` tools.
- Stay strictly read-only on the bot's part: drafts go to files, the team ships.
