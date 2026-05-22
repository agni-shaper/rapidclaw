#!/bin/zsh
# browser-open.sh — open a URL in a NEW tab in the bot's dedicated Chrome
# instance, attached via CDP. The bot Chrome lives at $BOT_CHROME_PROFILE and
# listens on $BOT_CHROME_CDP_PORT so browser-use can attach.
#
# Why a dedicated bot Chrome:
#   Chrome 136+ refuses --remote-debugging-port on the user's default profile
#   (security mitigation), so we can't attach to the owner's personal Chrome
#   via CDP. The bot runs its own visible Chrome window with its own cookies.
#   The owner logs into X / LinkedIn / etc. once in this window; cookies
#   persist on disk in $BOT_CHROME_PROFILE indefinitely.
#
# Concurrency:
#   Bot Chrome is a singleton. Two threads opening a URL at the same time
#   would race on tab lookup / switch / Gemini sweep. So this script holds an
#   shlock-based serialization lock for the duration of its run. Caller's
#   subsequent `browser-use screenshot` / `browser-use tab close` are NOT
#   locked — keep them quick to minimize cross-thread contamination.
#
# Behavior:
#   1. Acquires Chrome lock (waits up to $LOCK_TIMEOUT_SEC).
#   2. Ensures bot Chrome is running with CDP enabled. Launches if needed.
#   3. Opens URL as a NEW TAB and auto-focuses to it.
#   4. Sweeps up to 3 times to close any auto-spawned Chrome Gemini side panel.
#   5. Detects ad-blocker pages (ERR_BLOCKED_BY_CLIENT / chrome-error://).
#   6. Releases lock on exit.
#
# Usage:
#   browser-open.sh <url>
# After: caller does its scrape/screenshot, then `browser-use tab close`.
#
# Exit codes:
#   0   — success
#   11  — Gemini side panel hijack (chrome://settings/ai → disable)
#   12  — navigation blocked by extension (whitelist host)
#   13  — bot Chrome failed to expose CDP port
#   14  — couldn't acquire Chrome lock within $LOCK_TIMEOUT_SEC

set -e
source "${0:A:h}/_lib.sh"

BU="$(command -v browser-use || echo "$HOME/.browser-use-env/bin/browser-use")"
[ -x "$BU" ] || { echo "ERROR: browser-use not found. Install: pip install browser-use" >&2; exit 1; }

URL="${1:?url required as first arg}"
HOST="$(printf '%s' "$URL" | sed -E 's|^https?://([^/]+).*|\1|')"

BOT_CHROME_PROFILE="${BOT_CHROME_PROFILE:-$HOME/.rapidclaw-chrome-profile}"
BOT_CHROME_CDP_PORT="${BOT_CHROME_CDP_PORT:-9222}"
CDP_URL="http://localhost:$BOT_CHROME_CDP_PORT"

# Serialize concurrent browser-open.sh invocations across all threads.
# shlock (macOS, /usr/bin/shlock) does atomic create with PID check, auto-
# cleans stale locks (PID dead). Lock is held for THIS script's lifetime via
# the EXIT trap.
LOCK_FILE="/tmp/rapidclaw-chrome.lock"
LOCK_TIMEOUT_SEC=90
acquire_chrome_lock() {
  local start=$(date +%s)
  while ! /usr/bin/shlock -f "$LOCK_FILE" -p $$ 2>/dev/null; do
    local now=$(date +%s)
    if [ $(( now - start )) -ge $LOCK_TIMEOUT_SEC ]; then
      local holder=$(cat "$LOCK_FILE" 2>/dev/null || echo "?")
      echo "ERROR: another browser-open.sh has held the Chrome lock for >${LOCK_TIMEOUT_SEC}s (holder PID: $holder)" >&2
      echo "       If that PID is dead, run: rm $LOCK_FILE" >&2
      return 14
    fi
    sleep 0.5
  done
}
release_chrome_lock() { rm -f "$LOCK_FILE"; }
acquire_chrome_lock || exit 14
trap release_chrome_lock EXIT

# Ensure bot Chrome is running with CDP enabled. Launch if not.
if ! curl -s -o /dev/null -m 1 "$CDP_URL/json/version"; then
  mkdir -p "$BOT_CHROME_PROFILE"
  open -na "Google Chrome" --args \
    --user-data-dir="$BOT_CHROME_PROFILE" \
    --remote-debugging-port="$BOT_CHROME_CDP_PORT" \
    --no-first-run \
    --no-default-browser-check
  for i in {1..15}; do
    sleep 1
    curl -s -o /dev/null -m 1 "$CDP_URL/json/version" && break
    [ "$i" = 15 ] && { echo "ERROR: bot Chrome failed to expose CDP on port $BOT_CHROME_CDP_PORT after 15s" >&2; exit 13; }
  done
fi

# browser-use only needs --cdp-url when starting a fresh session. Once a daemon
# is running with config=cdp, subsequent calls reuse it — and passing the flag
# again triggers a "Session 'default' is already running with different config"
# error even when the URL matches. So we check for an existing cdp session.
BU_FLAGS=()
if ! "$BU" sessions 2>/dev/null | awk 'NR>1 && $1=="default" && $4=="cdp" {found=1} END {exit !found}'; then
  BU_FLAGS=(--cdp-url "$CDP_URL")
fi

"$BU" "${BU_FLAGS[@]}" tab new "$URL" >/dev/null
sleep 2

# Up to 3 sweeps because Glic re-spawns when URL changes
for sweep in 1 2 3; do
  TABS_RAW="$("$BU" tab list 2>&1)"
  echo "$TABS_RAW" | awk '/gemini\.google\.com/ {print $1}' | while read -r idx; do
    [ -n "$idx" ] && "$BU" tab close "$idx" >/dev/null 2>&1 || true
  done
  TARGET_IDX="$(echo "$TABS_RAW" | awk -v h="$HOST" '!/gemini\.google\.com/ && index($0, h) > 0 {print $1; exit}')"
  [ -n "$TARGET_IDX" ] && "$BU" tab switch "$TARGET_IDX" >/dev/null 2>&1 || true
  CURRENT_URL="$("$BU" eval 'window.location.href' 2>&1 | sed 's/^result: //')"
  case "$CURRENT_URL" in
    *gemini.google.com*) sleep 1; continue ;;
    *) break ;;
  esac
done

ACTUAL_URL="$("$BU" eval 'window.location.href' 2>&1 | sed 's/^result: //')"
echo "$ACTUAL_URL"

STATE="$("$BU" state 2>&1 || true)"

case "$ACTUAL_URL" in
  *gemini.google.com*)
    echo "ERROR: Gemini side panel kept hijacking focus after 3 close sweeps." >&2
    echo "FIX: open Chrome → chrome://settings/ai and turn off the Gemini side panel toggle." >&2
    exit 11
    ;;
esac

if printf '%s' "$STATE" | grep -qE 'ERR_BLOCKED_BY_CLIENT|This site can.t be reached|chrome-error://'; then
  echo "ERROR: navigation to $URL was blocked (likely an ad-blocker / privacy extension)." >&2
  echo "FIX: whitelist $HOST in the blocking extension, or disable it for this site." >&2
  exit 12
fi

exit 0
