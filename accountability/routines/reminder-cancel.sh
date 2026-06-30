#!/bin/zsh
# reminder-cancel.sh — cancel a pending reminder (status → 'cancelled').
#
# Usage:
#   reminder-cancel.sh <id>
#
# Use reminder-list.sh to find the id.

set -e
source "${0:A:h}/_lib.sh"

ID="${1:?usage: reminder-cancel.sh <id>}"
[[ "$ID" =~ ^[0-9]+$ ]] || { echo "ERROR: id must be a positive integer" >&2; exit 1; }

CHANGED=$(db_query "SELECT COUNT(*) FROM reminders WHERE id=$ID AND status='pending';")
[ "$CHANGED" = "0" ] && { echo "ERROR: no pending reminder with id=$ID" >&2; exit 1; }

db_exec "UPDATE reminders SET status='cancelled' WHERE id=$ID;"
echo "OK · cancelled reminder #$ID"
