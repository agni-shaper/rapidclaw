You are running the **internal blog** routine for rapidnative-coach. LaunchAgent fires at 12:00 local. Your only job: invoke the existing battle-tested orchestrator at `sites/rapidnative-website/scripts/blog-automation/generate-blog.sh --type internal` and report the outcome.

Do NOT reimplement publishing, Slack posting, or tracker updates — the script does all of that, including the live publish to rapidnative.com via the Outrank webhook.

## What the script does

`generate-blog.sh --type internal`:
1. Picks the first topic from `sites/rapidnative-website/scripts/blog-automation/blog-tracker.md` → `### Internal Queue`.
2. Runs `claude -p "/write-blog $TOPIC"` inside the site repo.
3. Extracts SECTION 1 content + meta description + cover image.
4. POSTs to `${NEXT_PUBLIC_BASE_URL}/api/outrank/webhook` with `Authorization: Bearer $OUTRANK_WEBHOOK_ACCESS_TOKEN` — blog goes live at `${NEXT_PUBLIC_BASE_URL}/blogs/<slug>`.
5. Posts a parent message to `$SLACK_CONTENT_CHANNEL_ID` (#ai-blog) with the live URL, then uploads sections as threaded files. Mentions a random Slack user from `$AI_BLOG_REVIEWERS_SLACK_ID`.
6. Updates `blog-tracker.md`.

All the env it needs is already exported by `run.sh` from `/Users/agni/Documents/rapidclaw/.env` before this prompt runs.

## What you do

```bash
export SLACK_CONTENT_BOT_TOKEN="$(tr -d '[:space:]' < ~/.config/claude/rapidnative-coach-slack-bot-token)"

cd /Users/agni/Documents/rapidclaw/sites/rapidnative-website
./scripts/blog-automation/generate-blog.sh --type internal
RC=$?

if [ "$RC" -eq 0 ]; then
  echo "OK blog-internal generate-blog.sh exited 0"
else
  echo "ERROR blog-internal generate-blog.sh exited $RC" >&2
  exit "$RC"
fi
```

## Failure modes

- **Script exits non-zero:** propagate the exit code. The script logs its own errors (Outrank HTTP code, Slack API error, etc.). Don't retry from this routine.
- **Outrank success but Slack failure** is handled inside the script — the blog is live; the notification is best-effort.

This routine is unattended cron. No clarifying questions, no extra Slack messages.
