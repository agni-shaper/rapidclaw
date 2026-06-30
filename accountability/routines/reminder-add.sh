#!/bin/zsh
# reminder-add.sh — schedule a reminder to fire on a future morning.
#
# Usage:
#   reminder-add.sh <fire_date> <body> [--time HH:MM] [--channel <id>] [--thread <ts>] [--by <slack_id>]
#
# fire_date: YYYY-MM-DD IST. The daily routine (11:30 IST) picks it up.
# body: free text (Slack mrkdwn supported). Use <@U…> for pings.
# --channel defaults to $SLACK_CONTENT_CHANNEL_ID (or C0B4HG16QP3 #rapidnative-coach).
# --thread optional: post as a thread reply instead of top-level.
# --by: who scheduled it (Slack ID); defaults to "bot".
#
# Example:
#   reminder-add.sh 2026-07-01 "Time to ship the v2 cutover" --by U09DC8L7PCZ

set -e
source "${0:A:h}/_lib.sh"

DATE="${1:?usage: reminder-add.sh <fire_date> <body> [--time HH:MM] [--channel <id>] [--thread <ts>] [--by <id>]}"
BODY="${2:?body required}"
shift 2

TIME=""
CHANNEL="C0B4HG16QP3"  # #rapidnative-coach (bot home)
THREAD=""
BY="bot"
while [ $# -gt 0 ]; do
  case "$1" in
    --time)    TIME="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    --thread)  THREAD="$2"; shift 2 ;;
    --by)      BY="${2//[\`<>@]/}"; shift 2 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: fire_date must be YYYY-MM-DD" >&2; exit 1; }
[ -n "$TIME" ] && { [[ "$TIME" =~ ^[0-9]{2}:[0-9]{2}$ ]] || { echo "ERROR: --time must be HH:MM" >&2; exit 1; }; }

BODY_ESC="${BODY//\'/\'\'}"

db_exec "INSERT INTO reminders (fire_date, fire_time, channel_id, thread_ts, body, created_by, status) VALUES ('$DATE', NULLIF('$TIME',''), '$CHANNEL', NULLIF('$THREAD',''), '$BODY_ESC', '$BY', 'pending'); SELECT last_insert_rowid();"
echo "OK · scheduled for $DATE${TIME:+ at $TIME IST} · channel $CHANNEL${THREAD:+ thread $THREAD}"
