#!/bin/zsh
# slack-download-file.sh — download a private Slack file via the bot token.
# Bot must have `files:read` scope.
#
# Usage: slack-download-file.sh <url_private> [output_path]

set -e
source "${0:A:h}/_lib.sh"

URL="${1:?url_private required}"
OUTPUT="${2:-}"

if [ -z "$OUTPUT" ]; then
  BASENAME="$(basename "${URL%%\?*}")"
  [ -z "$BASENAME" ] && BASENAME="slack-file-$(date +%s)"
  OUTPUT="/tmp/$BASENAME"
fi

TOKEN="$(get_bot_token)"
HTTP_STATUS="$(curl -sSL -H "Authorization: Bearer $TOKEN" -o "$OUTPUT" -w "%{http_code}" "$URL")"

[ "$HTTP_STATUS" = "200" ] || { echo "ERROR: HTTP $HTTP_STATUS downloading $URL" >&2; exit 1; }

# If the bot lacks files:read, Slack returns the login HTML page — detect it.
FIRST_BYTES="$(head -c 100 "$OUTPUT" 2>/dev/null)"
if echo "$FIRST_BYTES" | grep -qi '<html\|<!DOCTYPE'; then
  echo "ERROR: response is HTML, not a file. Bot likely lacks the 'files:read' scope." >&2
  echo "Add it at api.slack.com/apps → <your bot> → OAuth & Permissions → Bot Token Scopes → files:read, then reinstall." >&2
  rm -f "$OUTPUT"; exit 1
fi

echo "$OUTPUT"
