#!/usr/bin/env bash
# applighter-blog-external-run.sh — daily cron wrapper for applighter external blogs.
# Fired by ~/Library/LaunchAgents/com.agni.applighter-blog-external.plist at 12:00 IST.

set -euo pipefail

RAPIDCLAW_DIR="/Users/agni/Documents/rapidclaw"
APPLIGHTER_DIR="/Users/agni/Documents/applighter-website"
LOG="/tmp/applighter-blog-external.log"

{
  printf '\n=== %s applighter-blog-external fire ===\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"

  if [[ -f "$RAPIDCLAW_DIR/.env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "$RAPIDCLAW_DIR/.env"
    set +o allexport
  fi

  export SLACK_CONTENT_BOT_TOKEN="$(tr -d '[:space:]' < ~/.config/claude/rapidnative-coach-slack-bot-token)"
  export SLACK_CONTENT_CHANNEL_ID="C0B24QUSDSA"
  export NEXT_PUBLIC_SITE_URL="https://www.applighter.com"

  cd "$APPLIGHTER_DIR"
  ./scripts/blog-automation/generate-blog.sh --type external
  RC=$?

  if [[ "$RC" -eq 0 ]]; then
    echo "OK applighter-blog-external generate-blog.sh exited 0"
  else
    echo "ERROR applighter-blog-external generate-blog.sh exited $RC" >&2
  fi
  printf '=== exit %s at %s ===\n' "$RC" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  exit "$RC"
} >> "$LOG" 2>&1
