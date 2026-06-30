#!/bin/zsh
# reminder-list.sh — print scheduled reminders.
#
# Usage:
#   reminder-list.sh                     # pending reminders today onwards
#   reminder-list.sh --all               # everything (pending + fired + cancelled)
#   reminder-list.sh --on YYYY-MM-DD     # pending reminders for that date
#   reminder-list.sh --today             # pending reminders for today (what daily.md picks up)

set -e
source "${0:A:h}/_lib.sh"

WHERE="WHERE status='pending' AND fire_date >= '$(today_ist)'"
case "${1:-}" in
  --all)   WHERE="" ;;
  --today) WHERE="WHERE status='pending' AND fire_date = '$(today_ist)'" ;;
  --on)    WHERE="WHERE status='pending' AND fire_date = '${2:?--on requires date}'" ;;
  "")      ;;
  *) echo "usage: reminder-list.sh [--all | --today | --on YYYY-MM-DD]" >&2; exit 1 ;;
esac

# Bodies can contain newlines + pipes — query IDs, then fetch each row individually.
IDS=$(db_query "SELECT id FROM reminders $WHERE ORDER BY fire_date, COALESCE(fire_time, '');")
if [ -z "$IDS" ]; then
  echo "(no reminders)"
  exit 0
fi

for id in ${(f)IDS}; do
  fdate=$(db_query  "SELECT fire_date FROM reminders WHERE id=$id;")
  ftime=$(db_query  "SELECT COALESCE(fire_time,'') FROM reminders WHERE id=$id;")
  cid=$(db_query    "SELECT COALESCE(channel_id,'') FROM reminders WHERE id=$id;")
  tts=$(db_query    "SELECT COALESCE(thread_ts,'') FROM reminders WHERE id=$id;")
  stat=$(db_query   "SELECT status FROM reminders WHERE id=$id;")
  body=$(db_query   "SELECT body FROM reminders WHERE id=$id;")

  printf "[#%s] %s%s · %s%s · %s\n" \
    "$id" "$fdate" "${ftime:+ $ftime}" "$cid" "${tts:+ (thread $tts)}" "$stat"
  # indent the body
  echo "$body" | sed 's/^/  /'
  echo ""
done
