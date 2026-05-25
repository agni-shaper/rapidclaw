#!/bin/zsh
# slack-post.sh — post a text message to a Slack channel/thread via chat.postMessage.
# Usage:
#   slack-post.sh <channel_id> [thread_ts] "<text>"
#   echo "<text>" | slack-post.sh <channel_id> [thread_ts]
#   slack-post.sh <channel_id> [thread_ts] <<'EOF'
#   <multi-line text with real newlines>
#   EOF

set -e
source "${0:A:h}/_lib.sh"

CHANNEL_ID="${1:?usage: slack-post.sh <channel_id> [thread_ts] [text]}"
shift

THREAD_TS=""
if [ $# -gt 0 ]; then
  FIRST="$1"
  LAST="${@: -1}"
  if [[ "$FIRST" =~ ^[0-9]{10}\.[0-9]+$ ]]; then
    THREAD_TS="$FIRST"; shift
  elif [[ "$LAST" =~ ^[0-9]{10}\.[0-9]+$ ]]; then
    THREAD_TS="$LAST"; set -- "${@[1,-2]}"
  fi
fi

TEXT="$*"
[ -z "$TEXT" ] && [ ! -t 0 ] && TEXT="$(cat)"
[ -z "$TEXT" ] && { echo "ERROR: no text provided" >&2; exit 1; }

TOKEN="$(get_bot_token)"

PAYLOAD="$(/usr/bin/python3 -c '
import json, sys
ch, txt, tts = sys.argv[1], sys.argv[2], sys.argv[3]
d = {"channel": ch, "text": txt, "mrkdwn": True}
if tts: d["thread_ts"] = tts
print(json.dumps(d))
' "$CHANNEL_ID" "$TEXT" "$THREAD_TS")"

RESP="$(curl -fsS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data "$PAYLOAD" \
  https://slack.com/api/chat.postMessage)"

OK="$(echo "$RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("ok"))')"
[ "$OK" = "True" ] || { echo "ERROR: chat.postMessage failed" >&2; echo "$RESP" >&2; exit 1; }

TS="$(echo "$RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("ts",""))')"
echo "OK ts=$TS"
