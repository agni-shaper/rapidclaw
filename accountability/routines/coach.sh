#!/bin/zsh
# coach.sh — operational control for a rapidclaw bot's listener + jobs.
#
# Subcommands:
#   coach.sh status                       — dump listener + jobs + threads as JSON
#   coach.sh events [thread_ts] [limit]   — JSON tail of the events log
#   coach.sh restart-listener             — kickstart -k the launchd listener
#   coach.sh stop-listener                — bootout (will stay down until start)
#   coach.sh start-listener               — bootstrap from the installed plist
#   coach.sh stop-job <event_ts>          — kill claude child + drop inflight
#   coach.sh reset-thread <thread_ts>     — clear saved session (next msg = fresh)
#   coach.sh kill-all                     — emergency: stop listener + kill claude -p

set -e
source "${0:A:h}/_lib.sh"

LAUNCHD_LABEL="com.${OWNER}.${BOT_SLUG}-listener"
PLIST_PATH="$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist"
SESSIONS_FILE="$HOME/.config/claude/${BOT_SLUG}-thread-sessions.json"
INFLIGHT_FILE="$HOME/.config/claude/${BOT_SLUG}-inflight.json"
PROCESSED_FILE="$HOME/.config/claude/${BOT_SLUG}-processed-ts.log"
EVENTS_FILE="$HOME/.config/claude/${BOT_SLUG}-events.jsonl"
LISTENER_LOG="/tmp/${BOT_SLUG}-listener.log"

SUBCMD="${1:-status}"
shift || true

cmd_status() {
  LABEL="$LAUNCHD_LABEL" LOG="$LISTENER_LOG" INFLIGHT="$INFLIGHT_FILE" \
  SESSIONS="$SESSIONS_FILE" PROCESSED="$PROCESSED_FILE" \
  /usr/bin/python3 - <<'PY'
import json, os, subprocess, sys
from datetime import datetime, timezone

label = os.environ["LABEL"]
log_path = os.environ["LOG"]
inflight_path = os.environ["INFLIGHT"]
sessions_path = os.environ["SESSIONS"]
processed_path = os.environ["PROCESSED"]

def safe_json_load(p, default):
    try:
        with open(p) as f: return json.load(f)
    except Exception: return default

inflight = safe_json_load(inflight_path, [])
sessions = safe_json_load(sessions_path, {})

pid = None; listener_uptime = None
try:
    out = subprocess.check_output(["launchctl", "list"], text=True)
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2] == label:
            try: pid = int(parts[0])
            except ValueError: pid = None
            break
except Exception: pass

if pid:
    try: listener_uptime = subprocess.check_output(["ps", "-o", "etime=", "-p", str(pid)], text=True).strip()
    except Exception: pass

# All claude -p processes (macOS pgrep -a returns just PIDs — we look up cmds individually)
try:
    out = subprocess.check_output(["pgrep", "-f", "claude -p"], text=True)
    alive = []
    for pid_str in out.splitlines():
        pid_str = pid_str.strip()
        if not pid_str: continue
        try: etime = subprocess.check_output(["ps", "-o", "etime=", "-p", pid_str], text=True).strip()
        except Exception: etime = None
        alive.append({"pid": int(pid_str), "etime": etime})
except subprocess.CalledProcessError: alive = []
except Exception: alive = []

# Last log lines + heartbeat / match / exit
last_lines = []; last_heartbeat = None; last_match = None; last_exit = None
try:
    with open(log_path) as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 60_000))
        tail = f.read().splitlines()[-200:]
    for line in tail:
        if "heartbeat —" in line: last_heartbeat = line
        elif " MATCH " in line: last_match = line
        elif "claude exited" in line: last_exit = line
    last_lines = tail[-10:]
except Exception: pass

# Threads sorted by last_used desc
threads = []
for tts, info in sessions.items():
    threads.append({
        "thread_ts": tts,
        "session_id": (info.get("session_id") or "")[:8] + "…" if info.get("session_id") else None,
        "last_used": info.get("last_used"),
        "first_message": info.get("first_message") or None,
    })
threads.sort(key=lambda x: x.get("last_used") or "", reverse=True)

# Orphan claude -p (alive but not in inflight)
inflight_pids = set()
for entry in inflight:
    cp = entry.get("child_pid")
    if cp:
        try: inflight_pids.add(int(cp))
        except (TypeError, ValueError): pass

orphans = []
for proc in alive:
    if proc["pid"] not in inflight_pids:
        try:
            cmd_out = subprocess.check_output(["ps", "-o", "command=", "-p", str(proc["pid"])], text=True).strip()
        except Exception: cmd_out = ""
        orphans.append({"pid": proc["pid"], "etime": proc["etime"], "command": cmd_out[:200]})

processed_count = 0
try:
    with open(processed_path) as f:
        for _ in f: processed_count += 1
except Exception: pass

state = {
    "listener": {"pid": pid, "running": pid is not None and pid > 0, "uptime": listener_uptime, "label": label},
    "active_claude_processes": alive,
    "inflight_jobs": inflight,
    "orphan_processes": orphans,
    "threads": threads,
    "log": {"last_heartbeat": last_heartbeat, "last_match": last_match, "last_exit": last_exit, "tail": last_lines},
    "processed_count": processed_count,
}
print(json.dumps(state, indent=2))
PY
}

cmd_events() {
  local thread="${1:-}"
  local limit="${2:-50}"
  EVENTS="$EVENTS_FILE" THREAD="$thread" LIMIT="$limit" /usr/bin/python3 - <<'PY'
import json, os
events_path = os.environ["EVENTS"]
thread_filter = os.environ["THREAD"]
try: limit = max(1, int(os.environ["LIMIT"]))
except ValueError: limit = 50
out = []
if os.path.exists(events_path):
    with open(events_path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try: ev = json.loads(line)
            except Exception: continue
            if thread_filter and ev.get("thread_ts") != thread_filter: continue
            out.append(ev)
out = out[-limit:]
print(json.dumps({"events": out, "count": len(out), "thread_filter": thread_filter or None}, indent=2))
PY
}

cmd_restart_listener() {
  launchctl kickstart -k "gui/$UID/$LAUNCHD_LABEL"
  echo "OK restart-listener"
}

cmd_stop_listener() {
  if [ -f "$PLIST_PATH" ]; then launchctl bootout "gui/$UID/$LAUNCHD_LABEL" 2>&1 || true
  else launchctl unload -w "$PLIST_PATH" 2>&1 || true
  fi
  echo "OK stop-listener"
}

cmd_start_listener() {
  [ -f "$PLIST_PATH" ] || { echo "ERROR: plist not found at $PLIST_PATH" >&2; exit 1; }
  launchctl bootstrap "gui/$UID" "$PLIST_PATH" 2>&1 || true
  echo "OK start-listener"
}

cmd_stop_job() {
  local event_ts="${1:?usage: coach.sh stop-job <event_ts>}"
  INFLIGHT="$INFLIGHT_FILE" EVENT_TS="$event_ts" /usr/bin/python3 - <<'PY'
import json, os, signal, subprocess
inflight_path, event_ts = os.environ["INFLIGHT"], os.environ["EVENT_TS"]
try:
    with open(inflight_path) as f: data = json.load(f) or []
except Exception: data = []
match = None; remaining = []
for entry in data:
    if entry.get("event_ts") == event_ts: match = entry
    else: remaining.append(entry)
if not match:
    print(f"ERROR: no inflight job with event_ts={event_ts}", file=__import__('sys').stderr)
    raise SystemExit(1)
with open(inflight_path, "w") as f: json.dump(remaining, f, indent=2)
pid = match.get("child_pid")
if pid:
    try:
        os.kill(int(pid), signal.SIGTERM)
        print(f"OK stop-job event_ts={event_ts} pid={pid} (SIGTERM sent)")
    except ProcessLookupError:
        print(f"OK stop-job event_ts={event_ts} (already exited; inflight cleared)")
else:
    out = subprocess.run(["pgrep", "-f", "claude -p"], capture_output=True, text=True)
    pids = sorted(int(p) for p in out.stdout.split() if p)
    if pids:
        oldest = pids[0]
        try: os.kill(oldest, signal.SIGTERM); print(f"OK stop-job event_ts={event_ts} pid={oldest} (no child_pid; killed oldest claude -p; inflight cleared)")
        except ProcessLookupError: print(f"OK stop-job event_ts={event_ts} (no live claude -p; inflight cleared)")
    else:
        print(f"OK stop-job event_ts={event_ts} (no live claude -p; inflight cleared)")
PY
}

cmd_reset_thread() {
  local thread_ts="${1:?usage: coach.sh reset-thread <thread_ts>}"
  SESSIONS="$SESSIONS_FILE" THREAD_TS="$thread_ts" /usr/bin/python3 - <<'PY'
import json, os
sessions_path, thread_ts = os.environ["SESSIONS"], os.environ["THREAD_TS"]
try:
    with open(sessions_path) as f: data = json.load(f) or {}
except Exception: data = {}
removed = data.pop(thread_ts, None)
with open(sessions_path, "w") as f: json.dump(data, f, indent=2)
if removed:
    sid = (removed.get('session_id','?') or '?')[:8]
    print(f"OK reset-thread {thread_ts} (cleared session {sid}…)")
else:
    print(f"OK reset-thread {thread_ts} (no saved session — was already fresh)")
PY
}

claude_pids() { pgrep -fa 'claude -p' 2>/dev/null | awk '{print $1}'; }

cmd_kill_all() {
  echo "stopping listener..."
  cmd_stop_listener
  echo "killing claude -p children..."
  local pids
  pids="$(claude_pids || true)"
  if [ -n "$pids" ]; then
    echo "$pids" | xargs -I{} kill -TERM {} 2>/dev/null || true
    sleep 1
    pids="$(claude_pids || true)"
    [ -n "$pids" ] && echo "$pids" | xargs -I{} kill -KILL {} 2>/dev/null || true
  fi
  /usr/bin/python3 -c "open('$INFLIGHT_FILE','w').write('[]')" 2>/dev/null || true
  echo "OK kill-all (inflight cleared, listener stopped, all claude -p children killed)"
}

case "$SUBCMD" in
  status)            cmd_status ;;
  events)            cmd_events "$@" ;;
  restart-listener)  cmd_restart_listener ;;
  stop-listener)     cmd_stop_listener ;;
  start-listener)    cmd_start_listener ;;
  stop-job)          cmd_stop_job "$@" ;;
  reset-thread)      cmd_reset_thread "$@" ;;
  kill-all)          cmd_kill_all ;;
  *)
    cat >&2 <<EOF
ERROR: unknown subcommand '$SUBCMD'

Usage:
  coach.sh status                       — JSON snapshot
  coach.sh events [thread_ts] [limit]   — JSON tail of events log
  coach.sh restart-listener             — kickstart -k
  coach.sh stop-listener                — bootout
  coach.sh start-listener               — bootstrap
  coach.sh stop-job <event_ts>          — kill child + drop inflight
  coach.sh reset-thread <thread_ts>     — clear saved session
  coach.sh kill-all                     — emergency
EOF
    exit 1
    ;;
esac
