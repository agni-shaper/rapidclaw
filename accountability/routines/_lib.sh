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
