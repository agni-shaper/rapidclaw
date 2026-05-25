#!/bin/zsh
# slack-upload.sh — upload a file and post a message with it as initial comment.
# Usage:
#   slack-upload.sh <channel_id> <file_path> "<message>"
#   slack-upload.sh <channel_id> <file_path> "<message>" <thread_ts>
#   echo "message" | slack-upload.sh <channel_id> <file_path> [thread_ts]

set -e
source "${0:A:h}/_lib.sh"

CHANNEL_ID="${1:?usage: slack-upload.sh <channel_id> <file_path> [message] [thread_ts]}"
FILE_PATH="${2:?usage: slack-upload.sh <channel_id> <file_path> [message] [thread_ts]}"
shift 2

THREAD_TS=""
if [ $# -gt 0 ]; then
  LAST="${@: -1}"
  if [[ "$LAST" =~ ^[0-9]{10}\.[0-9]+$ ]]; then
    THREAD_TS="$LAST"; set -- "${@[1,-2]}"
  fi
fi
MESSAGE="$*"
[ -z "$MESSAGE" ] && [ ! -t 0 ] && MESSAGE="$(cat)"

[ -f "$FILE_PATH" ] || { echo "ERROR: file not found: $FILE_PATH" >&2; exit 1; }

TOKEN="$(get_bot_token)"
FILE_NAME="$(basename "$FILE_PATH")"
FILE_SIZE="$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH")"

GET_RESP="$(curl -fsS -G \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "filename=$FILE_NAME" \
  --data-urlencode "length=$FILE_SIZE" \
  https://slack.com/api/files.getUploadURLExternal)"

UPLOAD_URL="$(echo "$GET_RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("upload_url",""))')"
FILE_ID="$(echo "$GET_RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("file_id",""))')"
[ -n "$UPLOAD_URL" ] && [ -n "$FILE_ID" ] || { echo "ERROR: getUploadURLExternal failed" >&2; echo "$GET_RESP" >&2; exit 1; }

curl -fsS -X POST -F "file=@$FILE_PATH" "$UPLOAD_URL" > /dev/null

PAYLOAD="$(/usr/bin/python3 -c '
import json, sys
fid, fn, ch, msg, tts = sys.argv[1:6]
d = {"files": [{"id": fid, "title": fn}], "channel_id": ch}
if msg: d["initial_comment"] = msg
if tts: d["thread_ts"] = tts
print(json.dumps(d))
' "$FILE_ID" "$FILE_NAME" "$CHANNEL_ID" "$MESSAGE" "$THREAD_TS")"

COMPLETE_RESP="$(curl -fsS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data "$PAYLOAD" \
  https://slack.com/api/files.completeUploadExternal)"

OK="$(echo "$COMPLETE_RESP" | /usr/bin/python3 -c 'import json,sys; print(json.loads(sys.stdin.read(), strict=False).get("ok"))')"
[ "$OK" = "True" ] || { echo "ERROR: completeUploadExternal failed" >&2; echo "$COMPLETE_RESP" >&2; exit 1; }

echo "OK uploaded $FILE_NAME"
