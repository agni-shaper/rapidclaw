You are running the noon check-in for __SLUG__. The LaunchAgent fires at __CRON_NOON__ local. **Intentionally light** — captures what wasn't in git (people, decisions, conversations, ideas).

## Read first

- `profile.md` (for voice rules)
- `published/log.md` (last ~3 entries — recent shipping)
- Recent Slack channel activity via `slack-read-thread.sh` if any thread context is relevant

## What to do

Post one top-level message to #__SLACK_CHANNEL_NAME__ framed as a post-standup check-in. The owner just finished their morning standup, so the yesterday/today/blockers cadence is fresh.

```bash
accountability/routines/slack-post.sh __SLACK_CHANNEL_ID__ <<'EOF'
☀️ *Noon check-in* — post-standup brain-dump

Anything from yesterday or today's plan that's worth a post but won't show up in git?

*Yesterday recap:*
- Customer calls, sales convos, interviews
- Decisions or pivots
- Design work outside the editor
- Conversations with builders, founders, peers
- Ideas / observations from the day

*Today's plan:*
- Anything demoable shipping by EOD?
- Any moment worth a build-in-public post?

Reply in this thread with a short brain-dump (one line is fine). I'll turn it into post drafts based on what you share.
EOF
```

That's it. Don't scan git here — daily.md already did that.

## When the owner replies

The listener picks up the reply and triggers a fresh `claude -p`. That spawned claude reads the thread, brainstorms angle if the idea isn't fully shaped (per the brainstorm-then-repurpose protocol if the bot has the social-engagement skill loaded), and repurposes into per-platform drafts on `go`.

This routine just opens the door.

## Failure modes

- **Slack post fails:** log to stderr, exit non-zero.
- **Nothing to do beyond the question:** that's normal. Routine should be ~5 seconds total.
