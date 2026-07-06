#!/bin/zsh
# task-rm.sh — soft-delete a task (status='cancelled'). Never DELETEs.
#
# Usage:
#   task-rm.sh <id> [id ...]
#
# Audit trail (row + assignee + title + created_at) stays in sqlite forever.
# To restore: task-update.sh <id> status=open.

set -e
source "${0:A:h}/../../../../accountability/routines/_lib.sh"

[ $# -gt 0 ] || { echo "usage: task-rm.sh <id> [id ...]" >&2; exit 1; }

for ID in "$@"; do
  [[ "$ID" =~ ^[0-9]+$ ]] || { echo "ERROR: id must be a positive integer: $ID" >&2; exit 1; }
  ROW=$(db_query "SELECT assignee, status, title FROM tasks WHERE id=$ID;")
  [ -n "$ROW" ] || { echo "ERROR: no task with id=$ID" >&2; exit 1; }
  IFS='|' read -r sid stat title <<< "$ROW"
  handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
  if [ "$stat" = "cancelled" ]; then
    echo "SKIP · task #$ID already cancelled · $handle · $title"
    continue
  fi
  db_exec "UPDATE tasks SET status='cancelled', updated_at=datetime('now') WHERE id=$ID;"
  echo "OK · task #$ID cancelled · $handle · $title"
done
