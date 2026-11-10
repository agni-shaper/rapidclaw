#!/bin/zsh
# daily-tasks.sh — Mon–Fri 06:00 IST: live recon → post the daily distribution
# tasks (+ Task-Assistance-Bot threads) to #rn-coach-social.
# Replaces the old marketing-recon (06:00) + marketing-morning (07:00) pair.
# Skips weekends + team holidays via guard_working_day.
source "${0:A:h}/_lib.sh"
guard_working_day daily-tasks

LOG="/tmp/${BOT_SLUG}-daily-tasks.log"
cd "$PROJECT_DIR" || exit 1
{
  echo
  echo "=== $(date -Iseconds) daily-tasks fire ==="
  python3 accountability/routines/daily-tasks-recon.py
  echo "--- recon exit $? ---"
  python3 accountability/routines/daily-tasks-post.py
  RC=$?
  echo "=== post exit $RC at $(date -Iseconds) ==="
  if [ "$RC" -ne 0 ]; then
    printf '%s\n' ":warning: daily-tasks failed (exit $RC) — see $LOG" \
      | accountability/routines/slack-post.sh "${SLACK_CHANNEL_ID}" >/dev/null 2>&1
  fi
} >> "$LOG" 2>&1
