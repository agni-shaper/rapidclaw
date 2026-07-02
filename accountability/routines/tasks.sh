#!/bin/zsh
# tasks.sh — unified dispatcher for the task-* CRUD scripts.
#
# THIS is the stable entry point for two kinds of callers:
#   1. The Slack listener LLM — one thing to remember, low prompt-overhead.
#   2. Other bot scripts / cron routines — same interface, machine-parseable.
#
# Underneath, each subcommand delegates to the matching `task-<verb>.sh`.
# The dispatcher adds:
#   - JSON output mode  (--json)             for programmatic callers
#   - Slack notification (--notify)          fires slack-post.sh with a summary
#   - Custom notify channel (--channel <id>) default is #rapidnative-coach
#
# ═══════════════════════════════════════════════════════════════════════════
# USAGE
# ═══════════════════════════════════════════════════════════════════════════
#
#   tasks.sh add <@handle|SID> <due_date> <title...>
#     [--priority low|normal|high|blocker]
#     [--category marketing|sprint|bug|adhoc]
#     [--product rapidnative|applighter|letsdeployit]
#     [--source <string>]     [--description <text>]
#     [--force]               [--json]     [--notify] [--channel <id>]
#
#   tasks.sh list
#     [--assignee @X]  [--status open|in_progress|done|carried|cancelled]
#     [--category …]   [--product …]  [--due YYYY-MM-DD]  [--overdue]
#     [--all]  [--json]
#
#   tasks.sh get <id>                              [--json]
#   tasks.sh update <id> field=value [field=value ...]
#                                                  [--force] [--json] [--notify] [--channel <id>]
#   tasks.sh done <id> [id ...]                    [--json] [--notify] [--channel <id>]
#   tasks.sh rm <id>   [id ...]                    [--json] [--notify] [--channel <id>]
#
#   tasks.sh help
#
# ═══════════════════════════════════════════════════════════════════════════
# EXIT CODES
#   0  success
#   1  usage / validation error
#   2  guard rejection (e.g. assignee on leave without --force)
# ═══════════════════════════════════════════════════════════════════════════

set -e
SCRIPT_PATH="${0:A}"
HERE="${SCRIPT_PATH:h}"
source "$HERE/_lib.sh"

BOT_HOME_CHANNEL="C0B4HG16QP3"   # #rapidnative-coach

show_help() {
  sed -n '/^# USAGE/,/^# EXIT CODES/p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
}

# ─── Split args: global flags (--json / --notify / --channel) vs subcommand args ───
extract_global_flags() {
  # Reads $@; sets globals FORMAT, NOTIFY, CHANNEL; assigns REMAINING array.
  FORMAT="text"
  NOTIFY=0
  CHANNEL="$BOT_HOME_CHANNEL"
  REMAINING=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --json)    FORMAT="json"; shift ;;
      --notify)  NOTIFY=1; shift ;;
      --channel) CHANNEL="${2:?--channel requires an ID}"; shift 2 ;;
      *)         REMAINING+=("$1"); shift ;;
    esac
  done
}

# ─── Notify helper — posts a summary line ───
notify_slack() {
  local text="$1"
  [ "$NOTIFY" -eq 1 ] || return 0
  "$HERE/slack-post.sh" "$CHANNEL" "$text" >/dev/null || echo "WARN: slack-post failed" >&2
}

# ─── Emit a single task as JSON (used after mutations for --json output) ───
emit_json() {
  local id="$1"
  "$HERE/task-get.sh" "$id" --json
}

# ═══════════════ Subcommand dispatch ═══════════════

CMD="${1:-}"
[ -z "$CMD" ] && { show_help; exit 1; }
shift

extract_global_flags "$@"
set -- "${REMAINING[@]}"

case "$CMD" in
  # ─── ADD ─────────────────────────────────────────────
  add)
    OUT=$("$HERE/task-add.sh" "$@")   # errors bubble via set -e
    if [ "$FORMAT" = "json" ]; then
      ID=$(echo "$OUT" | sed -nE 's/^OK · task #([0-9]+) .*/\1/p')
      emit_json "$ID"
    else
      echo "$OUT"
    fi
    if [ "$NOTIFY" -eq 1 ]; then
      ID=$(echo "$OUT" | sed -nE 's/^OK · task #([0-9]+) .*/\1/p')
      # Fetch assignee handle + due for a clean message
      ROW=$(db_query "SELECT assignee, due_date, priority, title FROM tasks WHERE id=$ID;")
      IFS='|' read -r sid due prio title <<< "$ROW"
      handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
      notify_slack ":inbox_tray: *new task #${ID}* → <@${sid}> · due ${due} · ${prio} · ${title}"
    fi
    ;;

  # ─── LIST ────────────────────────────────────────────
  list)
    if [ "$FORMAT" = "json" ]; then
      # Rebuild the WHERE clause here since task-list.sh emits text only
      ASSIGNEE=""
      STATUS="open"
      CATEGORY=""
      PRODUCT=""
      DUE=""
      OVERDUE=0
      while [ $# -gt 0 ]; do
        case "$1" in
          --assignee) ASSIGNEE="$2"; shift 2 ;;
          --status)   STATUS="$2"; shift 2 ;;
          --category) CATEGORY="$2"; shift 2 ;;
          --product)  PRODUCT="$2"; shift 2 ;;
          --due)      DUE="$2"; shift 2 ;;
          --overdue)  OVERDUE=1; shift ;;
          --all)      STATUS="any"; shift ;;
          *)          echo "ERROR: unknown list flag $1" >&2; exit 1 ;;
        esac
      done
      WHERE_PARTS=()
      [ "$STATUS" != "any" ] && WHERE_PARTS+=("status='$STATUS'")
      if [ -n "$ASSIGNEE" ]; then
        if [[ "$ASSIGNEE" == @* ]]; then
          SID=$(lookup_slack_id "$ASSIGNEE")
          [ -n "$SID" ] || { echo "ERROR: handle not found: $ASSIGNEE" >&2; exit 1; }
        else
          SID="${ASSIGNEE//[\`<>@]/}"
        fi
        WHERE_PARTS+=("assignee='$SID'")
      fi
      [ -n "$CATEGORY" ] && WHERE_PARTS+=("category='$CATEGORY'")
      [ -n "$PRODUCT" ]  && WHERE_PARTS+=("product='$PRODUCT'")
      [ -n "$DUE" ]      && WHERE_PARTS+=("due_date='$DUE'")
      if [ "$OVERDUE" -eq 1 ]; then
        WHERE_PARTS+=("due_date < '$(today_ist)'")
        [ "$STATUS" = "any" ] && WHERE_PARTS+=("status IN ('open','in_progress','carried')")
      fi
      WHERE=""; [ ${#WHERE_PARTS[@]} -gt 0 ] && WHERE="WHERE ${(j: AND :)WHERE_PARTS}"
      sqlite3 -json "$DB_PATH" "SELECT * FROM tasks $WHERE ORDER BY (due_date IS NULL), due_date, priority='blocker' DESC, priority='high' DESC, id;"
    else
      "$HERE/task-list.sh" "$@"
    fi
    ;;

  # ─── GET ─────────────────────────────────────────────
  get)
    [ $# -ge 1 ] || { echo "usage: tasks.sh get <id> [--json]" >&2; exit 1; }
    if [ "$FORMAT" = "json" ]; then
      "$HERE/task-get.sh" "$1" --json
    else
      "$HERE/task-get.sh" "$1"
    fi
    ;;

  # ─── UPDATE ──────────────────────────────────────────
  update)
    [ $# -ge 2 ] || { echo "usage: tasks.sh update <id> field=value [...]" >&2; exit 1; }
    ID="$1"
    # Capture pre-update state for the notify diff
    OLD=""
    if [ "$NOTIFY" -eq 1 ]; then
      OLD=$(db_query "SELECT assignee, status, due_date FROM tasks WHERE id=$ID;" 2>/dev/null || true)
    fi
    OUT=$("$HERE/task-update.sh" "$@")
    if [ "$FORMAT" = "json" ]; then
      emit_json "$ID"
    else
      echo "$OUT"
    fi
    if [ "$NOTIFY" -eq 1 ]; then
      ROW=$(db_query "SELECT assignee, status, due_date, title FROM tasks WHERE id=$ID;")
      IFS='|' read -r sid stat due title <<< "$ROW"
      handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
      # Detect reassignment vs. plain edit for a nicer message
      if [ -n "$OLD" ]; then
        OLD_SID="${OLD%%|*}"
        if [ "$OLD_SID" != "$sid" ]; then
          old_handle=$(lookup_handle "$OLD_SID" 2>/dev/null); [ -z "$old_handle" ] && old_handle="<@$OLD_SID>"
          notify_slack ":arrows_counterclockwise: *task #${ID} reassigned* → <@${sid}> (was ${old_handle}) · due ${due} · ${stat} · ${title}"
        else
          notify_slack ":pencil2: *task #${ID} updated* → <@${sid}> · due ${due} · ${stat} · ${title}"
        fi
      fi
    fi
    ;;

  # ─── DONE ────────────────────────────────────────────
  done)
    [ $# -ge 1 ] || { echo "usage: tasks.sh done <id> [id ...]" >&2; exit 1; }
    OUT=$("$HERE/task-done.sh" "$@")
    if [ "$FORMAT" = "json" ]; then
      # Emit each affected task as a JSON array
      echo -n '['
      first=1
      for id in "$@"; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        [ $first -eq 1 ] || echo -n ','
        first=0
        "$HERE/task-get.sh" "$id" --json
      done
      echo ']'
    else
      echo "$OUT"
    fi
    if [ "$NOTIFY" -eq 1 ]; then
      for id in "$@"; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        ROW=$(db_query "SELECT assignee, title FROM tasks WHERE id=$id;")
        IFS='|' read -r sid title <<< "$ROW"
        handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
        notify_slack ":white_check_mark: *task #${id} done* · <@${sid}> · ${title}"
      done
    fi
    ;;

  # ─── RM / CANCEL ─────────────────────────────────────
  rm|cancel)
    [ $# -ge 1 ] || { echo "usage: tasks.sh rm <id> [id ...]" >&2; exit 1; }
    OUT=$("$HERE/task-rm.sh" "$@")
    if [ "$FORMAT" = "json" ]; then
      echo -n '['
      first=1
      for id in "$@"; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        [ $first -eq 1 ] || echo -n ','
        first=0
        "$HERE/task-get.sh" "$id" --json
      done
      echo ']'
    else
      echo "$OUT"
    fi
    if [ "$NOTIFY" -eq 1 ]; then
      for id in "$@"; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        ROW=$(db_query "SELECT assignee, title FROM tasks WHERE id=$id;")
        IFS='|' read -r sid title <<< "$ROW"
        handle=$(lookup_handle "$sid" 2>/dev/null); [ -z "$handle" ] && handle="<@$sid>"
        notify_slack ":wastebasket: *task #${id} cancelled* · <@${sid}> · ${title}"
      done
    fi
    ;;

  # ─── HELP ────────────────────────────────────────────
  help|-h|--help)
    show_help
    ;;

  *)
    echo "ERROR: unknown subcommand '$CMD' — try: add / list / get / update / done / rm / help" >&2
    exit 1
    ;;
esac
