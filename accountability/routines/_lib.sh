#!/bin/zsh
# _lib.sh — shared helpers sourced by all routine scripts.
# Loads .env from PROJECT_DIR (which is the parent of accountability/), exposes
# slug-aware token file paths.

# Find PROJECT_DIR by walking up from this file
_LIB_DIR="${(%):-%x:h}"
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
