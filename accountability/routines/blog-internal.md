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

## Step 2 — write amplification cache for marketing-recon

If the script succeeded, write a side-channel cache so the next morning's `marketing-recon` routine can surface this blog as an amplification task in `#marketing-automation`. Don't change anything the script did — this is purely additive.

```bash
# Re-source .env from the COACH repo (we cd'd into the site repo above).
COACH_DIR="/Users/agni/Documents/rapidclaw"
TODAY=$(TZ=Asia/Kolkata date +%Y-%m-%d)
CACHE_FILE="${COACH_DIR}/marketing/.state/blog-amplification-${TODAY}.md"
TRACKER="${COACH_DIR}/sites/rapidnative-website/scripts/blog-automation/blog-tracker.md"
```

Find the most-recent `published` internal row in `blog-tracker.md` for today's date:

```bash
# Parse the latest internal/published row matching today.
LATEST_ROW=$(awk -F'|' -v today="$TODAY" '
  $0 ~ today && $0 ~ "internal" && $0 ~ "published" {row=$0}
  END {print row}
' "$TRACKER")
```

Extract the `title` (column 4) and `slug` (column 5) from that row. The published URL is `${NEXT_PUBLIC_BASE_URL}/blogs/${slug}` (env already exported by run.sh from `.env`).

Draft a 50-word LinkedIn-style amplification caption in profile.md voice:

- Plain, opinionated, specific
- Lead with the most useful nugget from the blog (not "we wrote about X")
- One sentence + one bullet of takeaways, or two short sentences
- No "we're excited to share" or "must read"

Write the cache file:

```markdown
---
title: <blog title>
slug: <slug>
url: ${NEXT_PUBLIC_BASE_URL}/blogs/<slug>
type: internal
generated_at: <ISO timestamp>
source_date: <today's date>
---

<the 50-word caption>
```

Atomic write: write to `<file>.tmp` then `mv`.

```bash
mkdir -p "${COACH_DIR}/marketing/.state"
# ...write to ${CACHE_FILE}.tmp...
mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
echo "OK wrote amplification cache: $CACHE_FILE"
```

If the tracker has no matching row (script claimed success but didn't update tracker — shouldn't happen), log a warning and exit 0. The morning routine just won't have a blog to surface tomorrow.

## Failure modes

- **Script exits non-zero:** propagate the exit code. The script logs its own errors (Outrank HTTP code, Slack API error, etc.). Don't retry from this routine. **Don't write the amplification cache** — the blog isn't actually live.
- **Outrank success but Slack failure** is handled inside the script — the blog is live; the notification is best-effort. The amplification cache **should still write** in this case (Outrank is the source of truth for "is the blog live").
- **Amplification cache write fails:** log + exit 0. The blog is published; surfacing it tomorrow is a nice-to-have, not a blocker.

This routine is unattended cron. No clarifying questions, no extra Slack messages.
