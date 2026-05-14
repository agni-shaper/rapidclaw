#!/bin/zsh
# Wrapper for cron-fired routines. Loaded by launchd plists.
# Usage: run.sh <routine-name>   (e.g. daily, noon, friday, sunday, engagement)

ROUTINE="${1:?usage: run.sh <routine-name>}"

source "${0:A:h}/_lib.sh"

PROMPT="$PROJECT_DIR/accountability/routines/$ROUTINE.md"
LOG="/tmp/${BOT_SLUG}-${ROUTINE}.log"

# Gated behind USE_OPENROUTER=1 in .env. Default off — claude CLI uses the
# owner's Anthropic subscription auth. Flip the flag if Anthropic disables
# subscription-based automation usage of claude -p.
if [ "${USE_OPENROUTER:-}" = "1" ] && [ -n "${OPENROUTER_API_KEY:-}" ]; then
  export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://openrouter.ai/api}"
  export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
  ROUTINE_UPPER=$(echo "$ROUTINE" | tr '[:lower:]' '[:upper:]')
  PER_ROUTINE_VAR="${ROUTINE_UPPER}_MODEL"
  export ANTHROPIC_MODEL="${(P)PER_ROUTINE_VAR:-${ROUTINE_MODEL:-anthropic/claude-haiku-4-5}}"
fi

CLAUDE_PATH="$(command -v claude || echo "$HOME/.local/bin/claude")"

{
  echo
  echo "=== $(date -Iseconds) $ROUTINE fire ==="
  echo "  slug=$BOT_SLUG"
  echo "  model=${ANTHROPIC_MODEL:-default-anthropic}"
  if [ ! -f "$PROMPT" ]; then
    echo "ERROR: prompt file not found at $PROMPT"; exit 1
  fi
  cd "$PROJECT_DIR" || { echo "ERROR: cd failed"; exit 1; }
  {
    echo "Current date: $(date -I) ($(date '+%A')). Current time: $(date '+%H:%M %Z'). Anchor reasoning to this — do not assume time has elapsed since files were created; check file mtimes if needed."
    echo
    cat "$PROMPT"
  } | "$CLAUDE_PATH" \
    -p \
    --dangerously-skip-permissions \
    --add-dir "$PROJECT_DIR"
  echo "=== exit $? at $(date -Iseconds) ==="
} >> "$LOG" 2>&1
