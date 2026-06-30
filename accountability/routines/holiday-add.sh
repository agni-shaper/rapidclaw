#!/bin/zsh
# holiday-add.sh — log a team-wide holiday into sqlite.
#
# Usage:
#   holiday-add.sh <date> <name> [region]
#
# Date IST, YYYY-MM-DD. Region optional (e.g. "India", "company").
# For multi-day breaks, call once per day.

set -e
source "${0:A:h}/_lib.sh"

DATE="${1:?usage: holiday-add.sh <date> <name> [region]}"
NAME="${2:?name required}"
REGION="${3:-}"

[[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: date must be YYYY-MM-DD" >&2; exit 1; }

NAME_ESC="${NAME//\'/\'\'}"
REGION_ESC="${REGION//\'/\'\'}"

db_exec "INSERT INTO holidays (date, name, region, status) VALUES ('$DATE', '$NAME_ESC', NULLIF('$REGION_ESC',''), 'upcoming');"
echo "OK · $DATE · $NAME${REGION:+ ($REGION)}"
