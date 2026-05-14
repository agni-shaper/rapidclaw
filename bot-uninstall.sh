#!/bin/zsh
# bot-uninstall.sh — deprovision a rapidclaw bot.
#
# Modes (escalating):
#   bot-uninstall.sh              stop launchd agents, unload + delete plists,
#                                 kill any active claude -p children.
#                                 State files (tokens, sessions, events) preserved.
#                                 Project dir preserved.
#   bot-uninstall.sh --purge      above + delete ~/.config/claude/<slug>-* (tokens,
#                                 processed log, thread sessions, inflight, events log)
#                                 and /tmp/<slug>-*.log files.
#   bot-uninstall.sh --nuke       above + offer to delete claude's per-project memory
#                                 dir and the project directory itself.
#
# Re-runnable / idempotent at every level. Safe to interrupt and resume.

set -e
emulate -L zsh
# Globs that match nothing should expand to empty (default zsh errors).
setopt NULL_GLOB

PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"

# Load .env to get BOT_SLUG, OWNER (written by bot-init.sh).
if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo "ERROR: no .env at $PROJECT_DIR/.env — was bot-init.sh ever run here?" >&2
  exit 1
fi
set -a; source "$PROJECT_DIR/.env"; set +a
: "${BOT_SLUG:?BOT_SLUG missing from .env}"
: "${OWNER:?OWNER missing from .env}"

MODE="basic"
case "${1:-}" in
  --purge) MODE="purge" ;;
  --nuke)  MODE="nuke" ;;
  --help|-h)
    grep '^#' "$0" | head -25
    exit 0 ;;
  "") ;;
  *) echo "ERROR: unknown flag '$1' (use --purge, --nuke, or --help)" >&2; exit 1 ;;
esac

# ---------- UI helpers ----------
readonly BOLD="\033[1m" DIM="\033[2m" RESET="\033[0m"
readonly GREEN="\033[32m" YELLOW="\033[33m" RED="\033[31m"
ok() { print -P "${GREEN}✓${RESET} $1"; }
note() { print -P "${DIM}$1${RESET}"; }
warn() { print -P "${YELLOW}⚠${RESET}  $1"; }

confirm() {
  local q="$1"
  local default="${2:-n}"
  local prompt_str="[y/N]"; [[ "$default" == "y" ]] && prompt_str="[Y/n]"
  print -nP "  ${BOLD}$q${RESET} ${DIM}$prompt_str${RESET}: "
  local ans
  read -r ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy] ]]
}

# ---------- Headline + confirmation ----------
print -P ""
print -P "${RED}╔═════════════════════════════════════════════════════════════════╗${RESET}"
print -P "${RED}║${RESET}  ${BOLD}rapidclaw uninstall${RESET}                                            ${RED}║${RESET}"
print -P "${RED}╚═════════════════════════════════════════════════════════════════╝${RESET}"
print ""
print -P "  Bot slug: ${BOLD}$BOT_SLUG${RESET}"
print -P "  Project:  $PROJECT_DIR"
print -P "  Mode:     ${BOLD}$MODE${RESET}"
print ""

case "$MODE" in
  basic) print "  Will: stop launchd agents, unload + delete plists, kill claude -p children." ;;
  purge) print "  Will: stop agents + delete tokens/state at ~/.config/claude/${BOT_SLUG}-* and /tmp/${BOT_SLUG}-*." ;;
  nuke)  print "  Will: stop agents + purge state + offer to delete claude memory dir + project dir." ;;
esac
print ""
confirm "Continue?" n || { echo "aborted"; exit 0; }

# ---------- Step 1: stop + unload launchd ----------
print ""
print -P "${BOLD}→ stopping + unloading launchd agents${RESET}"
DEST="$HOME/Library/LaunchAgents"
LAUNCHD_PREFIX="com.${OWNER}.${BOT_SLUG}"
unloaded=0
for plist in "$DEST/$LAUNCHD_PREFIX"-*.plist; do
  [ -f "$plist" ] || continue
  name=$(basename "$plist" .plist)
  launchctl bootout "gui/$UID/$name" 2>/dev/null || \
    launchctl unload "$plist" 2>/dev/null || true
  rm -f "$plist"
  ok "removed $name.plist"
  unloaded=$((unloaded + 1))
done
[ "$unloaded" -eq 0 ] && note "  (no launchd agents found — already uninstalled?)"

# ---------- Step 2: kill any active claude -p children for this bot ----------
print ""
print -P "${BOLD}→ killing any active claude -p children${RESET}"
INFLIGHT_FILE="$HOME/.config/claude/${BOT_SLUG}-inflight.json"
killed=0
if [ -f "$INFLIGHT_FILE" ]; then
  while read -r pid; do
    [ -n "$pid" ] && [ "$pid" != "null" ] && {
      kill -TERM "$pid" 2>/dev/null && ok "SIGTERM → pid $pid" && killed=$((killed + 1))
    }
  done < <(/usr/bin/python3 -c "
import json
try:
    data = json.load(open('$INFLIGHT_FILE'))
    for e in data: print(e.get('child_pid') or '')
except Exception: pass
")
fi
[ "$killed" -eq 0 ] && note "  (no inflight children — clean)"

if [ "$MODE" = "basic" ]; then
  print ""
  print -P "${GREEN}╔═════════════════════════════════════════════════════════════════╗${RESET}"
  print -P "${GREEN}║${RESET}  ${BOLD}Basic uninstall complete${RESET}                                        ${GREEN}║${RESET}"
  print -P "${GREEN}╚═════════════════════════════════════════════════════════════════╝${RESET}"
  print ""
  note "  State preserved at: ~/.config/claude/${BOT_SLUG}-*"
  note "  Project preserved at: $PROJECT_DIR"
  note "  To purge state too:  ./bot-uninstall.sh --purge"
  exit 0
fi

# ---------- Step 3: purge state files ----------
print ""
print -P "${BOLD}→ purging state files${RESET}"
removed=0
for f in \
  "$HOME/.config/claude/${BOT_SLUG}-slack-bot-token" \
  "$HOME/.config/claude/${BOT_SLUG}-slack-app-token" \
  "$HOME/.config/claude/${BOT_SLUG}-processed-ts.log" \
  "$HOME/.config/claude/${BOT_SLUG}-thread-sessions.json" \
  "$HOME/.config/claude/${BOT_SLUG}-inflight.json" \
  "$HOME/.config/claude/${BOT_SLUG}-events.jsonl"; do
  if [ -e "$f" ]; then
    rm -f "$f"
    ok "removed $f"
    removed=$((removed + 1))
  fi
done

# /tmp logs (slug-prefixed)
for f in /tmp/${BOT_SLUG}-*.log /tmp/${BOT_SLUG}-launchd-*.log; do
  if [ -e "$f" ]; then
    rm -f "$f"
    ok "removed $f"
    removed=$((removed + 1))
  fi
done

[ "$removed" -eq 0 ] && note "  (nothing to remove — already purged)"

if [ "$MODE" = "purge" ]; then
  print ""
  print -P "${GREEN}╔═════════════════════════════════════════════════════════════════╗${RESET}"
  print -P "${GREEN}║${RESET}  ${BOLD}Purge complete${RESET}                                                  ${GREEN}║${RESET}"
  print -P "${GREEN}╚═════════════════════════════════════════════════════════════════╝${RESET}"
  print ""
  note "  Project preserved at: $PROJECT_DIR"
  note "  To delete it too:    ./bot-uninstall.sh --nuke"
  print ""
  warn "  Heads up: the Slack bot itself (your sanket-coach-style Slack app) still exists in"
  warn "  api.slack.com/apps. If you don't want it anymore, delete it there manually."
  exit 0
fi

# ---------- Step 4 (nuke): offer to delete claude memory dir + project dir ----------
print ""
print -P "${BOLD}→ nuke mode${RESET}"

# Claude memory dirs are at ~/.claude/projects/<encoded-path>/memory/
# Encoding: project path with / → -, leading dash. Search anything containing slug.
print ""
note "  Searching for claude memory dirs that reference this project…"
MATCHES=()
if [ -d "$HOME/.claude/projects" ]; then
  for d in "$HOME/.claude/projects"/*; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
      *"$BOT_SLUG"*|*"${PROJECT_DIR//\//-}"*) MATCHES+=("$d") ;;
    esac
  done
fi

if [ ${#MATCHES[@]} -eq 0 ]; then
  note "  (no claude memory dir found for this bot)"
else
  print ""
  print -P "  Found ${BOLD}${#MATCHES[@]}${RESET} matching claude memory dir(s):"
  for d in "${MATCHES[@]}"; do print -P "    ${DIM}$d${RESET}"; done
  print ""
  if confirm "Delete these memory dirs?" n; then
    for d in "${MATCHES[@]}"; do
      rm -rf "$d"
      ok "removed $d"
    done
  fi
fi

print ""
if confirm "Delete the project directory $PROJECT_DIR?" n; then
  cd "$HOME"
  rm -rf "$PROJECT_DIR"
  ok "deleted $PROJECT_DIR"
  print ""
  print -P "${GREEN}✓ Nuke complete. Goodbye, ${BOLD}$BOT_SLUG${RESET}${GREEN}.${RESET}"
else
  note "  Project dir preserved. You can delete it manually: rm -rf $PROJECT_DIR"
fi

print ""
warn "  Heads up: the Slack bot itself (your $BOT_SLUG Slack app) still exists in"
warn "  api.slack.com/apps. If you don't want it anymore, delete it there manually."
