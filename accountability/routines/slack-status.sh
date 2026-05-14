#!/bin/zsh
# slack-status.sh — post or update a single Slack status message in place.
# Usage:
#   slack-status.sh post   <channel_id> <thread_ts|-> "<text>"     # prints ts of new
#   slack-status.sh update <channel_id> <ts>          "<text>"     # rewrites
#   echo "<text>" | slack-status.sh post   <channel_id> <thread_ts|->
#   echo "<text>" | slack-status.sh update <channel_id> <ts>

set -e
source "${0:A:h}/_lib.sh"

SUBCMD="${1:?usage: slack-status.sh <post|update> <channel> <ts|-> [text]}"
shift

TOKEN="$(get_bot_token)"

build_payload() {
  /usr/bin/python3 -c '
import json, sys
ch, txt, mode = sys.argv[1], sys.argv[2], sys.argv[3]
d = {"channel": ch, "text": txt, "mrkdwn": True}
if mode.startswith("thread:"): d["thread_ts"] = mode.split(":", 1)[1]
elif mode.startswith("update:"): d["ts"] = mode.split(":", 1)[1]
print(json.dumps(d))
' "$1" "$2" "$3"
}

read_text() {
  local t="$*"
  [ -z "$t" ] && [ ! -t 0 ] && t="$(cat)"
  printf '%s' "$t"
}

call_slack() {
  curl -fsS -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data "$2" \
    "https://slack.com/api/$1"
}

case "$SUBCMD" in
  post)
    CHANNEL="${1:?channel required}"
    THREAD_TS="${2:?thread_ts or '-' required}"
    shift 2
    TEXT="$(read_text "$@")"
    [ -z "$TEXT" ] && { echo "ERROR: empty text" >&2; exit 1; }
    MODE="top"
    [ "$THREAD_TS" != "-" ] && [ -n "$THREAD_TS" ] && MODE="thread:$THREAD_TS"
    PAYLOAD="$(build_payload "$CHANNEL" "$TEXT" "$MODE")"
    RESP="$(call_slack chat.postMessage "$PAYLOAD")"
    OK="$(echo "$RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("ok"))')"
    [ "$OK" = "True" ] || { echo "ERROR: $RESP" >&2; exit 1; }
    echo "$RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False)["ts"])'
    ;;
  update)
    CHANNEL="${1:?channel required}"
    TS="${2:?message ts required}"
    shift 2
    TEXT="$(read_text "$@")"
    [ -z "$TEXT" ] && { echo "ERROR: empty text" >&2; exit 1; }
    PAYLOAD="$(build_payload "$CHANNEL" "$TEXT" "update:$TS")"
    RESP="$(call_slack chat.update "$PAYLOAD")"
    OK="$(echo "$RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("ok"))')"
    [ "$OK" = "True" ] || { echo "ERROR: $RESP" >&2; exit 1; }
    echo "OK ts=$TS"
    ;;
  *) echo "ERROR: unknown subcommand '$SUBCMD' (use post|update)" >&2; exit 1 ;;
esac
