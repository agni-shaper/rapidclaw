#!/bin/zsh
# task-add.sh — insert a new task into sqlite `tasks`.
#
# Usage:
#   task-add.sh <@handle|SLACK_ID> <due_date> <title...>
#     [--priority low|normal|high|blocker]  (default: normal)
#     [--category marketing|sprint|bug|adhoc]  (default: adhoc)
#     [--product rapidnative|applighter|letsdeployit]
#     [--source <string>]                  (e.g. 'slack:1720000000.123456')
#     [--description <text>]
#     [--force]                            (bypass on-leave / non-working-day guards)
#
# Assignee accepts `@handle`, `<@U…>`, or bare `U…`. Handle → Slack ID via people.md.
# Refuses to insert if assignee is on leave on due_date (unless --force).
# Warns (but proceeds) if due_date is a weekend or team holiday.
#
# Emits the new row id on success.

set -e
source "${0:A:h}/_lib.sh"

# ─── args ───
if [ $# -lt 3 ]; then
  echo "usage: task-add.sh <@handle|SLACK_ID> <due_date YYYY-MM-DD> <title...> [--priority …] [--category …] [--product …] [--source …] [--description …] [--force]" >&2
  exit 1
fi

ASSIGNEE_RAW="$1"; shift
DUE="$1"; shift

PRIORITY="normal"
CATEGORY="adhoc"
PRODUCT=""
SOURCE=""
DESCRIPTION=""
FORCE=0
TITLE_PARTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --priority)    PRIORITY="${2:?--priority requires a value}"; shift 2 ;;
    --category)    CATEGORY="${2:?--category requires a value}"; shift 2 ;;
    --product)     PRODUCT="${2:?--product requires a value}"; shift 2 ;;
    --source)      SOURCE="${2:?--source requires a value}"; shift 2 ;;
    --description) DESCRIPTION="${2:?--description requires a value}"; shift 2 ;;
    --force)       FORCE=1; shift ;;
    --*)           echo "ERROR: unknown flag $1" >&2; exit 1 ;;
    *)             TITLE_PARTS+=("$1"); shift ;;
  esac
done

TITLE="${TITLE_PARTS[*]}"
[ -n "$TITLE" ] || { echo "ERROR: title required" >&2; exit 1; }

# ─── validate ───
[[ "$DUE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: due_date must be YYYY-MM-DD" >&2; exit 1; }
case "$PRIORITY" in low|normal|high|blocker) ;; *) echo "ERROR: --priority must be one of low|normal|high|blocker" >&2; exit 1 ;; esac

# ─── resolve assignee ───
if [[ "$ASSIGNEE_RAW" == @* ]]; then
  SID=$(lookup_slack_id "$ASSIGNEE_RAW")
  [ -n "$SID" ] || { echo "ERROR: handle not found in definitions/people.md: $ASSIGNEE_RAW" >&2; exit 1; }
else
  SID="${ASSIGNEE_RAW//[\`<>@]/}"
fi
HANDLE=$(lookup_handle "$SID"); [ -z "$HANDLE" ] && HANDLE="<@$SID>"

# ─── composed guards ───
if is_on_leave "$SID" "$DUE"; then
  if [ "$FORCE" -eq 1 ]; then
    echo "WARN: $HANDLE is on leave on $DUE — proceeding (--force)" >&2
  else
    echo "ERROR: $HANDLE is on leave on $DUE. Reassign, change due_date, or pass --force." >&2
    exit 2
  fi
fi

if ! is_working_day "$DUE"; then
  if is_weekend "$DUE"; then
    echo "WARN: $DUE is a weekend — proceeding" >&2
  else
    LABEL=$(db_query "SELECT name FROM holidays WHERE date='$DUE' AND status='upcoming' LIMIT 1;" 2>/dev/null || true)
    echo "WARN: $DUE is a holiday${LABEL:+ ($LABEL)} — proceeding" >&2
  fi
fi

# ─── insert ───
TITLE_ESC="${TITLE//\'/\'\'}"
DESCRIPTION_ESC="${DESCRIPTION//\'/\'\'}"
SOURCE_ESC="${SOURCE//\'/\'\'}"
PRODUCT_ESC="${PRODUCT//\'/\'\'}"
CATEGORY_ESC="${CATEGORY//\'/\'\'}"

ID=$(db_exec "INSERT INTO tasks (title, description, assignee, status, priority, category, product, source, due_date)
  VALUES ('$TITLE_ESC', '$DESCRIPTION_ESC', '$SID', 'open', '$PRIORITY', '$CATEGORY_ESC', '$PRODUCT_ESC', '$SOURCE_ESC', '$DUE');
  SELECT last_insert_rowid();")

echo "OK · task #$ID · $HANDLE · $DUE · $CATEGORY${PRODUCT:+/$PRODUCT} · $PRIORITY · $TITLE"
