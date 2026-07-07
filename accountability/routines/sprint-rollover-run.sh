#!/usr/bin/env bash
# sprint-rollover-run.sh — daily cron wrapper for sprint-rollover.
# Fired by ~/Library/LaunchAgents/com.agni.rapidnative-coach-sprint-rollover.plist
# at 06:30 IST every Monday.
#
# Reads sprint.md, appends this week's Mon–Fri sections (from the standard
# rotation template at the bottom of that file) if they're not already there.
# Idempotent — running twice is a no-op.
#
# The delegate script is a pure Python program (accountability/routines/sprint-rollover.py)
# because the task is entirely mechanical. This wrapper only handles logging + env.

set -euo pipefail

RAPIDCLAW_DIR="/Users/agni/Documents/rapidclaw"
LOG="/tmp/rapidnative-coach-sprint-rollover.log"

{
  printf '\n=== %s sprint-rollover fire ===\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"

  if [[ -f "$RAPIDCLAW_DIR/.env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source "$RAPIDCLAW_DIR/.env"
    set +o allexport
  fi

  cd "$RAPIDCLAW_DIR"
  /usr/bin/python3 accountability/routines/sprint-rollover.py
  RC=$?

  if [[ "$RC" -eq 0 ]]; then
    echo "OK sprint-rollover.py exited 0"
  else
    echo "ERROR sprint-rollover.py exited $RC" >&2
  fi
  printf '=== exit %s at %s ===\n' "$RC" "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  exit "$RC"
} >> "$LOG" 2>&1
