#!/bin/zsh
# task-assist.sh — post recon-derived assistance to a task's Slack thread.
#
# Usage:
#   task-assist.sh <task_id> [--dry-run]
#
# What it does:
#   1. Reads the task via `tasks.sh get <id> --json` (assignee, product, title,
#      slack_message_ts, slack_message_url, etc.).
#   2. Runs gen-task-assistance.py to classify the task by title pattern and
#      look up matching data in today's marketing-recon cache.
#   3. If assistance content was found, posts it as a thread reply under the
#      task's original notification (using slack_message_ts). Also stashes
#      the metadata blob into the task's `metadata` JSON column for the
#      Kanban UI to render.
#   4. If no assistance is available (task has no product, wrong category,
#      recon has no matching data, or classification failed), posts a
#      one-line "No pre-computed assistance" note so the assignee still
#      knows the bot looked.
#
# Exit codes:
#   0  posted successfully (or --dry-run)
#   1  usage / task not found / no slack_message_ts (task wasn't --notify'd)
#   2  Slack post failed
#
# NOT wired into cron. Callable from:
#   - CLI: `task-assist.sh 142`
#   - Slack listener LLM via the task-assistance skill (`.claude/skills/task-assistance/SKILL.md`)
#   - (future) `gen-marketing-morning.py` post-hook, Kanban UI button

set -e
source "${0:A:h}/_lib.sh"

TASK_ID="${1:?usage: task-assist.sh <task_id> [--dry-run]}"
DRY_RUN=0
[ "${2:-}" = "--dry-run" ] && DRY_RUN=1

[[ "$TASK_ID" =~ ^[0-9]+$ ]] || { echo "ERROR: task_id must be a positive integer" >&2; exit 1; }

HERE="${0:A:h}"
TASKS_SH="$HERE/tasks.sh"
GEN_PY="$HERE/gen-task-assistance.py"
SLACK_POST="$HERE/slack-post.sh"

# ─── 1. Fetch task ───
TASK_JSON=$("$TASKS_SH" get "$TASK_ID" --json 2>/dev/null || true)
[ -n "$TASK_JSON" ] || { echo "ERROR: task #$TASK_ID not found" >&2; exit 1; }

# Extract the fields we need. Using python for JSON parsing — jq isn't guaranteed.
FIELDS=$(python3 -c "
import json, sys
t = json.loads(sys.argv[1])
print(t.get('slack_message_ts') or '')
print(t.get('slack_message_url') or '')
print(t.get('title') or '')
print(t.get('assignee') or '')
print(t.get('product') or '')
print(t.get('category') or '')
" "$TASK_JSON")

SLACK_TS=$(echo "$FIELDS" | sed -n '1p')
SLACK_URL=$(echo "$FIELDS" | sed -n '2p')
TITLE=$(echo "$FIELDS" | sed -n '3p')
ASSIGNEE=$(echo "$FIELDS" | sed -n '4p')
PRODUCT=$(echo "$FIELDS" | sed -n '5p')
CATEGORY=$(echo "$FIELDS" | sed -n '6p')

if [ -z "$SLACK_TS" ]; then
  echo "ERROR: task #$TASK_ID has no slack_message_ts — was it created without --notify?" >&2
  echo "       Nothing to reply under. Re-issue the task with --notify, or ask the assignee directly." >&2
  exit 1
fi

# Derive channel ID from the task's slack_message_url (…/archives/<CHANNEL>/p…).
CHANNEL=$(echo "$SLACK_URL" | sed -nE 's|.*/archives/([^/]+)/.*|\1|p')
[ -n "$CHANNEL" ] || CHANNEL="C0ASK9520JG"   # fallback to #tasks default

# ─── 2. Build assistance content ───
BODY_JSON=$(python3 "$GEN_PY" "$TASK_ID" --json 2>/dev/null || echo '{"ok":false,"text":"","metadata":{},"reason":"gen-task-assistance.py failed"}')
BODY_TEXT=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('text',''))" "$BODY_JSON")
BODY_REASON=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('reason',''))" "$BODY_JSON")

# Compose the final message. Always prefix with a bot header so the reply is
# obviously bot-generated (assignee shouldn't confuse it with a human hint).
if [ -n "$BODY_TEXT" ]; then
  MESSAGE=$(printf ':robot_face: *Task-Assistance-Bot* — for T%s\n\n%s\n\n_%s · %s_' \
    "$TASK_ID" "$BODY_TEXT" "${PRODUCT:-no product}" "${CATEGORY:-adhoc}")
else
  MESSAGE=$(printf ':robot_face: *Task-Assistance-Bot* — for T%s\n\nNo pre-computed assistance available.\n_Reason: %s_' \
    "$TASK_ID" "${BODY_REASON:-unknown}")
fi

# ─── 3. Post as thread reply ───
if [ "$DRY_RUN" -eq 1 ]; then
  echo "=== DRY-RUN: would post to channel=$CHANNEL thread_ts=$SLACK_TS ==="
  echo ""
  echo "$MESSAGE"
  echo ""
  echo "=== metadata that would be stashed ==="
  python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1]).get('metadata',{}), indent=2))" "$BODY_JSON"
  exit 0
fi

REPLY_RAW=$("$SLACK_POST" "$CHANNEL" "$SLACK_TS" "$MESSAGE" 2>&1) || {
  echo "ERROR: slack-post failed" >&2
  echo "$REPLY_RAW" >&2
  exit 2
}
REPLY_TS="${REPLY_RAW#OK ts=}"

# ─── 4. Stash metadata on the task row ───
# We use json_patch to merge with any existing metadata (recon cache pointers,
# marketing-morning template info, etc.). If the row's metadata is NULL,
# json_patch replaces it with our block.
META_JSON=$(python3 -c "
import json, sys
m = json.loads(sys.argv[1]).get('metadata', {})
m['assist_posted_ts'] = '$REPLY_TS'
m['assist_channel'] = '$CHANNEL'
print(json.dumps(m))
" "$BODY_JSON")

META_ESC="${META_JSON//\'/''}"
db_exec "UPDATE tasks
         SET metadata = COALESCE(
               json_patch(COALESCE(metadata, '{}'), '$META_ESC'),
               '$META_ESC'
             ),
             updated_at = datetime('now')
         WHERE id = $TASK_ID;" 2>/dev/null || true

if [ -n "$BODY_TEXT" ]; then
  echo "OK · assistance posted for T$TASK_ID · thread_ts=$REPLY_TS"
else
  echo "OK · 'no assistance' note posted for T$TASK_ID · thread_ts=$REPLY_TS · reason: $BODY_REASON"
fi
