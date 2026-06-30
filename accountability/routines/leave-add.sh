#!/bin/zsh
# leave-add.sh — log a leave entry into sqlite.
#
# Usage:
#   leave-add.sh <SLACK_ID> <start_date> <end_date> [note...]
#
# SLACK_ID accepts `<@U…>`, `U…`, or `@handle` (resolved via people.md).
# Dates inclusive, IST. Note is optional.

set -e
source "${0:A:h}/_lib.sh"

SID_RAW="${1:?usage: leave-add.sh <SLACK_ID> <start_date> <end_date> [note]}"
START="${2:?start_date required (YYYY-MM-DD)}"
END="${3:?end_date required (YYYY-MM-DD)}"
shift 3
NOTE="$*"

# Resolve @handle → U... if needed
if [[ "$SID_RAW" == @* ]]; then
  SID=$(lookup_slack_id "$SID_RAW")
  [ -n "$SID" ] || { echo "ERROR: handle not found in people.md: $SID_RAW" >&2; exit 1; }
else
  SID="${SID_RAW//[\`<>@]/}"
fi

# Validate dates
[[ "$START" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: start_date must be YYYY-MM-DD" >&2; exit 1; }
[[ "$END"   =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: end_date must be YYYY-MM-DD" >&2; exit 1; }
[[ "$START" > "$END" ]] && { echo "ERROR: start_date is after end_date" >&2; exit 1; }

NOTE_ESC="${NOTE//\'/\'\'}"

db_exec "INSERT INTO leave_entries (slack_id, start_date, end_date, note, status) VALUES ('$SID', '$START', '$END', '$NOTE_ESC', 'active');"

HANDLE=$(lookup_handle "$SID")
echo "OK · $HANDLE ($SID) · $START to $END · ${NOTE:-no note}"
