#!/bin/zsh
# task-update.sh — mutate fields on an existing task.
#
# Usage:
#   task-update.sh <id> field=value [field=value ...]
#
# Editable fields: assignee, status, priority, category, product, due_date,
#                  title, description, source
#
# When `assignee` or `due_date` changes, re-validates is_on_leave for the
# (assignee, due_date) pair. Refuses unless the whole change set is legal
# (pass --force to bypass).
#
# `updated_at` is always bumped.

set -e
source "${0:A:h}/_lib.sh"

ID="${1:?usage: task-update.sh <id> field=value [field=value …]}"
shift
[[ "$ID" =~ ^[0-9]+$ ]] || { echo "ERROR: id must be a positive integer" >&2; exit 1; }

FORCE=0
SET_PARTS=()
NEW_ASSIGNEE=""
NEW_DUE=""

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1; continue ;;
  esac
  [[ "$arg" == *=* ]] || { echo "ERROR: bad arg '$arg' (expected field=value)" >&2; exit 1; }
  field="${arg%%=*}"
  value="${arg#*=}"
  case "$field" in
    title|description|source|category|product)
      value_esc="${value//\'/\'\'}"
      SET_PARTS+=("$field='$value_esc'")
      ;;
    status)
      case "$value" in open|in_progress|done|carried|cancelled) ;; *) echo "ERROR: status must be open|in_progress|done|carried|cancelled" >&2; exit 1 ;; esac
      SET_PARTS+=("status='$value'")
      ;;
    priority)
      case "$value" in low|normal|high|blocker) ;; *) echo "ERROR: priority must be low|normal|high|blocker" >&2; exit 1 ;; esac
      SET_PARTS+=("priority='$value'")
      ;;
    due_date)
      [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: due_date must be YYYY-MM-DD" >&2; exit 1; }
      NEW_DUE="$value"
      SET_PARTS+=("due_date='$value'")
      ;;
    assignee)
      if [[ "$value" == @* ]]; then
        SID=$(lookup_slack_id "$value")
        [ -n "$SID" ] || { echo "ERROR: handle not found in people.md: $value" >&2; exit 1; }
      else
        SID="${value//[\`<>@]/}"
      fi
      NEW_ASSIGNEE="$SID"
      SET_PARTS+=("assignee='$SID'")
      ;;
    *) echo "ERROR: unknown field '$field' — editable: assignee status priority category product due_date title description source" >&2; exit 1 ;;
  esac
done

[ ${#SET_PARTS[@]} -eq 0 ] && { echo "ERROR: no fields to update" >&2; exit 1; }

# ─── fetch current for re-validation of leave/working-day ───
ROW=$(db_query "SELECT assignee, due_date FROM tasks WHERE id=$ID;")
[ -n "$ROW" ] || { echo "ERROR: no task with id=$ID" >&2; exit 1; }
CUR_ASSIGNEE="${ROW%%|*}"
CUR_DUE="${ROW##*|}"

EFF_ASSIGNEE="${NEW_ASSIGNEE:-$CUR_ASSIGNEE}"
EFF_DUE="${NEW_DUE:-$CUR_DUE}"

if [ -n "$EFF_ASSIGNEE" ] && [ -n "$EFF_DUE" ]; then
  if is_on_leave "$EFF_ASSIGNEE" "$EFF_DUE"; then
    handle=$(lookup_handle "$EFF_ASSIGNEE"); [ -z "$handle" ] && handle="<@$EFF_ASSIGNEE>"
    if [ "$FORCE" -eq 1 ]; then
      echo "WARN: $handle is on leave on $EFF_DUE — proceeding (--force)" >&2
    else
      echo "ERROR: $handle is on leave on $EFF_DUE. Reassign, change due_date, or pass --force." >&2
      exit 2
    fi
  fi
  if [ -n "$NEW_DUE" ] && ! is_working_day "$NEW_DUE"; then
    if is_weekend "$NEW_DUE"; then
      echo "WARN: $NEW_DUE is a weekend — proceeding" >&2
    else
      echo "WARN: $NEW_DUE is a holiday — proceeding" >&2
    fi
  fi
fi

# Always bump updated_at
SET_PARTS+=("updated_at=datetime('now')")
SET_CLAUSE="${(j:, :)SET_PARTS}"

db_exec "UPDATE tasks SET $SET_CLAUSE WHERE id=$ID;"

# Verify + emit
NEW=$(db_query "SELECT id, assignee, status, priority, due_date, category, product, title FROM tasks WHERE id=$ID;")
IFS='|' read -r id sid stat prio due cat prod title <<< "$NEW"
handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
[ -z "$due" ] && due="(no due)"
loc="$cat"; [ -n "$prod" ] && loc="$cat/$prod"
echo "OK · task #$id · $handle · $stat/$prio · $due · $loc · $title"
