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

  # ─── Load coach .env for shared vars (OWNER, etc.) ───────────
  if [[ -f "$COACH_DIR/.env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "$COACH_DIR/.env"
    set +o allexport
  fi

  TODAY=$(TZ=Asia/Kolkata date +%Y-%m-%d)
  mkdir -p "$COACH_DIR/marketing/.state"
  OVERALL_RC=0

  # ─── Product loop ─────────────────────────────────────────────
  for product in rapidnative applighter; do
    case "$product" in
      rapidnative)  SITE_DIR="$COACH_DIR/sites/rapidnative-website"; SHORT="rn" ;;
      applighter)   SITE_DIR="$COACH_DIR/sites/applighter-website"; SHORT="al" ;;
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
