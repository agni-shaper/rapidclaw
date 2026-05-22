#!/bin/zsh
# sites-prepare.sh — prepare a per-thread git worktree of a linked site so
# this thread's edits don't collide with other Slack threads or cron routines
# working on the same site repo.
#
# What it does:
#   1. Resolves $PROJECT_DIR/sites/<name> to find the real underlying repo.
#   2. Creates ~/rapidclaw-site-worktrees/<safe_ts>/<name>/ as a worktree of
#      that real repo on branch thread/<safe_ts>.
#   3. Replaces this thread's sites/<name> symlink to point at the new
#      per-thread worktree (so `cd sites/<name>` lands in the isolated copy).
#   4. Prints the worktree path on stdout.
#
# Idempotent: if a per-thread worktree already exists for this thread+site,
# just re-points the symlink and exits.
#
# Pointer .md files (sites/<name>.md instead of a symlink) are NOT supported
# here — those entries are copied verbatim into the worktree and the bot
# follows the pointer's documented workflow without a per-thread worktree.
#
# Usage:
#   sites-prepare.sh <site-name>
#
# Requires (set by listener.js when spawning claude inside a worktree):
#   SLACK_THREAD_TS       — Slack thread_ts driving this session
#   SLACK_THREAD_WORKDIR  — the per-thread bot worktree path

set -e
source "${0:A:h}/_lib.sh"

SITE="${1:?usage: sites-prepare.sh <site-name>}"
: "${SLACK_THREAD_TS:?SLACK_THREAD_TS not set — sites-prepare.sh must run inside a bot-spawned claude session}"
: "${SLACK_THREAD_WORKDIR:?SLACK_THREAD_WORKDIR not set — sites-prepare.sh must run inside a bot-spawned claude session}"

SAFE_TS="${SLACK_THREAD_TS//./_}"
SITE_WT_ROOT="$HOME/rapidclaw-site-worktrees"
PER_THREAD_DIR="$SITE_WT_ROOT/$SAFE_TS"
PER_THREAD_WT="$PER_THREAD_DIR/$SITE"
BRANCH="thread/$SAFE_TS"

# Find the real repo via main project's sites/<name> symlink (not the
# thread's, which we're about to rewrite).
MAIN_SITE_LINK="$PROJECT_DIR/sites/$SITE"
if [ ! -L "$MAIN_SITE_LINK" ]; then
  if [ -f "$PROJECT_DIR/sites/$SITE.md" ]; then
    echo "ERROR: sites/$SITE is a pointer .md file, not a symlink. Read its instructions instead of using sites-prepare.sh." >&2
    exit 2
  fi
  echo "ERROR: $MAIN_SITE_LINK is not a symlink and there's no sites/$SITE.md pointer either." >&2
  exit 1
fi
REAL_REPO="$(/usr/bin/readlink "$MAIN_SITE_LINK")"
# Resolve relative symlinks to absolute
case "$REAL_REPO" in
  /*) ;;
  *) REAL_REPO="$(cd "$PROJECT_DIR/sites" && cd "$(dirname "$REAL_REPO")" && pwd)/$(basename "$REAL_REPO")" ;;
esac

if [ ! -d "$REAL_REPO/.git" ]; then
  echo "ERROR: $REAL_REPO is not a git repo (no .git/). Cannot create per-thread worktree." >&2
  exit 3
fi

# If already prepared for this thread, just ensure the thread's symlink points right.
if [ -d "$PER_THREAD_WT" ]; then
  rm -f "$SLACK_THREAD_WORKDIR/sites/$SITE"
  ln -sfn "$PER_THREAD_WT" "$SLACK_THREAD_WORKDIR/sites/$SITE"
  echo "$PER_THREAD_WT"
  exit 0
fi

mkdir -p "$PER_THREAD_DIR"

# Try to create on a new branch off HEAD. If that branch already exists
# (e.g., from a previously-pruned thread reusing the same ts), attach to it.
if ! git -C "$REAL_REPO" worktree add -b "$BRANCH" "$PER_THREAD_WT" HEAD 2>/dev/null; then
  if ! git -C "$REAL_REPO" worktree add "$PER_THREAD_WT" "$BRANCH" 2>/dev/null; then
    echo "ERROR: git worktree add failed for $REAL_REPO at $PER_THREAD_WT" >&2
    rm -rf "$PER_THREAD_WT"
    exit 4
  fi
fi

# Swap this thread's sites/<name> symlink from the shared real repo to the
# per-thread worktree. Use ln -sfn to atomically replace.
rm -f "$SLACK_THREAD_WORKDIR/sites/$SITE"
ln -sfn "$PER_THREAD_WT" "$SLACK_THREAD_WORKDIR/sites/$SITE"

echo "$PER_THREAD_WT"
