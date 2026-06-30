#!/bin/zsh
# leave-rm.sh — soft-delete a leave entry (status → 'past').
#
# Usage:
#   leave-rm.sh <SLACK_ID> <start_date>
#
# Matches the unique (slack_id, start_date) entry. No hard DELETE — keeps audit trail.

set -e
source "${0:A:h}/_lib.sh"

SID_RAW="${1:?usage: leave-rm.sh <SLACK_ID> <start_date>}"
START="${2:?start_date required (YYYY-MM-DD)}"

if [[ "$SID_RAW" == @* ]]; then
  SID=$(lookup_slack_id "$SID_RAW")
  [ -n "$SID" ] || { echo "ERROR: handle not found in people.md: $SID_RAW" >&2; exit 1; }
else
  SID="${SID_RAW//[\`<>@]/}"
fi

CHANGED=$(db_query "SELECT COUNT(*) FROM leave_entries WHERE slack_id='$SID' AND start_date='$START' AND status='active';")
[ "$CHANGED" = "0" ] && { echo "ERROR: no active leave entry for $SID starting $START" >&2; exit 1; }

db_exec "UPDATE leave_entries SET status='past' WHERE slack_id='$SID' AND start_date='$START' AND status='active';"
echo "OK · marked past: $SID · start $START"
