# Engagement strategy & editorial mix

This is the living plan for what __SLUG__ posts, comments on, and amplifies. The engagement skill at `.claude/skills/social-engagement/SKILL.md` (if present) is the operational protocol; this file is the plan it executes against.

## North star

1. **Help first.** Free advice, lived experience, resources. No sales.
2. **Earn authority.** Products / projects / topics from `profile.md` show up because they're the most natural anchors for what the owner is already saying.
3. **Soft pull, never push.** Audience comes to the owner's work because their presence is genuinely valuable.

## Pillars

See `profile.md` for the canonical list. Update there, not here.

## Weekly editorial mix (target — adjust based on what lands)

TBD per bot. Suggested defaults if applicable:

| Type | Cadence | Surface |
|---|---|---|
| Original post (punchline / observational) | TBD / wk | (X, LinkedIn, …) |
| Long-form thought | TBD / wk | (blog, /unpolished, …) |
| Replies to peers | TBD / wk | (X, LinkedIn, Reddit, …) |
| RTs / quote with thoughts | TBD / wk | (X) |
| Comments | TBD / wk | (LinkedIn) |

## Cron schedule

- **Mon-Sun __CRON_DAILY__ local** — daily morning routine (git scan + draft candidates)
- **Mon-Sun __CRON_NOON__ local** — noon check-in (post-standup brain-dump for non-git activity)
- **Mon-Sun __CRON_ENGAGEMENT_1__ / __CRON_ENGAGEMENT_2__ / __CRON_ENGAGEMENT_3__ local** — engagement scans
- **Fri __CRON_FRIDAY__ local** — build-in-public scan
- **Sun __CRON_SUNDAY__ local** — weekly review

## Approval flow

Every candidate posts to #__SLACK_CHANNEL_NAME__ as a top-level message with:
- The original (when scoring an existing post)
- The drafted text in the owner's voice
- For X: a Twitter intent URL via `x-intent.sh` (owner clicks → posts in their real session)
- For LinkedIn / Reddit: the drafted text in a code block for copy-paste (no intent URL exists)

Owner approves in-thread (or pastes the published URL to log it). The listener picks up the reply and triggers the next step.

## Learning loop

After each approval / skip:
- Log to `published/log.md` (if used): platform, original URL, type, draft, posted URL
- If the owner consistently rejects a shape, add it to a skip list in this file
- Sunday review surfaces what landed and what didn't — update the mix based on data
