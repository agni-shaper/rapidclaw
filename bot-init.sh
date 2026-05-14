#!/bin/zsh
# bot-init.sh — interactive setup wizard for a rapidclaw bot.
#
# Run from the root of a freshly-cloned rapidclaw repo. Asks ~12 grouped
# questions, writes the bot's identity files, saves Slack tokens to
# ~/.config/claude/<slug>-slack-{bot,app}-token (mode 600), substitutes
# placeholders in all template files, optionally loads launchd + runs a
# smoke test.
#
# State is tracked in .bot-setup-state.json. Re-run any time to resume from
# the first incomplete step.

set -e
emulate -L zsh
setopt PIPE_FAIL

PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"

STATE_FILE="$PROJECT_DIR/.bot-setup-state.json"

# ---------- state helpers (python for safe JSON read/write) ----------

state_get() {
  /usr/bin/python3 - "$STATE_FILE" "$1" <<'PY'
import json, sys, os
path, key = sys.argv[1], sys.argv[2]
if not os.path.exists(path):
    print(""); sys.exit(0)
try:
    d = json.load(open(path))
except Exception:
    print(""); sys.exit(0)
# dotted: vars.SLUG or steps_completed.bot_slug
node = d
for part in key.split("."):
    if not isinstance(node, dict): node = ""; break
    node = node.get(part, "")
print(node if isinstance(node, str) else json.dumps(node))
PY
}

state_set() {
  /usr/bin/python3 - "$STATE_FILE" "$1" "$2" <<'PY'
import json, sys, os
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
d = {}
if os.path.exists(path):
    try: d = json.load(open(path))
    except Exception: d = {}
if not d.get("version"):
    d["version"] = 1
    from datetime import datetime, timezone
    d["started_at"] = datetime.now(timezone.utc).isoformat()
node = d
parts = key.split(".")
for p in parts[:-1]:
    node = node.setdefault(p, {})
node[parts[-1]] = val
open(path, "w").write(json.dumps(d, indent=2))
PY
}

mark_step_done() {
  local step="$1"
  local now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  state_set "steps_completed.$step" "$now"
}

is_step_done() {
  local step="$1"
  [[ -n "$(state_get "steps_completed.$step")" ]]
}

set_var() { state_set "vars.$1" "$2"; }
get_var() { state_get "vars.$1"; }

# ---------- UI helpers ----------

readonly RESET="\033[0m"
readonly BOLD="\033[1m"
readonly DIM="\033[2m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"
readonly RED="\033[31m"

banner() {
  print -P ""
  print -P "%F{green}┌─────────────────────────────────────────────────────────────────┐%f"
  print -P "%F{green}│%f  %B$1%b  %F{green}│%f"
  print -P "%F{green}└─────────────────────────────────────────────────────────────────┘%f"
}

note() { print -P "${DIM}$1${RESET}"; }
ok() { print -P "${GREEN}✓${RESET} $1"; }
warn() { print -P "${YELLOW}⚠${RESET}  $1"; }
fail() { print -P "${RED}✗${RESET} $1" >&2; }

# Read a single line with default and validation.
# Usage: prompt VAR_NAME "Question?" "default" [regex_validator]
prompt() {
  local var_name="$1" question="$2" default="$3" validator="${4:-.*}"
  local current="$(get_var "$var_name")"
  local prefilled="${current:-$default}"
  local input=""
  while true; do
    if [ -n "$prefilled" ]; then
      print -nP "  ${BOLD}$question${RESET} ${DIM}[$prefilled]${RESET}: "
    else
      print -nP "  ${BOLD}$question${RESET}: "
    fi
    read -r input
    input="${input:-$prefilled}"
    if [[ -z "$input" && -z "$prefilled" ]]; then
      fail "value required"
      continue
    fi
    if [[ "$input" =~ $validator ]]; then
      set_var "$var_name" "$input"
      return 0
    else
      fail "doesn't match expected format (regex: $validator)"
    fi
  done
}

# Read a secret (xoxb-, xapp-, etc.) without echo, save to a file at mode 600.
# Usage: prompt_secret_to_file VAR_NAME "Question?" /path/to/file [prefix_required]
prompt_secret_to_file() {
  local var_name="$1" question="$2" path="$3" required_prefix="${4:-}"
  if [ -f "$path" ]; then
    note "  (already saved at $path — skipping)"
    set_var "$var_name" "saved"
    return 0
  fi
  local input=""
  while true; do
    print -nP "  ${BOLD}$question${RESET} ${DIM}(input hidden)${RESET}: "
    read -rs input
    print ""
    if [ -z "$input" ]; then fail "value required"; continue; fi
    if [ -n "$required_prefix" ] && [[ "$input" != "$required_prefix"* ]]; then
      fail "token must start with '$required_prefix'"
      continue
    fi
    mkdir -p "${path:h}"
    chmod 700 "${path:h}"
    print -n "$input" > "$path"
    chmod 600 "$path"
    set_var "$var_name" "saved"
    ok "saved to $path (mode 600)"
    return 0
  done
}

# Prompt for an optional multi-line block, end with a single line "." or EOF.
prompt_block() {
  local var_name="$1" question="$2"
  local current="$(get_var "$var_name")"
  print -P "  ${BOLD}$question${RESET}"
  print -P "  ${DIM}(end with a single '.' on its own line, or Ctrl-D)${RESET}"
  if [ -n "$current" ]; then
    note "  Current value (press Enter to keep):"
    print -P "  ${DIM}$(print "$current" | sed 's/^/  > /')${RESET}"
    print -nP "  ${BOLD}Replace?${RESET} ${DIM}[N/y]${RESET}: "
    local repl
    read -r repl
    if [[ ! "$repl" =~ ^[Yy] ]]; then return 0; fi
  fi
  local lines=()
  while IFS= read -r line; do
    [[ "$line" == "." ]] && break
    lines+=("$line")
  done
  local joined="${(F)lines}"
  set_var "$var_name" "$joined"
}

yes_no() {
  local question="$1" default="${2:-y}"
  local prompt_str="[Y/n]"
  [[ "$default" == "n" ]] && prompt_str="[y/N]"
  print -nP "  ${BOLD}$question${RESET} ${DIM}$prompt_str${RESET}: "
  local ans
  read -r ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy] ]]
}

# ---------- Steps ----------

step_bot_slug() {
  banner "Step 1/12  ·  Bot slug"
  note "  Used in launchd labels (com.<owner>.<slug>-listener), sqlite filenames,"
  note "  log paths. Must be lowercase, dash-separated, ≤32 chars."
  prompt SLUG "Bot slug" "" '^[a-z][a-z0-9-]{0,31}$'
  mark_step_done bot_slug
}

step_owner() {
  banner "Step 2/12  ·  Owner"
  prompt OWNER "macOS user account name" "$USER" '^[a-z][a-z0-9_-]*$'
  prompt OWNER_EMAIL "Email" "" '^.+@.+\..+$'
  mark_step_done owner
}

step_slack_basics() {
  banner "Step 3/12  ·  Slack workspace + channel"
  note "  Where the bot lives. The channel ID (Cxxx) is in the channel's URL:"
  note "  app.slack.com/client/<team>/<channel-id>"
  prompt SLACK_WORKSPACE "Workspace subdomain (e.g. acme-co)" "" '^[a-z0-9-]+$'
  prompt SLACK_CHANNEL_ID "Channel ID (Cxxxxxxxx)" "" '^C[A-Z0-9]+$'
  prompt SLACK_CHANNEL_NAME "Channel name (for log readability)" "sanket-coach" '^[a-z0-9-]+$'
  prompt SLACK_USER_ID "Your Slack user ID (Uxxx; only you trigger the bot)" "" '^U[A-Z0-9]+$'
  prompt BOT_USER_ID "Bot's Slack user ID (Uxxx; listener ignores its own posts)" "" '^U[A-Z0-9]+$'
  mark_step_done slack_basics
}

step_slack_tokens() {
  banner "Step 4/12  ·  Slack bot + app tokens"
  note "  Slack app dashboard → Install App for bot token (xoxb-),"
  note "  Basic Information → App-Level Tokens for app token (xapp-, with connections:write scope)."
  local SLUG="$(get_var SLUG)"
  prompt_secret_to_file SLACK_BOT_TOKEN "Slack bot token (xoxb-)" "$HOME/.config/claude/${SLUG}-slack-bot-token" "xoxb-"
  prompt_secret_to_file SLACK_APP_TOKEN "Slack app token (xapp-)" "$HOME/.config/claude/${SLUG}-slack-app-token" "xapp-"
  mark_step_done slack_tokens
}

step_openrouter() {
  banner "Step 5/12  ·  OpenRouter (optional)"
  note "  Leave blank to use claude -p on your Anthropic subscription (default)."
  note "  Set when Anthropic disables subscription -p automation, or to use"
  note "  cheaper / open-source models per route."
  local current="$(get_var OPENROUTER_API_KEY)"
  print -nP "  ${BOLD}OpenRouter API key${RESET} ${DIM}(blank to skip${current:+; current=<set>})${RESET}: "
  local key
  read -rs key
  print ""
  if [ -n "$key" ]; then
    set_var OPENROUTER_API_KEY "$key"
    if yes_no "Enable OpenRouter routing now? (otherwise default subscription)"; then
      set_var USE_OPENROUTER "1"
    else
      set_var USE_OPENROUTER ""
    fi
  fi
  mark_step_done openrouter
}

step_chrome_profiles() {
  banner "Step 6/12  ·  Chrome profile mapping"
  note "  Which Chrome profile is signed in to each social platform. Used by"
  note "  browser-use scans. 'Default' is your personal Chrome profile."
  note "  Find profile names in: ~/Library/Application Support/Google/Chrome/Local State"
  prompt CHROME_PROFILE_X "Chrome profile for X" "Default" '.*'
  prompt CHROME_PROFILE_LINKEDIN "Chrome profile for LinkedIn" "Default" '.*'
  prompt CHROME_PROFILE_INSTAGRAM "Chrome profile for Instagram" "Default" '.*'
  prompt CHROME_PROFILE_GITHUB "Chrome profile for GitHub" "Default" '.*'
  prompt CHROME_PROFILE_REDDIT "Chrome profile for Reddit" "Default" '.*'
  mark_step_done chrome_profiles
}

step_identity() {
  banner "Step 7/12  ·  Bot identity (goal, voice, pillars)"
  note "  These get written into profile.md and referenced by routines + listener."
  print ""
  prompt GOAL "Top-level goal (1-2 sentences — what is this bot for?)" "" '.{8,}'
  print ""
  prompt_block VOICE_RULES "Voice rules (multi-line — em dashes? hashtags? case style? specific phrases to avoid?)"
  print ""
  prompt PILLARS "Topic pillars (comma-separated, 1-5)" "" '.+'
  mark_step_done identity
}

step_cron_times() {
  banner "Step 8/12  ·  Cron schedule"
  note "  All times in 24h local time."
  prompt CRON_DAILY "Morning routine (daily) — HH:MM" "10:30" '^[0-9]{1,2}:[0-9]{2}$'
  prompt CRON_NOON "Noon check-in — HH:MM" "12:00" '^[0-9]{1,2}:[0-9]{2}$'
  prompt CRON_FRIDAY "Friday build-in-public — HH:MM" "17:00" '^[0-9]{1,2}:[0-9]{2}$'
  prompt CRON_SUNDAY "Sunday weekly review — HH:MM" "12:00" '^[0-9]{1,2}:[0-9]{2}$'
  prompt CRON_ENGAGEMENT_1 "Engagement scan #1 — HH:MM" "11:30" '^[0-9]{1,2}:[0-9]{2}$'
  prompt CRON_ENGAGEMENT_2 "Engagement scan #2 — HH:MM" "14:30" '^[0-9]{1,2}:[0-9]{2}$'
  prompt CRON_ENGAGEMENT_3 "Engagement scan #3 — HH:MM" "18:00" '^[0-9]{1,2}:[0-9]{2}$'
  mark_step_done cron_times
}

step_substitutions() {
  banner "Step 9/12  ·  Substitute placeholders into template files"
  local SLUG="$(get_var SLUG)"
  local OWNER="$(get_var OWNER)"
  local OWNER_EMAIL="$(get_var OWNER_EMAIL)"
  local SLACK_WORKSPACE="$(get_var SLACK_WORKSPACE)"
  local SLACK_CHANNEL_ID="$(get_var SLACK_CHANNEL_ID)"
  local SLACK_CHANNEL_NAME="$(get_var SLACK_CHANNEL_NAME)"
  local SLACK_USER_ID="$(get_var SLACK_USER_ID)"
  local BOT_USER_ID="$(get_var BOT_USER_ID)"
  local NODE_BIN="$(dirname "$(which node)" 2>/dev/null)"
  local CLAUDE_PATH="$(which claude 2>/dev/null || print "$HOME/.local/bin/claude")"

  # Write .env from the wizard answers
  print "→ writing .env"
  /usr/bin/python3 - "$STATE_FILE" "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env" <<'PY'
import json, sys, os
state_path, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
state = json.load(open(state_path))
vars_ = state.get("vars", {})
text = open(src).read()
# Substitute __KEY__ markers in .env.example with vars_[KEY]
import re
def repl(m):
    return vars_.get(m.group(1), m.group(0))
text = re.sub(r"__([A-Z_][A-Z0-9_]*)__", repl, text)
open(dst, "w").write(text)
os.chmod(dst, 0o600)
PY
  # Append OPENROUTER_API_KEY / USE_OPENROUTER if captured (they're not in .env.example default fields)
  if [ -n "$(get_var OPENROUTER_API_KEY)" ]; then
    print "OPENROUTER_API_KEY=$(get_var OPENROUTER_API_KEY)" >> "$PROJECT_DIR/.env"
  fi
  if [ -n "$(get_var USE_OPENROUTER)" ]; then
    print "USE_OPENROUTER=$(get_var USE_OPENROUTER)" >> "$PROJECT_DIR/.env"
  fi
  ok ".env written (mode 600)"

  # Substitute placeholders in all template files
  print "→ substituting placeholders in template files"
  local sed_args=(
    -e "s|__SLUG__|$SLUG|g"
    -e "s|__OWNER__|$OWNER|g"
    -e "s|__OWNER_EMAIL__|$OWNER_EMAIL|g"
    -e "s|__SLACK_WORKSPACE__|$SLACK_WORKSPACE|g"
    -e "s|__SLACK_CHANNEL_ID__|$SLACK_CHANNEL_ID|g"
    -e "s|__SLACK_CHANNEL_NAME__|$SLACK_CHANNEL_NAME|g"
    -e "s|__SLACK_USER_ID__|$SLACK_USER_ID|g"
    -e "s|__BOT_USER_ID__|$BOT_USER_ID|g"
    -e "s|__PROJECT_DIR__|$PROJECT_DIR|g"
    -e "s|__HOME__|$HOME|g"
    -e "s|__NODE_BIN__|$NODE_BIN|g"
    -e "s|__CLAUDE_PATH__|$CLAUDE_PATH|g"
  )

  # cron time placeholders: substitute both the full HH:MM (used in markdown
  # docs) and the split HH / MIN parts (used in launchd plist integers).
  for k in CRON_DAILY CRON_NOON CRON_FRIDAY CRON_SUNDAY CRON_ENGAGEMENT_1 CRON_ENGAGEMENT_2 CRON_ENGAGEMENT_3; do
    local v="$(get_var $k)"
    local hh="${v%:*}"
    local mm="${v#*:}"
    sed_args+=(
      -e "s|__${k}__|$v|g"
      -e "s|__${k}_HOUR__|$hh|g"
      -e "s|__${k}_MIN__|$mm|g"
    )
  done

  # Find every file that contains a placeholder (any __XXX__) and substitute in place
  local count=0
  while IFS= read -r f; do
    /usr/bin/sed -i.bak "${sed_args[@]}" "$f"
    rm -f "$f.bak"
    count=$((count + 1))
  done < <(grep -rlE '__[A-Z_][A-Z0-9_]*__' "$PROJECT_DIR" 2>/dev/null \
            | grep -v -E '/(node_modules|\.git|\.bak|\.env\.example|README\.md)$' \
            | grep -v '/\.bot-setup-state\.json$' \
            | grep -v -E '/(AGENTS|bot-init)\.sh?$')
  ok "substituted $count file(s)"

  # Rename launchd plists to bake in slug + owner
  print "→ renaming launchd plists with slug + owner"
  for src in "$PROJECT_DIR"/launchd/*-listener.plist "$PROJECT_DIR"/launchd/*-daily.plist \
             "$PROJECT_DIR"/launchd/*-noon.plist "$PROJECT_DIR"/launchd/*-friday.plist \
             "$PROJECT_DIR"/launchd/*-sunday.plist "$PROJECT_DIR"/launchd/*-engagement.plist; do
    [ -f "$src" ] || continue
    local base="${src:t:r}"
    # If the filename already contains the slug, skip
    if [[ "$base" == "com.$OWNER.$SLUG-"* ]]; then continue; fi
    # Convert e.g. "rapidclaw-listener" -> "com.<owner>.<slug>-listener"
    local routine="${base#*-}"
    local newname="com.$OWNER.$SLUG-$routine.plist"
    mv "$src" "$PROJECT_DIR/launchd/$newname"
  done
  ok "launchd plists renamed"

  # Write profile.md from goal + voice + pillars
  print "→ writing profile.md from your identity answers"
  /usr/bin/python3 - "$STATE_FILE" "$PROJECT_DIR/profile.md" <<'PY'
import json, sys
state = json.load(open(sys.argv[1]))
v = state.get("vars", {})
content = f"""# {v.get("SLUG","bot")} — profile

## Identity
- **Slug:** `{v.get("SLUG","")}`
- **Owner:** {v.get("OWNER","")}
- **Email:** {v.get("OWNER_EMAIL","")}
- **Slack:** #{v.get("SLACK_CHANNEL_NAME","")} in {v.get("SLACK_WORKSPACE","")}.slack.com

## Top-level goal
{v.get("GOAL","")}

## Topic pillars
""" + "\n".join(f"- {p.strip()}" for p in v.get("PILLARS","").split(",") if p.strip()) + f"""

## Voice rules
{v.get("VOICE_RULES","(no voice rules captured)")}

## Chrome profile mapping
| Platform | Chrome profile |
|---|---|
| X | `{v.get("CHROME_PROFILE_X","Default")}` |
| LinkedIn | `{v.get("CHROME_PROFILE_LINKEDIN","Default")}` |
| Instagram | `{v.get("CHROME_PROFILE_INSTAGRAM","Default")}` |
| GitHub | `{v.get("CHROME_PROFILE_GITHUB","Default")}` |
| Reddit | `{v.get("CHROME_PROFILE_REDDIT","Default")}` |
"""
open(sys.argv[2], "w").write(content)
PY
  ok "profile.md written"

  mark_step_done substitutions
}

step_deps() {
  banner "Step 10/12  ·  Install listener npm deps"
  if [ -d "$PROJECT_DIR/accountability/listener/node_modules" ]; then
    note "  node_modules already present — skipping"
  else
    (cd "$PROJECT_DIR/accountability/listener" && npm install --silent 2>&1 | tail -3)
  fi
  ok "listener deps installed"
  mark_step_done deps
}

step_launchd() {
  banner "Step 11/12  ·  Install launchd plists (boot listener + cron routines)"
  if yes_no "Install launchd plists now?"; then
    if [ -x "$PROJECT_DIR/launchd/install.sh" ]; then
      "$PROJECT_DIR/launchd/install.sh"
    else
      warn "launchd/install.sh not found or not executable — skipping"
    fi
  else
    note "  Skipped. Run ./launchd/install.sh manually when ready."
  fi
  mark_step_done launchd
}

step_smoke_test() {
  banner "Step 12/12  ·  Smoke test"
  local SLUG="$(get_var SLUG)"
  local SLACK_CHANNEL_ID="$(get_var SLACK_CHANNEL_ID)"
  if yes_no "Post a smoke-test message to #$(get_var SLACK_CHANNEL_NAME)?"; then
    "$PROJECT_DIR/accountability/routines/slack-post.sh" "$SLACK_CHANNEL_ID" - <<EOF || true
🤖 *${SLUG}* installed and listening.

This is a smoke-test message. Reply in this thread to verify the listener picks it up.
EOF
    ok "smoke-test message posted — check the channel"
  else
    note "  Skipped. You can test by sending any message in the channel."
  fi
  mark_step_done smoke_test
}

# ---------- Main ----------

banner "rapidclaw setup wizard"
print ""
note "  State file: $STATE_FILE"
print ""

declare -a steps=(
  bot_slug
  owner
  slack_basics
  slack_tokens
  openrouter
  chrome_profiles
  identity
  cron_times
  substitutions
  deps
  launchd
  smoke_test
)

for step in $steps; do
  if is_step_done "$step"; then
    print -P "${DIM}skipping step: $step (done)${RESET}"
    continue
  fi
  step_$step
  print ""
done

banner "Setup complete 🎉"
print ""
print -P "  Bot slug: ${BOLD}$(get_var SLUG)${RESET}"
print -P "  Project:  $PROJECT_DIR"
print -P "  Slack:    #$(get_var SLACK_CHANNEL_NAME) in $(get_var SLACK_WORKSPACE).slack.com"
print ""
print -P "  Inspect: ${DIM}./accountability/routines/coach.sh status${RESET}"
print -P "  Logs:    ${DIM}tail -f /tmp/$(get_var SLUG)-listener.log${RESET}"
print ""
