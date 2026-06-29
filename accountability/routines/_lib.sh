#!/bin/zsh
# _lib.sh — shared helpers sourced by all routine scripts.
# Loads .env from PROJECT_DIR (which is the parent of accountability/), exposes
# slug-aware token file paths.

# Find PROJECT_DIR by walking up from this file.
# `${(%):-%x}` prompt-expands to this sourced file's path; outer `:h` strips
# the filename. The previous form `${(%):-%x:h}` treated `:h` as a literal
# suffix, leaving _LIB_DIR as `/path/_lib.sh:h` and PROJECT_DIR as `/`.
_LIB_DIR="${${(%):-%x}:h}"
PROJECT_DIR="${_LIB_DIR:h:h}"

# Load .env (gitignored, written by bot-init.sh)
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

# Required: BOT_SLUG must be set by .env
: "${BOT_SLUG:?BOT_SLUG must be set in $PROJECT_DIR/.env — run bot-init.sh}"

# Slug-aware token paths
BOT_TOKEN_FILE="$HOME/.config/claude/${BOT_SLUG}-slack-bot-token"
APP_TOKEN_FILE="$HOME/.config/claude/${BOT_SLUG}-slack-app-token"

# Helper: read the bot token (with cleanup of whitespace).
get_bot_token() {
  [ -f "$BOT_TOKEN_FILE" ] || { echo "ERROR: token file not found at $BOT_TOKEN_FILE" >&2; return 1; }
  tr -d '[:space:]' < "$BOT_TOKEN_FILE"
}

# Today's date in IST as YYYY-MM-DD. Override via TODAY_OVERRIDE for tests.
today_ist() {
  [ -n "$TODAY_OVERRIDE" ] && { echo "$TODAY_OVERRIDE"; return; }
  TZ=Asia/Kolkata date +%Y-%m-%d
}

# is_weekend [YYYY-MM-DD] — exit 0 if Sat/Sun (IST), else 1.
is_weekend() {
  local d="${1:-$(today_ist)}"
  local dow
  dow=$(TZ=Asia/Kolkata date -j -f "%Y-%m-%d" "$d" "+%u" 2>/dev/null) || return 1
  [ "$dow" = "6" ] || [ "$dow" = "7" ]
}

# is_holiday [YYYY-MM-DD] — exit 0 if listed under any section of accountability/holidays.md, else 1.
is_holiday() {
  local d="${1:-$(today_ist)}"
  local f="$PROJECT_DIR/accountability/holidays.md"
  [ -f "$f" ] || return 1
  grep -Eq "^- ${d} " "$f"
}

# is_working_day [YYYY-MM-DD] — exit 0 if weekday AND not a holiday, else 1.
is_working_day() {
  ! is_weekend "$@" && ! is_holiday "$@"
}

# is_on_leave <@SLACK_ID> [YYYY-MM-DD] — exit 0 if id is in leave.md *Active* covering the date.
# Accepts the id with or without `<@…>` / backticks.
is_on_leave() {
  local sid="$1"
  local d="${2:-$(today_ist)}"
  local f="$PROJECT_DIR/accountability/leave.md"
  [ -f "$f" ] || return 1
  sid="${sid//[\`<>@]/}"
  awk -v sid="$sid" -v today="$d" '
    /^## Active/ {active=1; next}
    /^## / && active {exit}
    active && index($0, sid) > 0 {
      if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2} to [0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
        range = substr($0, RSTART, RLENGTH)
        split(range, p, " to ")
        if (today >= p[1] && today <= p[2]) { found=1; exit }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$f"
}

# n_working_days_ago N — print YYYY-MM-DD (IST) that is N working days BEFORE today.
# A "working day" is a weekday (Mon–Fri) not listed in holidays.md. Today is NOT counted.
# e.g. if today is Tue and Mon is a holiday: `n_working_days_ago 2` = previous Thu.
n_working_days_ago() {
  local n="$1"
  local d; d=$(today_ist)
  local count=0
  while [ "$count" -lt "$n" ]; do
    d=$(TZ=Asia/Kolkata date -v-1d -j -f "%Y-%m-%d" "$d" "+%Y-%m-%d" 2>/dev/null) || return 1
    if ! is_weekend "$d" && ! is_holiday "$d"; then
      count=$((count + 1))
    fi
  done
  echo "$d"
}

# guard_working_day [routine-name] — call at the top of a routine script.
# If today isn't a working day (weekend or holiday), logs why and exits 0
# so launchd doesn't treat the skipped run as a failure.
guard_working_day() {
  local name="${1:-routine}"
  local today; today=$(today_ist)
  if is_weekend; then
    echo "[$(date '+%H:%M:%S')] $name: skipping — $today is a weekend (IST)" >&2
    exit 0
  fi
  if is_holiday; then
    local label
    label=$(grep -E "^- ${today} " "$PROJECT_DIR/accountability/holidays.md" | sed -E "s/^- ${today} · //")
    echo "[$(date '+%H:%M:%S')] $name: skipping — $today is a holiday: ${label:-listed in holidays.md}" >&2
    exit 0
  fi
}

# ---------------- Phase 0: definitions/ helpers ----------------
# Single-source-of-truth lookups against the registry files under
# definitions/. All helpers fail loudly if the registry file is missing —
# definitions/ is meant to be authoritative.

DEFINITIONS_DIR="$PROJECT_DIR/definitions"

# Column layout in definitions/people.md (awk -F'|' yields empty $1 due to leading |):
#   $2=Handle  $3=Name  $4=Role  $5=Kind  $6=SlackID  $7=Email  $8=Tier
# channels.md: $2=Channel  $3=ID  $4=Product  $5=Owner …

# lookup_handle <SLACK_ID> — print "@handle" for that ID, else nothing (exit 1).
lookup_handle() {
  local slack_id="${1:?usage: lookup_handle <SLACK_ID> (without <@>)}"
  slack_id="${slack_id#<@}"; slack_id="${slack_id%>}"
  [ -f "$DEFINITIONS_DIR/people.md" ] || { echo "ERROR: $DEFINITIONS_DIR/people.md not found" >&2; return 1; }
  awk -F'|' -v id="$slack_id" '/^\| `@/{
    gsub(/[ `]/, "", $2)
    gsub(/[ `]/, "", $6)
    if ($6 == id) { print $2; exit }
  }' "$DEFINITIONS_DIR/people.md"
}

# lookup_slack_id @handle — print slack ID, else nothing (exit 1).
lookup_slack_id() {
  local handle="${1:?usage: lookup_slack_id @handle}"
  handle="${handle#@}"
  [ -f "$DEFINITIONS_DIR/people.md" ] || { echo "ERROR: $DEFINITIONS_DIR/people.md not found" >&2; return 1; }
  awk -F'|' -v h="$handle" '/^\| `@/{
    gsub(/[ `@]/, "", $2)
    gsub(/[ `]/, "", $6)
    if ($2 == h) { print $6; exit }
  }' "$DEFINITIONS_DIR/people.md"
}

# product_for_channel <channel_id> — print product slug(s) for that channel.
product_for_channel() {
  local cid="${1:?usage: product_for_channel <channel_id>}"
  [ -f "$DEFINITIONS_DIR/channels.md" ] || { echo "ERROR: $DEFINITIONS_DIR/channels.md not found" >&2; return 1; }
  awk -F'|' -v id="$cid" '/^\| `#/{
    gsub(/[ `]/, "", $3)
    sub(/^ +/, "", $4); sub(/ +$/, "", $4)
    if ($3 == id) { print $4; exit }
  }' "$DEFINITIONS_DIR/channels.md"
}

# skill_path <skill_name> — print the absolute path to that skill's directory
# if it exists, by checking coach .claude/skills/ first then each site's.
skill_path() {
  local name="${1:?usage: skill_path <skill_name>}"
  for base in "$PROJECT_DIR/.claude/skills" "$PROJECT_DIR/sites/"*"/.claude/skills"; do
    if [ -d "$base/$name" ]; then
      echo "$base/$name"
      return 0
    fi
  done
  return 1
}

# ---------------- Phase 3: sqlite helpers ----------------
# DB: ~/.config/claude/${BOT_SLUG}.sqlite (created by bin/migrate-to-sqlite.py)
# These run ALONGSIDE the existing markdown-reading helpers (is_on_leave, is_holiday).
# Routines that still call the markdown helpers keep working unchanged.
# Skill-based code paths (Phase 2+) should prefer the sqlite_* variants below.

DB_PATH="$HOME/.config/claude/${BOT_SLUG}.sqlite"

# db_path — echo the absolute DB path (handy for one-liners).
db_path() { echo "$DB_PATH"; }

# db_query "SELECT …" — run a read query, print result rows (pipe-separated).
# Fails loudly if the DB doesn't exist (callers can fall back to .md if they want).
db_query() {
  [ -f "$DB_PATH" ] || { echo "ERROR: sqlite DB not found at $DB_PATH — run bin/migrate-to-sqlite.py" >&2; return 1; }
  sqlite3 "$DB_PATH" "$@"
}

# db_exec "INSERT …" — run a write query.
db_exec() {
  [ -f "$DB_PATH" ] || { echo "ERROR: sqlite DB not found at $DB_PATH — run bin/migrate-to-sqlite.py" >&2; return 1; }
  sqlite3 "$DB_PATH" "$@"
}

# sqlite_is_on_leave <SLACK_ID> [YYYY-MM-DD] — sqlite-backed version of is_on_leave.
# Same exit-code contract: 0 if covered, 1 otherwise.
sqlite_is_on_leave() {
  local sid="${1:?usage: sqlite_is_on_leave <SLACK_ID> [date]}"
  local d="${2:-$(today_ist)}"
  sid="${sid//[\`<>@]/}"
  local count
  count=$(db_query "SELECT COUNT(*) FROM leave_entries WHERE slack_id='$sid' AND status='active' AND '$d' BETWEEN start_date AND end_date;") || return 1
  [ "$count" != "0" ]
}

# sqlite_is_holiday [YYYY-MM-DD] — sqlite-backed version of is_holiday. Same contract.
sqlite_is_holiday() {
  local d="${1:-$(today_ist)}"
  local count
  count=$(db_query "SELECT COUNT(*) FROM holidays WHERE date='$d' AND status='upcoming';") || return 1
  [ "$count" != "0" ]
}

# log_routine_start <name> — print the new row ID (use it for log_routine_end).
log_routine_start() {
  local name="${1:?usage: log_routine_start <routine_name>}"
  local log_path="/tmp/${BOT_SLUG}-${name}.log"
  local ts; ts=$(date -Iseconds)
  db_exec "INSERT INTO routine_runs (routine, started_at, log_path) VALUES ('$name', '$ts', '$log_path'); SELECT last_insert_rowid();"
}

# log_routine_end <id> <exit_code> [notes] — close out a routine run row.
log_routine_end() {
  local id="${1:?usage: log_routine_end <run_id> <exit_code> [notes]}"
  local code="${2:?exit_code required}"
  local notes="${3:-}"
  local ts; ts=$(date -Iseconds)
  local notes_sql=""
  if [ -n "$notes" ]; then
    local esc="${notes//\'/\'\'}"
    notes_sql=", notes='$esc'"
  fi
  db_exec "UPDATE routine_runs SET ended_at='$ts', exit_code=$code$notes_sql WHERE id=$id;"
}

# last_run <routine> — print the last started_at ISO timestamp, or empty if never.
last_run() {
  local name="${1:?usage: last_run <routine_name>}"
  db_query "SELECT started_at FROM routine_runs WHERE routine='$name' ORDER BY started_at DESC LIMIT 1;"
}
