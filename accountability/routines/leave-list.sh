#!/bin/zsh
# leave-list.sh — print leave entries.
#
# Usage:
#   leave-list.sh             # active entries only (covering today onwards)
#   leave-list.sh --all       # active + past
#   leave-list.sh --on YYYY-MM-DD   # active entries covering that date
#
# Output: one line per entry, "@handle · start to end · note"

set -e
source "${0:A:h}/_lib.sh"

MODE="active"
ON_DATE=""
case "${1:-}" in
  --all) MODE="all" ;;
  --on)  MODE="on"; ON_DATE="${2:?--on requires YYYY-MM-DD}" ;;
  "")    ;;
  *)     echo "usage: leave-list.sh [--all | --on YYYY-MM-DD]" >&2; exit 1 ;;
esac

case "$MODE" in
  active) WHERE="WHERE status='active' AND end_date >= '$(today_ist)'" ;;
  all)    WHERE="" ;;
  on)     WHERE="WHERE status='active' AND '$ON_DATE' BETWEEN start_date AND end_date" ;;
esac

ROWS=$(db_query "SELECT slack_id, start_date, end_date, note, status FROM leave_entries $WHERE ORDER BY start_date;")
if [ -z "$ROWS" ]; then
  if [ "$MODE" = "active" ]; then echo "(no active leave)"; else echo "(no entries)"; fi
  exit 0
fi

echo "$ROWS" | while IFS='|' read -r sid start_d end_d note stat; do
  handle=$(lookup_handle "$sid")
  [ -z "$handle" ] && handle="<@$sid>"
  if [ "$MODE" = "all" ] && [ "$stat" = "past" ]; then
    printf "  past · %s · %s to %s · %s\n" "$handle" "$start_d" "$end_d" "$note"
  else
    printf "%s · %s to %s · %s\n" "$handle" "$start_d" "$end_d" "$note"
  fi
done
