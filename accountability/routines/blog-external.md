You are running the **external blog** routine for rapidnative-coach. LaunchAgent fires at 10:00 and 15:00 local. Your only job: invoke the existing battle-tested orchestrator at `sites/rapidnative-website/scripts/blog-automation/generate-blog.sh --type external` and report the outcome.

Do NOT reimplement extraction, splitting, Slack posting, or tracker updates — the script does all of that. Do NOT call `/write-blog` yourself — the script does. Do NOT post anywhere outside what the script posts.

## What the script does

`generate-blog.sh --type external`:
1. Picks the first topic from `sites/rapidnative-website/scripts/blog-automation/blog-tracker.md` → `### External Queue`.
2. Runs `claude -p "/write-blog $TOPIC"` inside the site repo to generate the blog.
3. Splits the output by `━━━` section separators.
4. Posts a parent message to `$SLACK_CONTENT_CHANNEL_ID` (#ai-blog), then uploads each section as a threaded file. Mentions a random Slack user from `$AI_BLOG_PUBLISHERS_SLACK_ID`.
5. Updates `blog-tracker.md` (history row, stats counters, queue removal + renumber).

All the env it needs (`SLACK_CONTENT_*`, `OUTRANK_*`, `NEXT_PUBLIC_BASE_URL`, `AI_BLOG_*`) is already exported by `run.sh` from `/Users/agni/Documents/rapidclaw/.env` before this prompt runs.

## What you do

```bash
# Use the rapidnative-coach bot identity (single-bot rule). The script's own
# generate-blog.sh expects $SLACK_CONTENT_BOT_TOKEN; we point it at this
# bot's token so #ai-blog posts come from @rapidnative-coach, not a 2nd bot.
export SLACK_CONTENT_BOT_TOKEN="$(tr -d '[:space:]' < ~/.config/claude/rapidnative-coach-slack-bot-token)"

cd /Users/agni/Documents/rapidclaw/sites/rapidnative-website
./scripts/blog-automation/generate-blog.sh --type external
RC=$?

if [ "$RC" -eq 0 ]; then
  echo "OK blog-external generate-blog.sh exited 0"
else
  echo "ERROR blog-external generate-blog.sh exited $RC" >&2
  exit "$RC"
fi
```

## Failure modes

- **Script not executable / not found:** something is wrong with the symlink at `sites/rapidnative-website`. Log clearly and exit non-zero.
- **Script exits non-zero:** propagate the exit code. The script logs its own errors verbosely; your job is just to surface the failure.
- **Don't retry inside this routine.** If today's run fails, the next cron slot will try again with the (still un-removed) first topic in the queue.

This routine is unattended cron. No clarifying questions, no Slack chatter outside what the script does, no voice formatting to apply (the script handles its own message formatting).
