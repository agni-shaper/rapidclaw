#!/bin/zsh
# task-get.sh — print full detail for a single task.
#
# Usage:
#   task-get.sh <id>              # human-readable multi-line output
#   task-get.sh <id> --json       # single-object JSON
#
# Fields: id, title, description, assignee (Slack ID + @handle),
#         status, priority, category, product, source, due_date,
#         created_at, updated_at, metadata.

set -e
source "${0:A:h}/../../../../accountability/routines/_lib.sh"

FORMAT="text"
ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) FORMAT="json"; shift ;;
    *)      ID="$1"; shift ;;
  esac
done

[ -n "$ID" ] || { echo "usage: task-get.sh <id> [--json]" >&2; exit 1; }
[[ "$ID" =~ ^[0-9]+$ ]] || { echo "ERROR: id must be a positive integer" >&2; exit 1; }

if [ "$FORMAT" = "json" ]; then
  JSON=$(sqlite3 -json "$DB_PATH" "SELECT * FROM tasks WHERE id=$ID;")
  if [ "$JSON" = "[]" ] || [ -z "$JSON" ]; then
    echo "ERROR: no task with id=$ID" >&2
    exit 1
  fi
  # Strip [ ] wrapper — return a single object
  echo "$JSON" | sed -e 's/^\[//' -e 's/\]$//'
  exit 0
fi

ROW=$(db_query "SELECT id, title, description, assignee, status, priority, category, product, source, due_date, created_at, updated_at, metadata FROM tasks WHERE id=$ID;")
[ -n "$ROW" ] || { echo "ERROR: no task with id=$ID" >&2; exit 1; }

IFS='|' read -r id title desc sid stat prio cat prod source due created updated metadata <<< "$ROW"
handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
[ -z "$due" ] && due="(no due)"

echo "task #$id"
echo "  title:       $title"
[ -n "$desc" ]     && echo "  description: $desc"
echo "  assignee:    $handle (Slack: $sid)"
echo "  status:      $stat"
echo "  priority:    $prio"
[ -n "$cat" ]      && echo "  category:    $cat"
[ -n "$prod" ]     && echo "  product:     $prod"
[ -n "$source" ]   && echo "  source:      $source"
echo "  due_date:    $due"
echo "  created:     $created"
echo "  updated:     $updated"
[ -n "$metadata" ] && echo "  metadata:    $metadata"
