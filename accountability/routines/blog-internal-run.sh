#!/usr/bin/env bash
# blog-internal-run.sh — daily cron wrapper. Fires 12:00 IST daily via launchd.
# Generates today's RN internal blog and publishes it to rapidnative.com via
# Outrank. All Slack posts are suppressed via the same curl-shim pattern used
# by blog-prep-run.sh — the shim intercepts calls whose URL contains slack.com
# and returns fake success, while non-Slack traffic (Outrank webhook to
# rapidnative.com) passes through to the real /usr/bin/curl.
#
# WHAT'S KEPT:
#   • generate-blog.sh runs (drafts blog with `claude -p /write-blog`)
#   • Outrank webhook publishes blog to rapidnative.com
#   • blog-tracker.md updates (local file, no curl involved)
#   • sites/rapidnative-website/scripts/blog-automation/output/ gets the file
#
# WHAT'S DROPPED (all Slack posts silenced by the shim):
#   • Editorial post to #ai-blogs — was landing here as ContentWriterBot due
#     to generate-blog.sh's load_env overriding SLACK_CONTENT_BOT_TOKEN with
#     the site's .env value.
#   • Task ping to #marketing-automation for @famitha + @russel design/video
#     amplification — was part of the LLM-driven blog-internal.md prompt
#     (now retired).
#   • marketing/.state/blog-amplification-<date>.md cache write — was consumed
#     by gen-marketing-morning.py's append_blog_task() to synthesize a
#     "Publish a blog for X" personal-account task. That synthetic task will
#     silently no-op without the cache (append_blog_task returns early when
#     blog_cache is None). Retire the code path or wire a simpler cache write
#     if the crew wants that task back.

set -euo pipefail

COACH_DIR="/Users/agni/Documents/rapidclaw"
LOG="/tmp/rapidnative-coach-blog-internal.log"

{
  printf '\n=== %s blog-internal fire ===\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"

  # ─── Set up the curl shim ─────────────────────────────────────
  SHIM_DIR="${TMPDIR:-/tmp}/blog-internal-shim-$$"
  mkdir -p "$SHIM_DIR"
  cat > "$SHIM_DIR/curl" <<'CURL_SHIM'
#!/bin/bash
# curl shim — intercept Slack API calls, pass through everything else.
for arg in "$@"; do
  case "$arg" in
    *slack.com*|*hooks.slack.com*)
      echo '{"ok":true,"ts":"1783500000.000000","channel":"CBLOGSHIM","message":{"ts":"1783500000.000000","bot_id":"BBLOGSHIM"},"file":{"id":"FBLOGSHIM","permalink":"https://shim/file"},"upload_url":"https://shim/upload","file_id":"FBLOGSHIM"}'
      exit 0
      ;;
  esac
done
exec /usr/bin/curl "$@"
CURL_SHIM
  chmod +x "$SHIM_DIR/curl"
  trap 'rm -rf "$SHIM_DIR"' EXIT
  export PATH="$SHIM_DIR:$PATH"

  # ─── Load coach .env for shared vars ─────────────────────────
  if [[ -f "$COACH_DIR/.env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "$COACH_DIR/.env"
    set +o allexport
  fi

  # Coach bot token — documented "single-bot rule" even though the shim
  # intercepts all Slack traffic anyway. Kept so any accidental non-shimmed
  # Slack call posts under this bot's identity instead of ContentWriterBot's.
  export SLACK_CONTENT_BOT_TOKEN="$(tr -d '[:space:]' < ~/.config/claude/rapidnative-coach-slack-bot-token)"

  # ─── Run generate-blog.sh --type internal ─────────────────────
  cd "$COACH_DIR/sites/rapidnative-website"
  ./scripts/blog-automation/generate-blog.sh --type internal
  RC=$?

  if [[ "$RC" -eq 0 ]]; then
    echo "OK blog-internal generate-blog.sh exited 0 (Slack silenced, Outrank publish preserved)"
  else
    echo "ERROR blog-internal generate-blog.sh exited $RC" >&2
  fi
  printf '=== exit %s at %s ===\n' "$RC" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  exit "$RC"
} >> "$LOG" 2>&1
