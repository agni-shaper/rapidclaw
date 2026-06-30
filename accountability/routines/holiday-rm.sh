#!/bin/zsh
# holiday-rm.sh — soft-delete a holiday (status → 'past').
#
# Usage:
#   holiday-rm.sh <date>

set -e
source "${0:A:h}/_lib.sh"

DATE="${1:?usage: holiday-rm.sh <date>}"

CHANGED=$(db_query "SELECT COUNT(*) FROM holidays WHERE date='$DATE' AND status='upcoming';")
[ "$CHANGED" = "0" ] && { echo "ERROR: no upcoming holiday on $DATE" >&2; exit 1; }

db_exec "UPDATE holidays SET status='past' WHERE date='$DATE' AND status='upcoming';"
echo "OK · marked past: $DATE"
