#!/bin/zsh
# tasker.sh — the coach's only door into tasker (tasks.rapidnative.com), the team's tracker.
#
#   accountability/routines/tasker.sh tools                    every tool, one line each
#   accountability/routines/tasker.sh tools create_item        one tool's input schema
#   accountability/routines/tasker.sh find_nodes '{"query":"stripe webhook"}'
#   echo '{"title":"…"}' | accountability/routines/tasker.sh create_item - --project RapidNative
#
# Every change shows in tasker's activity log as "Claude Code for Agni" (tasker member
# person-agni, agni@rapidnative.com), with notifications and undo, like a teammate's change.
# Needs TASKER_AGENT_TOKEN in .env (the team's shared agent token; ask Sanket).
# bin/tasker.mjs is a copy of rapidnative-dev-kit/claude/skills/tasker/tasker.mjs;
# refresh it from there when tasker's client changes.

source "${0:A:h}/_lib.sh"

: "${TASKER_AGENT_TOKEN:?TASKER_AGENT_TOKEN is not set in $PROJECT_DIR/.env (the team's shared tasker agent token)}"
export TASKER_AGENT_TOKEN

# tasker.mjs identifies the actor from git config; inject it per call so the bot acts as
# its own tasker member whatever the machine's or worktree's git identity is.
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=user.name    GIT_CONFIG_VALUE_0="${TASKER_NAME:-Agni}"
export GIT_CONFIG_KEY_1=tasker.email GIT_CONFIG_VALUE_1="${TASKER_EMAIL:-agni@rapidnative.com}"

NODE="$(command -v node || echo /opt/homebrew/bin/node)"
exec "$NODE" "$PROJECT_DIR/bin/tasker.mjs" "$@"
