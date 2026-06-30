#!/bin/zsh
# holiday-list.sh — print holidays.
#
# Usage:
#   holiday-list.sh             # upcoming only (today onwards)
#   holiday-list.sh --all       # upcoming + past
#
# Output: "YYYY-MM-DD · name (region)"

set -e
source "${0:A:h}/_lib.sh"

if [ "${1:-}" = "--all" ]; then
  WHERE=""
elif [ -z "${1:-}" ]; then
  WHERE="WHERE status='upcoming' AND date >= '$(today_ist)'"
else
  echo "usage: holiday-list.sh [--all]" >&2; exit 1
fi

ROWS=$(db_query "SELECT date, name, region, status FROM holidays $WHERE ORDER BY date;")
if [ -z "$ROWS" ]; then
  echo "(no holidays)"
  exit 0
fi

echo "$ROWS" | while IFS='|' read -r d name region stat; do
  suffix=""; [ -n "$region" ] && suffix=" ($region)"
  if [ "$stat" = "past" ]; then
    printf "  past · %s · %s%s\n" "$d" "$name" "$suffix"
  else
    printf "%s · %s%s\n" "$d" "$name" "$suffix"
  fi
done
