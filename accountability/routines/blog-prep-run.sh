#!/usr/bin/env bash
# blog-prep-run.sh — daily cron wrapper. Fires 06:45 IST Mon–Fri via launchd
# (before marketing-morning at 07:00). Generates today's RN + AL external
# blogs to local disk with **all Slack calls suppressed** so the crew's
# workspace stays quiet. Files land in the linked-site's `output/`; the
# distro-article task-assist path reads from there.
#
# Suppression mechanism: prepends a curl shim to $PATH that intercepts any
# HTTPS call to *slack.com* / *hooks.slack.com* and returns fake success
# JSON. Everything else (Outrank webhook to rapidnative.com, claude -p
# invocations, git operations, etc.) passes through to the real curl.
#
# Idempotent: sentinel file `marketing/.state/blog-prep-<product>-<date>.sentinel`
# stops repeat generation within the same IST day. Delete it to force a re-run.

set -euo pipefail

COACH_DIR="/Users/agni/Documents/rapidclaw"
LOG="/tmp/rapidnative-coach-blog-prep.log"

{
  printf '\n=== %s blog-prep fire ===\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"

  # ─── Set up the curl shim ─────────────────────────────────────
  # Real curl at /usr/bin/curl; shim at $SHIM_DIR/curl. Prepending
  # $SHIM_DIR to $PATH means generate-blog.sh finds the shim first.
  SHIM_DIR="${TMPDIR:-/tmp}/blog-prep-shim-$$"
  mkdir -p "$SHIM_DIR"
  cat > "$SHIM_DIR/curl" <<'CURL_SHIM'
#!/bin/bash
# curl shim — intercept Slack API calls, pass through everything else.
# Returns synthetic success JSON so generate-blog.sh proceeds normally
# without actually posting anything to Slack.
#
# Three response-format cases in generate-blog.sh:
#   1. `curl -w "\n%{http_code}"` (RN's chat.postMessage) → expects
#      JSON body + newline + HTTP status code. Bash then reads status
#      via `tail -1` and body via `sed '$d'`.
#   2. `curl` without -w (files.getUploadURLExternal path) → pipes
#      raw response to jq, which chokes on any trailing status line.
#   3. AL's script wraps curl output through Python's `json.load`,
#      which raises "Extra data" if there's anything after the JSON.
#
# Solution: emit the HTTP status suffix ONLY when curl was called with
# -w. Otherwise emit pure JSON so jq/json.load parse cleanly.

has_w=0
for arg in "$@"; do
  if [ "$arg" = "-w" ] || [ "$arg" = "--write-out" ]; then
    has_w=1
    break
  fi
done

for arg in "$@"; do
  case "$arg" in
    *slack.com*|*hooks.slack.com*)
      echo '{"ok":true,"ts":"1783500000.000000","channel":"CBLOGSHIM","message":{"ts":"1783500000.000000","bot_id":"BBLOGSHIM"},"file":{"id":"FBLOGSHIM","permalink":"https://shim/file"},"upload_url":"https://shim/upload","file_id":"FBLOGSHIM"}'
      [ "$has_w" -eq 1 ] && echo '200'
      exit 0
      ;;
  esac
done
exec /usr/bin/curl "$@"
CURL_SHIM
  chmod +x "$SHIM_DIR/curl"
  trap 'rm -rf "$SHIM_DIR"' EXIT

  export PATH="$SHIM_DIR:$PATH"

  # ─── Load coach .env for shared vars (OWNER, etc.) ───────────
  if [[ -f "$COACH_DIR/.env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "$COACH_DIR/.env"
    set +o allexport
  fi

  # generate-blog.sh's required_vars check demands SLACK_CONTENT_BOT_TOKEN.
  # AL's site .env doesn't have it (unlike RN's), so we set it here — even
  # though the shim intercepts every Slack call and the token is never
  # actually sent. Kept as the rapidnative-coach bot token for the
  # documented "single-bot rule" invariant.
  export SLACK_CONTENT_BOT_TOKEN="$(tr -d '[:space:]' < ~/.config/claude/rapidnative-coach-slack-bot-token)"

  TODAY=$(TZ=Asia/Kolkata date +%Y-%m-%d)
  mkdir -p "$COACH_DIR/marketing/.state"
  OVERALL_RC=0

  # ─── Product loop ─────────────────────────────────────────────
  for product in rapidnative applighter; do
    case "$product" in
      rapidnative)
        SITE_DIR="$COACH_DIR/sites/rapidnative-website"
        SHORT="rn"
        export NEXT_PUBLIC_SITE_URL="https://www.rapidnative.com"
        ;;
      applighter)
        SITE_DIR="$COACH_DIR/sites/applighter-website"
        SHORT="al"
        # AL's generate-blog.sh requires NEXT_PUBLIC_SITE_URL. The retired
        # applighter-blog-external-run.sh used to set it explicitly here.
        export NEXT_PUBLIC_SITE_URL="https://www.applighter.com"
        ;;
    esac
    SENTINEL="$COACH_DIR/marketing/.state/blog-prep-${SHORT}-${TODAY}.sentinel"

    if [[ -f "$SENTINEL" ]]; then
      echo "  cache-hit · $product · sentinel: $SENTINEL"
      continue
    fi

    if [[ ! -d "$SITE_DIR" ]]; then
      echo "  skip · $product · site not linked at $SITE_DIR"
      continue
    fi

    echo "  generating · $product external blog (shim active — no Slack posts)"
    ( cd "$SITE_DIR" && ./scripts/blog-automation/generate-blog.sh --type external ) \
      && RC=0 || RC=$?

    if [[ "$RC" -eq 0 ]]; then
      touch "$SENTINEL"
      echo "  OK · $product blog generated"
    else
      echo "  ERROR · $product generate-blog.sh exited $RC" >&2
      OVERALL_RC=$RC
    fi
  done

  printf '=== exit %s at %s ===\n' "$OVERALL_RC" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  exit "$OVERALL_RC"
} >> "$LOG" 2>&1
