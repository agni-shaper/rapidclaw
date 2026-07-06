#!/bin/zsh
# task-done.sh — mark one or more tasks as done.
#
# Usage:
#   task-done.sh <id> [id ...]
#
# Sets status='done' and bumps updated_at. Idempotent — re-marking a done
# task is a no-op message (no error).

set -e
source "${0:A:h}/../../../../accountability/routines/_lib.sh"

[ $# -gt 0 ] || { echo "usage: task-done.sh <id> [id ...]" >&2; exit 1; }

for ID in "$@"; do
  [[ "$ID" =~ ^[0-9]+$ ]] || { echo "ERROR: id must be a positive integer: $ID" >&2; exit 1; }
  ROW=$(db_query "SELECT assignee, status, title FROM tasks WHERE id=$ID;")
  [ -n "$ROW" ] || { echo "ERROR: no task with id=$ID" >&2; exit 1; }
  IFS='|' read -r sid stat title <<< "$ROW"
  handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
  if [ "$stat" = "done" ]; then
    echo "SKIP · task #$ID already done · $handle · $title"
    continue
  fi
  db_exec "UPDATE tasks SET status='done', updated_at=datetime('now') WHERE id=$ID;"
  echo "OK · task #$ID done · $handle · $title"
done
