---
channel_id:C09EU7C87BM
name: user-testing
purpose: User testing operations — recruiting participants, scheduling sessions, capturing notes/recordings, synthesizing findings, feeding insights into design and product decisions.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: []
---

# Purpose

> **DRAFT** — Agni: confirm or refine. Most teams use a tool like Maze / Lookback / UserInterviews / Notion for the actual sessions; this channel is the coordination layer around that.

Where the team coordinates the user-testing program. Use for:

- Recruiting participants (criteria, outreach drafts, scheduling)
- Posting session notes / observation summaries after a test
- Synthesizing findings across multiple sessions into a digest
- Surfacing recurring themes that should change design or product behavior
- Tracking which features are queued for testing vs already tested

# Voice

Apply `profile.md` defaults, plus:

- **Quote real users verbatim** when reporting findings — paraphrasing loses signal. Attribute with role/persona but not name unless they've consented to internal mention.
- **Honest about sample size** — *"3 of 5 testers stumbled on the onboarding screen"* beats *"users are confused by onboarding"*. Always include N.
- **Distinguish observation from inference** — *"user X clicked the wrong button (observation), suggesting the label is unclear (inference)"*. Don't conflate.
- **Hedge appropriately** — small-n qualitative isn't statistical evidence; phrase as signals to investigate, not facts to act on.

# Scope

In scope: anything tied to the user-testing program from recruit → session → notes → synthesis.

Redirect:
- Implementing design changes that come from findings → `#design`
- Quantitative usage metrics that complement testing (e.g., funnel data) → `#bi-reports`
- Recruiting participants from the existing community → `#community-building`
- Tasking the actual fix work into the tracker → `#tasks`

# Privileged actions

Any external communication to a tester (recruitment email/DM, scheduling outreach, incentive payout) requires owner or super-admin approval. Internal notes, drafts, and synthesis are open to any teammate.

Sharing findings with external parties (clients, partners, public posts) is **always** owner or super-admin only — testers often share things they wouldn't if they knew the public was watching.

# Notes for the bot

- Raw session notes / recordings should NOT live in this Slack channel long-term — they're sensitive. Drop them in `drafts/user-testing/<YYYY-MM-DD-session>/` and reference by path.
- The `user-testing-capture` routine (`accountability/routines/user-testing-capture.md`) fires daily and reads this channel, diffs against `accountability/user-testing/issues-log.md`, and posts proposed updates to **#rapidnative-coach** for one-line confirm. Raw session notes still live in `drafts/user-testing/<YYYY-MM-DD-session>/`; the issues-log is the dedup'd index.
- Potential future additions:
  - `weekly-user-testing-digest` (Friday: summary of the week's findings + a list of action items, routed to `#design` and `#tasks` as appropriate)
  - `recruit-followup-nudge` (gentle ping when scheduled testers haven't confirmed)
- If the team adopts a specific tool (Maze, Lookback, Dovetail, UserInterviews, Notion), document the access pattern here so the bot knows where to look for raw data.
- Don't post identifying details about an individual tester in any other channel without their consent — privacy and trust matter for the next round of recruits.
