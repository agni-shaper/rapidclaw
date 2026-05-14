#!/bin/zsh
# browser-open.sh — open a URL in a NEW tab via browser-use, on the owner's
# real Chrome. Reads per-platform Chrome profile from .env (CHROME_PROFILE_X,
# CHROME_PROFILE_LINKEDIN, etc.) so different platforms can use different
# Chrome profiles.
#
# Behavior:
#   1. Opens the URL as a NEW TAB (auto-focuses to it).
#   2. Sweeps up to 3 times to close any auto-spawned Chrome Gemini side panel.
#   3. Detects ad-blocker pages (ERR_BLOCKED_BY_CLIENT / chrome-error://).
#
# Usage:
#   browser-open.sh <url>
# After: caller does its scrape/screenshot, then `browser-use tab close`.
#
# Exit codes:
#   0   — success
#   11  — Gemini side panel hijack (chrome://settings/ai → disable)
#   12  — navigation blocked by extension (whitelist host)

set -e
source "${0:A:h}/_lib.sh"

BU="$(command -v browser-use || echo "$HOME/.browser-use-env/bin/browser-use")"
[ -x "$BU" ] || { echo "ERROR: browser-use not found. Install: pip install browser-use" >&2; exit 1; }

URL="${1:?url required as first arg}"

# Pick the Chrome profile based on the URL host
HOST="$(printf '%s' "$URL" | sed -E 's|^https?://([^/]+).*|\1|')"
PROFILE="${CHROME_PROFILE_DEFAULT:-Default}"
case "$HOST" in
  *x.com*|*twitter.com*) PROFILE="${CHROME_PROFILE_X:-$PROFILE}" ;;
  *linkedin.com*)        PROFILE="${CHROME_PROFILE_LINKEDIN:-$PROFILE}" ;;
  *instagram.com*)       PROFILE="${CHROME_PROFILE_INSTAGRAM:-$PROFILE}" ;;
  *github.com*)          PROFILE="${CHROME_PROFILE_GITHUB:-$PROFILE}" ;;
  *reddit.com*)          PROFILE="${CHROME_PROFILE_REDDIT:-$PROFILE}" ;;
esac

# Ensure a daemon exists on the right profile. If it's already running with a
# different profile, --profile is silently ignored; that's OK — tab new still
# works on the existing daemon.
"$BU" --profile "$PROFILE" tab new "$URL" >/dev/null 2>&1 || "$BU" tab new "$URL" >/dev/null
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
