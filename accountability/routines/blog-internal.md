You are running the **internal blog** routine for rapidnative-coach. LaunchAgent fires at 12:00 local. Your job: invoke the existing `generate-blog.sh` orchestrator AND surface the published blog as a clean task in `#marketing-automation` for @famitha + @russel (design + video amplification work). The blog itself still auto-publishes to rapidnative.com via Outrank.

## What the script does (unchanged)

`generate-blog.sh --type internal` (in `sites/rapidnative-website/scripts/blog-automation/`):
1. Picks the first topic from `blog-tracker.md` → `### Internal Queue`.
2. Runs `claude -p "/write-blog $TOPIC"` inside the site repo.
3. Extracts SECTION 1 content + meta description + cover image.
4. POSTs to `${NEXT_PUBLIC_BASE_URL}/api/outrank/webhook` → blog goes live at `${NEXT_PUBLIC_BASE_URL}/blogs/<slug>`.
5. Posts a parent message to `$SLACK_CONTENT_CHANNEL_ID` (editorial format with file uploads + reviewer mention).
6. Updates `blog-tracker.md`.

**Routing change:** we override `SLACK_CONTENT_CHANNEL_ID` to point at `#marketing-automation` (`C0BBQ7PV34N`) so the script's editorial post lands there. We then post a separate **clean task** message in the same channel for the crew to act on.

This gives `#marketing-automation` two messages per blog:
1. The script's editorial post (parent + file uploads with full content) — useful for the team to read/share.
2. Our clean task message — pings @famitha + @russel for design + video amplification, with thread for assets.

The `#ai-blogs` channel is no longer used for internal blog automation.

## Step 1 — env override + run script

```bash
export SLACK_CONTENT_BOT_TOKEN="$(tr -d '[:space:]' < ~/.config/claude/rapidnative-coach-slack-bot-token)"

# Route the script's editorial post to #marketing-automation instead of #ai-blogs.
# The script reads SLACK_CONTENT_CHANNEL_ID from env; this overrides the .env value.
export SLACK_CONTENT_CHANNEL_ID="C0BBQ7PV34N"

cd /Users/agni/Documents/rapidclaw/sites/rapidnative-website
./scripts/blog-automation/generate-blog.sh --type internal
RC=$?

if [ "$RC" -ne 0 ]; then
  echo "ERROR blog-internal generate-blog.sh exited $RC" >&2
  exit "$RC"
fi
echo "OK blog-internal generate-blog.sh exited 0"
```

If the script exits non-zero, propagate the exit code. **Don't post a task** for a failed blog (no URL to surface).

## Step 2 — read latest published row from blog-tracker.md

After the script succeeds, the tracker has a new "published" row. Extract title + slug.

```bash
TODAY=$(TZ=Asia/Kolkata date +%Y-%m-%d)
COACH_DIR="/Users/agni/Documents/rapidclaw"
TRACKER="${COACH_DIR}/sites/rapidnative-website/scripts/blog-automation/blog-tracker.md"

LATEST_ROW=$(awk -F'|' -v today="$TODAY" '
  $0 ~ today && $0 ~ "internal" && $0 ~ "published" {row=$0}
  END {print row}
' "$TRACKER")

# Parse: | date | type | title | slug | status |
TITLE=$(echo "$LATEST_ROW" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')
SLUG=$(echo  "$LATEST_ROW" | awk -F'|' '{gsub(/^ +| +$/, "", $5); print $5}')
URL="${NEXT_PUBLIC_BASE_URL}/blogs/${SLUG}"
```

If the row isn't found (script claimed success but tracker not updated — shouldn't happen), log a warning and exit 0. Editorial post already landed; the missing task is a graceful degradation.

## Step 3 — draft a 50-word social caption

Use Claude to draft a short LinkedIn/Twitter-style caption that opens with the most useful nugget from the blog (not "we wrote about X"). Plain, opinionated, specific. Two sentences max OR one sentence + one bullet of takeaways. No "we're excited to share" filler.

The blog markdown is available at `${COACH_DIR}/sites/rapidnative-website/scripts/blog-automation/output/` — find the most recent `.md` file matching the slug to read the actual content.

```bash
CAPTION=$(claude -p "Draft a 50-word LinkedIn-style caption for this blog post in profile.md voice. Plain, opinionated, specific. Lead with the most useful nugget, not 'we wrote about'.

Title: ${TITLE}
URL: ${URL}

[Optionally include first 1-2 paragraphs of blog content here]")
```

## Step 4 — post the clean task to #marketing-automation

Post a top-level message:

```bash
TASK_BODY=$(cat <<EOF
*📝 Blog published: ${TITLE}*

<@U09LL9JTDM5> <@U09DFJJGS1X> — design + video amplification needed
🔗 ${URL}

_Reply 'done' in this thread when assets are ready, or react :white_check_mark:._
EOF
)

TASK_TS=$(echo "$TASK_BODY" | "${COACH_DIR}/accountability/routines/slack-post.sh" C0BBQ7PV34N)
TASK_TS=$(echo "$TASK_TS" | sed -n 's/^OK ts=//p')

if [ -z "$TASK_TS" ]; then
  echo "WARN: task post to #marketing-automation failed; editorial post still landed" >&2
  exit 0
fi
```

`@famitha` (`U09LL9JTDM5`) is the designer — she's pinged for the cover image / social cards.
`@russel` (`U09DFJJGS1X`) is the video editor — he's pinged for the video version / promo cut.

If you want to route to different crew (e.g. add `@rishav` for technical-review), update `definitions/people.md` first and re-derive the ping list from there.

## Step 5 — threaded reply with caption + asset breakdown

Under `$TASK_TS`, post a threaded reply with the suggested social caption + a per-person breakdown:

```bash
THREAD_BODY=$(cat <<EOF
📝 *Suggested social caption* (adapt before posting):

"${CAPTION}"

---

*Asset checklist:*
• <@U09LL9JTDM5> @famitha — cover image (1200×630 for OG, 1080×1080 for IG, 1500×500 for X banner)
• <@U09DFJJGS1X> @russel — video cut (60s vertical for Reels/Shorts, 2-3min landscape for YouTube)
• Either — short-form social post draft adapted from the caption above (post from personal LinkedIn/X accounts)

Drop the rendered assets in this thread when ready.
EOF
)

echo "$THREAD_BODY" | "${COACH_DIR}/accountability/routines/slack-post.sh" C0BBQ7PV34N "$TASK_TS" >/dev/null \
  || echo "WARN: threaded reply failed; task message still landed" >&2
```

## Step 6 — write amplification cache (full body for next morning's blog task)

Write a cache file that the next morning's `marketing-morning` reads. The cache contains the title, slug, URL, suggested caption, **and the full blog markdown body** — so the morning routine can render a dedicated "Publish a blog for rapidnative" task with the entire blog content in its thread (no need for the crew to navigate to rapidnative.com to see what shipped).

```bash
CACHE_FILE="${COACH_DIR}/marketing/.state/blog-amplification-${TODAY}.md"
mkdir -p "${COACH_DIR}/marketing/.state"

# Find the generated blog markdown. generate-blog.sh writes to
# ${OUTPUT_DIR}/.blog-content-<pid>.md (extracted SECTION 1 body) for internal blogs.
BLOG_OUTPUT_DIR="${COACH_DIR}/sites/rapidnative-website/scripts/blog-automation/output"
BLOG_BODY_FILE=$(ls -t "${BLOG_OUTPUT_DIR}"/.blog-content-*.md 2>/dev/null | head -1)

if [ -n "$BLOG_BODY_FILE" ] && [ -f "$BLOG_BODY_FILE" ]; then
  BLOG_BODY=$(cat "$BLOG_BODY_FILE")
else
  # Fall back to the raw blog file (whole Claude /write-blog output).
  RAW_FILE=$(ls -t "${BLOG_OUTPUT_DIR}"/*.md 2>/dev/null | head -1)
  BLOG_BODY=$(cat "$RAW_FILE" 2>/dev/null || echo "(blog body not found at ${BLOG_OUTPUT_DIR})")
fi

# Cache format:
#   YAML frontmatter (title, slug, url, type, generated_at, source_date)
#   blank line
#   ${CAPTION}                 ← 50-word social caption
#   blank line
#   ---BODY---                 ← separator
#   blank line
#   ${BLOG_BODY}               ← full markdown body of the published blog
{
  echo "---"
  echo "title: ${TITLE}"
  echo "slug: ${SLUG}"
  echo "url: ${URL}"
  echo "type: internal"
  echo "generated_at: $(date -Iseconds)"
  echo "source_date: ${TODAY}"
  echo "---"
  echo
  echo "${CAPTION}"
  echo
  echo "---BODY---"
  echo
  echo "${BLOG_BODY}"
} > "${CACHE_FILE}.tmp"
mv "${CACHE_FILE}.tmp" "${CACHE_FILE}"
echo "OK wrote amplification cache: $CACHE_FILE ($(wc -c < "$CACHE_FILE") bytes)"
```

**Cache size is fine.** Internal blog bodies are typically 4-10KB markdown. The cache file lives in `marketing/.state/` which is `.gitignore`d (runtime state).

If the body file isn't found (output cleanup race or path change in the script), the cache still writes with metadata + caption — the morning routine renders a task that links to rapidnative.com instead of inlining the body. Graceful degradation.

## Failure modes

- **Script exits non-zero:** propagate, don't post task. Editorial post in marketing-automation may be partial; that's the script's problem.
- **`blog-tracker.md` parse fails:** log + exit 0. Editorial post landed; task post is skipped this run.
- **Task post to marketing-automation fails:** log + exit 0. Editorial post in marketing-automation is still useful as the surface.
- **Threaded reply fails:** log + exit 0. Task message landed; thread is just empty.
- **Amplification cache write fails:** log + exit 0. Next morning won't have the amplification task; not worth crashing.

This routine is unattended cron. No clarifying questions. The task post must NOT include any approval gating — the blog is already published.
