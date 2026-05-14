#!/bin/zsh
# launchd/install.sh — copy all plists for this bot into ~/Library/LaunchAgents
# and load them. Re-runnable.
#
# Usage:
#   ./install.sh             — copy + load all plists for this bot
#   ./install.sh --uninstall — unload + remove from ~/Library/LaunchAgents
#
# bot-init.sh's substitution step already renamed plists to com.<owner>.<slug>-*.plist
# (no __PLACEHOLDER__ markers in filenames anymore).

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/LaunchAgents"
mkdir -p "$DEST"

if [ "${1:-}" = "--uninstall" ]; then
  for plist in "$DIR"/com.*-*.plist; do
    [ -f "$plist" ] || continue
    name=$(basename "$plist")
    if [ -f "$DEST/$name" ]; then
      launchctl unload "$DEST/$name" 2>/dev/null || true
      rm -f "$DEST/$name"
      echo "removed: $name"
    fi
  done
  exit 0
fi

# Sanity check — refuse to install if templates still contain placeholders.
if grep -qE '__[A-Z_][A-Z0-9_]*__' "$DIR"/com.*-*.plist 2>/dev/null; then
  echo "ERROR: launchd plists still contain __PLACEHOLDER__ markers — run bot-init.sh first." >&2
  exit 1
fi

count=0
for plist in "$DIR"/com.*-*.plist; do
  [ -f "$plist" ] || continue
  name=$(basename "$plist")
  /bin/cp -f "$plist" "$DEST/$name"
  launchctl unload "$DEST/$name" 2>/dev/null || true
  launchctl load -w "$DEST/$name"
  echo "installed: $name"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "WARN: no com.*-*.plist files found in $DIR — did you run bot-init.sh?" >&2
  exit 1
fi

echo
echo "Verify:"
echo "  launchctl list | grep com\\."
