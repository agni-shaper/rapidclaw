#!/bin/zsh
# task-list.sh — query sqlite `tasks` with optional filters.
#
# Usage:
#   task-list.sh                       # open tasks, all assignees
#   task-list.sh --assignee @handle    # open tasks for one person
#   task-list.sh --status <s>          # any status (open|in_progress|done|carried|cancelled|any)
#   task-list.sh --category <c>        # marketing / sprint / bug / adhoc
#   task-list.sh --product <p>         # rapidnative / applighter / letsdeployit
#   task-list.sh --due YYYY-MM-DD      # tasks due on that date
#   task-list.sh --overdue             # open tasks with due_date < today
#   task-list.sh --all                 # every task, every status
#
# Filters compose (all AND'd). Output: one line per task,
# "#id · @handle · status/priority · due · category[/product] · title"

set -e
source "${0:A:h}/_lib.sh"

ASSIGNEE=""
STATUS="open"
CATEGORY=""
PRODUCT=""
DUE=""
OVERDUE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --assignee) ASSIGNEE="${2:?--assignee requires a value}"; shift 2 ;;
    --status)   STATUS="${2:?--status requires a value}"; shift 2 ;;
    --category) CATEGORY="${2:?--category requires a value}"; shift 2 ;;
    --product)  PRODUCT="${2:?--product requires a value}"; shift 2 ;;
    --due)      DUE="${2:?--due requires YYYY-MM-DD}"; shift 2 ;;
    --overdue)  OVERDUE=1; shift ;;
    --all)      STATUS="any"; shift ;;
    *)          echo "usage: task-list.sh [--assignee @X] [--status …] [--category …] [--product …] [--due YYYY-MM-DD] [--overdue] [--all]" >&2; exit 1 ;;
  esac
done

# Build WHERE
WHERE_PARTS=()

if [ "$STATUS" != "any" ]; then
  WHERE_PARTS+=("status='$STATUS'")
fi

if [ -n "$ASSIGNEE" ]; then
  if [[ "$ASSIGNEE" == @* ]]; then
    SID=$(lookup_slack_id "$ASSIGNEE")
    [ -n "$SID" ] || { echo "ERROR: handle not found in people.md: $ASSIGNEE" >&2; exit 1; }
  else
    SID="${ASSIGNEE//[\`<>@]/}"
  fi
  WHERE_PARTS+=("assignee='$SID'")
fi

[ -n "$CATEGORY" ] && WHERE_PARTS+=("category='$CATEGORY'")
[ -n "$PRODUCT" ]  && WHERE_PARTS+=("product='$PRODUCT'")
[ -n "$DUE" ]      && WHERE_PARTS+=("due_date='$DUE'")

if [ "$OVERDUE" -eq 1 ]; then
  TODAY=$(today_ist)
  WHERE_PARTS+=("due_date < '$TODAY'")
  # Overdue only makes sense for still-open tasks
  [ "$STATUS" = "any" ] && WHERE_PARTS+=("status IN ('open','in_progress','carried')")
fi

WHERE=""
if [ ${#WHERE_PARTS[@]} -gt 0 ]; then
  WHERE="WHERE ${(j: AND :)WHERE_PARTS}"
fi

ROWS=$(db_query "SELECT id, assignee, status, priority, due_date, category, product, title FROM tasks $WHERE ORDER BY (due_date IS NULL), due_date, priority='blocker' DESC, priority='high' DESC, id;")

if [ -z "$ROWS" ]; then
  echo "(no tasks match)"
  exit 0
fi

echo "$ROWS" | while IFS='|' read -r id sid stat prio due cat prod title; do
  handle=$(lookup_handle "$sid" 2>/dev/null)
  [ -z "$handle" ] && handle="<@$sid>"
  [ -z "$due" ] && due="(no due)"
  loc="$cat"
  [ -n "$prod" ] && loc="$cat/$prod"
  printf "#%s · %s · %s/%s · %s · %s · %s\n" "$id" "$handle" "$stat" "$prio" "$due" "$loc" "$title"
done
