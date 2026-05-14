#!/bin/zsh
# slack-read-thread.sh — read a thread (parent + replies) via conversations.replies.
# Usage: slack-read-thread.sh <channel_id> <message_ts> [limit]
# Output: pretty JSON {ok, messages: [{user, ts, thread_ts, text, files:[name...]}]}

set -e
source "${0:A:h}/_lib.sh"

CHANNEL_ID="${1:?usage: slack-read-thread.sh <channel_id> <message_ts> [limit]}"
MESSAGE_TS="${2:?usage: slack-read-thread.sh <channel_id> <message_ts> [limit]}"
LIMIT="${3:-100}"

TOKEN="$(get_bot_token)"

curl -fsS -G \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "channel=$CHANNEL_ID" \
  --data-urlencode "ts=$MESSAGE_TS" \
  --data-urlencode "limit=$LIMIT" \
  https://slack.com/api/conversations.replies \
  | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
if not d.get("ok"):
    print("ERROR:", json.dumps(d), file=sys.stderr); sys.exit(1)
msgs = [{
    "user": m.get("user"),
    "ts": m.get("ts"),
    "thread_ts": m.get("thread_ts"),
    "text": m.get("text", ""),
    "files": [f.get("name") for f in (m.get("files") or [])],
} for m in d.get("messages", [])]
print(json.dumps({"ok": True, "messages": msgs}, indent=2, ensure_ascii=False))
'
