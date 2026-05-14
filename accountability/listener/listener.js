#!/usr/bin/env node
// rapidclaw listener — Slack Socket Mode → `claude -p`.
//
// Treats any message from the owner in the target channel (top-level or thread
// reply) as a conversational turn. Spawns `claude -p` with a prompt loaded from
// bootstrap-prompt.md (or resume-prompt.md for follow-ups), substituting runtime
// values (channel/thread_ts/text/files). The spawned claude reads CLAUDE.md +
// profile.md for project context, does the task, posts back, and cleans up.
//
// This file is slug-aware: all hardcoded values (channel, user IDs, project
// path) are placeholders the bot-init wizard substitutes from the user's answers.

const { SocketModeClient } = require('@slack/socket-mode');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// ---------- slug-aware constants (substituted by bot-init.sh) ----------

const SLUG = '__SLUG__';
const PROJECT = '__PROJECT_DIR__';
const HOME = process.env.HOME;
const TARGET_CHANNEL = '__SLACK_CHANNEL_ID__';
const OWNER_USER = '__SLACK_USER_ID__';
const BOT_USER = '__BOT_USER_ID__';
const CLAUDE_PATH = '__CLAUDE_PATH__';
const NODE_BIN = '__NODE_BIN__';
const PATH_VAR = `${NODE_BIN}:${HOME}/.browser-use-env/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin`;

// ---------- file paths (all namespaced by slug) ----------

const APP_TOKEN_PATH = path.join(HOME, '.config/claude', `${SLUG}-slack-app-token`);
const BOT_TOKEN_PATH = path.join(HOME, '.config/claude', `${SLUG}-slack-bot-token`);
const PROCESSED_LOG = path.join(HOME, '.config/claude', `${SLUG}-processed-ts.log`);
const SESSION_STATE_PATH = path.join(HOME, '.config/claude', `${SLUG}-thread-sessions.json`);
const INFLIGHT_PATH = path.join(HOME, '.config/claude', `${SLUG}-inflight.json`);
const EVENTS_LOG_PATH = path.join(HOME, '.config/claude', `${SLUG}-events.jsonl`);
const LISTENER_LOG = `/tmp/${SLUG}-listener.log`;
const BOOTSTRAP_PROMPT_FILE = path.join(PROJECT, 'accountability/listener/bootstrap-prompt.md');
const RESUME_PROMPT_FILE = path.join(PROJECT, 'accountability/listener/resume-prompt.md');

// Ensure the ~/.config/claude/ dir exists for our state files
try { fs.mkdirSync(path.dirname(APP_TOKEN_PATH), { recursive: true, mode: 0o700 }); } catch {}

const APP_TOKEN = fs.readFileSync(APP_TOKEN_PATH, 'utf8').trim();
let BOT_TOKEN = '';
try { BOT_TOKEN = fs.readFileSync(BOT_TOKEN_PATH, 'utf8').trim(); } catch {}

// ---------- .env loading + optional OpenRouter routing ----------

function loadDotEnvIntoProcess() {
  try {
    const txt = fs.readFileSync(path.join(PROJECT, '.env'), 'utf8');
    for (const line of txt.split('\n')) {
      const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)\s*$/);
      if (!m) continue;
      const v = m[2].replace(/^["']|["']$/g, '');
      if (!process.env[m[1]]) process.env[m[1]] = v;
    }
  } catch {}
}
loadDotEnvIntoProcess();

// Gated behind USE_OPENROUTER=1 in .env. Default off — claude CLI uses the
// owner's Anthropic subscription. Flip the flag if Anthropic disables
// subscription-based automation usage of `claude -p`.
if (process.env.USE_OPENROUTER === '1' && process.env.OPENROUTER_API_KEY) {
  process.env.ANTHROPIC_BASE_URL = process.env.ANTHROPIC_BASE_URL || 'https://openrouter.ai/api';
  process.env.ANTHROPIC_AUTH_TOKEN = process.env.OPENROUTER_API_KEY;
  process.env.ANTHROPIC_MODEL = process.env.LISTENER_MODEL || process.env.ANTHROPIC_MODEL || 'anthropic/claude-haiku-4-5';
}

// ---------- logging ----------

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}\n`;
  process.stdout.write(line);
  try { fs.appendFileSync(LISTENER_LOG, line); } catch {}
}

// ---------- processed-ts log (dedup) ----------

const processed = new Set();
try {
  fs.readFileSync(PROCESSED_LOG, 'utf8').split('\n').filter(Boolean).forEach(ts => processed.add(ts));
  log(`loaded ${processed.size} processed ts from log`);
} catch {}

function markProcessed(ts) {
  if (processed.has(ts)) return;
  processed.add(ts);
  try { fs.appendFileSync(PROCESSED_LOG, ts + '\n'); } catch (e) { log(`mark error: ${e.message}`); }
}

// ---------- per-thread event log (jsonl, the studio reads this) ----------

function appendEvent(ev) {
  const line = JSON.stringify({ ts: new Date().toISOString(), ...ev }) + '\n';
  try { fs.appendFileSync(EVENTS_LOG_PATH, line); }
  catch (e) { log(`event-log append error: ${e.message}`); }
}

function rotateEventLog(maxLines = 5000) {
  try {
    if (!fs.existsSync(EVENTS_LOG_PATH)) return;
    const lines = fs.readFileSync(EVENTS_LOG_PATH, 'utf8').split('\n').filter(Boolean);
    if (lines.length <= maxLines) return;
    fs.writeFileSync(EVENTS_LOG_PATH, lines.slice(-maxLines).join('\n') + '\n');
    log(`event-log rotated: kept last ${maxLines} of ${lines.length} lines`);
  } catch (e) { log(`event-log rotate error: ${e.message}`); }
}

// ---------- tool-trace helpers ----------

function truncate(s, n = 80) {
  if (s == null) return '';
  s = String(s).replace(/\s+/g, ' ').trim();
  return s.length > n ? s.slice(0, n - 1) + '…' : s;
}
function tailPath(p, depth = 2) {
  if (!p) return '';
  return String(p).split('/').filter(Boolean).slice(-depth).join('/');
}

function summarizeToolUse(tu) {
  const name = tu.name || 'Tool';
  const input = tu.input || {};
  switch (name) {
    case 'Bash': return `Bash: ${truncate(input.description || input.command, 80)}`;
    case 'Read': return `Read ${truncate(tailPath(input.file_path, 2), 60)}`;
    case 'Edit': return `Edit ${truncate(tailPath(input.file_path, 2), 60)}`;
    case 'Write': return `Write ${truncate(tailPath(input.file_path, 2), 60)}`;
    case 'Glob': return `Glob: ${truncate(input.pattern || input.path, 60)}`;
    case 'Grep': return `Grep: ${truncate(input.pattern, 60)}`;
    case 'Skill': return `Skill: ${truncate(input.skill || input.name, 50)}`;
    case 'Task':
    case 'Agent': return `Agent: ${truncate(input.description || input.subagent_type, 70)}`;
    case 'WebFetch': return `WebFetch: ${truncate(input.url, 70)}`;
    case 'WebSearch': return `WebSearch: ${truncate(input.query, 70)}`;
    case 'TodoWrite': return `TodoWrite (${(input.todos || []).length} item${(input.todos || []).length === 1 ? '' : 's'})`;
    default: {
      const k = Object.keys(input)[0];
      return k ? `${name}: ${truncate(input[k], 70)}` : name;
    }
  }
}

async function slackPostStatus(channel, threadTs, text) {
  if (!BOT_TOKEN) throw new Error('bot token not loaded');
  const body = { channel, text, mrkdwn: true };
  if (threadTs && threadTs !== '-') body.thread_ts = threadTs;
  const r = await fetch('https://slack.com/api/chat.postMessage', {
    method: 'POST',
    headers: { Authorization: `Bearer ${BOT_TOKEN}`, 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify(body),
  });
  const j = await r.json();
  if (!j.ok) throw new Error(`postMessage failed: ${j.error}`);
  return j.ts;
}

async function slackUpdateStatus(channel, ts, text) {
  if (!BOT_TOKEN) throw new Error('bot token not loaded');
  const r = await fetch('https://slack.com/api/chat.update', {
    method: 'POST',
    headers: { Authorization: `Bearer ${BOT_TOKEN}`, 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ channel, ts, text, mrkdwn: true }),
  });
  const j = await r.json();
  if (!j.ok) throw new Error(`update failed: ${j.error}`);
}

// ---------- inflight tracking (crash-safe job recovery) ----------

function readInflight() {
  try { return JSON.parse(fs.readFileSync(INFLIGHT_PATH, 'utf8')) || []; }
  catch { return []; }
}
function writeInflight(list) {
  try { fs.writeFileSync(INFLIGHT_PATH, JSON.stringify(list, null, 2)); }
  catch (e) { log(`inflight write error: ${e.message}`); }
}
function markInflight(job, childPid = null) {
  const list = readInflight();
  const existing = list.find(x => x.event_ts === job.event.ts);
  if (existing) {
    if (childPid != null) { existing.child_pid = childPid; writeInflight(list); }
    return;
  }
  list.push({
    event_ts: job.event.ts,
    started_at: new Date().toISOString(),
    child_pid: childPid,
    job: { event: job.event, text: job.text, threadTs: job.threadTs, files: job.files },
  });
  writeInflight(list);
}
function clearInflight(eventTs) {
  const before = readInflight();
  const after = before.filter(x => x.event_ts !== eventTs);
  if (after.length !== before.length) writeInflight(after);
}
function recoverInflight() {
  const list = readInflight();
  if (list.length === 0) return;
  log(`recovering ${list.length} interrupted job(s) from previous run`);
  for (const x of list) {
    const txt = (x.job?.text || '').slice(0, 60);
    log(`recovery enqueue: thread=${x.job?.threadTs} reply=${x.event_ts} text="${txt}"`);
    if (x.job) enqueue(x.job);
  }
}

// ---------- per-thread Claude session resume ----------

function loadThreadSessions() {
  try { return JSON.parse(fs.readFileSync(SESSION_STATE_PATH, 'utf8')); }
  catch { return {}; }
}
function getThreadSession(threadTs) {
  const m = loadThreadSessions();
  return m[threadTs] && m[threadTs].session_id;
}
function saveThreadSession(threadTs, sessionId, firstMessage) {
  const m = loadThreadSessions();
  const existing = m[threadTs] || {};
  m[threadTs] = {
    session_id: sessionId,
    last_used: new Date().toISOString(),
    first_message: existing.first_message || firstMessage || null,
  };
  try { fs.writeFileSync(SESSION_STATE_PATH, JSON.stringify(m, null, 2)); }
  catch (e) { log(`session save error: ${e.message}`); }
}

// ---------- queue + health metrics ----------

const queue = [];
let busy = false;
const activeChildren = new Set();
let shuttingDown = false;

const FLAP_WINDOW_MS = 5 * 60 * 1000;
const FLAP_THRESHOLD = 6;
const HEARTBEAT_MS = 30 * 60 * 1000;
const BACKFILL_WINDOW_MS = 24 * 60 * 60 * 1000;
const BACKFILL_REFRESH_MS = 2 * 60 * 1000;
const PERIODIC_BACKFILL_MS = 3 * 60 * 1000;
let recentDisconnects = [];
let lastSuccessfulEventAt = Date.now();
let lastBackfillAt = 0;

function enqueue(job) { queue.push(job); drain(); }

function drain() {
  if (busy || queue.length === 0) return;
  busy = true;
  const job = queue.shift();
  log(`dequeue: thread=${job.threadTs} reply=${job.event.ts}, queue depth now ${queue.length}`);
  runClaude(job).catch(e => log(`runClaude error: ${e.message}`)).finally(() => {
    busy = false;
    setImmediate(drain);
  });
}

// ---------- prompt building (load from .md files, substitute runtime values) ----------

function filesBlock(files) {
  if (!files || files.length === 0) return '';
  const lines = files.map(f =>
    `- ${f.name || '(unnamed)'} (${f.mimetype || 'unknown'}, ${f.size || '?'} bytes) — url_private: ${f.url_private}`
  ).join('\n');
  return `\nThe owner also attached ${files.length} file(s):\n${lines}\nFetch via \`accountability/routines/slack-download-file.sh <url_private> [output_path]\` (requires bot \`files:read\` scope).\n`;
}

function substitute(template, vars) {
  return template.replace(/\{\{([A-Z_]+)\}\}/g, (m, k) => (vars[k] !== undefined ? String(vars[k]) : m));
}

function buildBootstrapPrompt({ event, text, threadTs, files }) {
  const isFirstTurn = (event.thread_ts == null) || (event.thread_ts === event.ts);
  const tmpl = fs.readFileSync(BOOTSTRAP_PROMPT_FILE, 'utf8');
  return substitute(tmpl, {
    TEXT_JSON: JSON.stringify(text),
    CHANNEL: event.channel,
    REPLY_TS: event.ts,
    THREAD_TS: threadTs,
    TURN_KIND: isFirstTurn ? 'a new top-level message (start of conversation)' : 'a reply inside an existing thread (continuation)',
    FILES_BLOCK: files && files.length ? filesBlock(files) : '',
    LOAD_THREAD_HINT: isFirstTurn
      ? 'No prior turns to load.'
      : `Read the thread via Bash: \`accountability/routines/slack-read-thread.sh ${event.channel} ${threadTs}\` — outputs JSON of all messages in this thread (parent + replies). The thread IS your conversation memory.`,
  });
}

function buildResumePrompt({ event, text, threadTs, files }) {
  const tmpl = fs.readFileSync(RESUME_PROMPT_FILE, 'utf8');
  return substitute(tmpl, {
    TEXT: text || '(no text)',
    CHANNEL: event.channel,
    REPLY_TS: event.ts,
    THREAD_TS: threadTs,
    FILES_BLOCK: files && files.length ? filesBlock(files) : '',
  });
}

// ---------- runClaude — spawn + stream tool trace to Slack ----------

const STATUS_THROTTLE_MS = 3000;
const STATUS_TRACE_LINES = 10;
const STATUS_HANG_MS = 60000;
const STATUS_HANG_CHECK_MS = 15000;

function runClaude(job) {
  return new Promise(resolve => {
    markInflight(job);
    const existingSession = getThreadSession(job.threadTs);
    const isResume = !!existingSession;
    const prompt = isResume ? buildResumePrompt(job) : buildBootstrapPrompt(job);

    const args = [
      '-p',
      '--dangerously-skip-permissions',
      '--add-dir', PROJECT,
      '--output-format', 'stream-json',
      '--verbose',
    ];
    if (isResume) args.push('--resume', existingSession);

    log(`spawning claude -p ${isResume ? `(RESUME ${existingSession.slice(0,8)}…)` : '(FRESH session)'} prompt=${prompt.length}b thread=${job.threadTs}`);
    appendEvent({
      type: 'start',
      thread_ts: job.threadTs,
      event_ts: job.event.ts,
      is_resume: isResume,
      session_id: existingSession || null,
      prompt_bytes: prompt.length,
      text: (job.text || '').slice(0, 200),
    });

    const child = spawn(CLAUDE_PATH, args, {
      cwd: PROJECT,
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, PATH: PATH_VAR, HOME, SLACK_THREAD_TS: job.threadTs, SLACK_CHANNEL: job.event.channel },
    });
    activeChildren.add(child);
    markInflight(job, child.pid);
    child.stdin.write(prompt);
    child.stdin.end();

    const channel = job.event.channel;
    const threadTs = job.threadTs;
    const startedAt = Date.now();
    let stdoutBuf = '', stderrBuf = '';
    const traceLines = [];
    let toolCount = 0;
    let statusTs = null;
    let lastStatusUpdateAt = 0;
    let pendingStatusTimer = null;
    let lastEventAt = Date.now();
    let hangNotified = false;
    let exited = false;
    let resultEvent = null;

    const renderStatus = ({ done = false, hung = false } = {}) => {
      const elapsedSec = Math.round((Date.now() - startedAt) / 1000);
      const visible = traceLines.slice(-STATUS_TRACE_LINES);
      const header = done
        ? `✅ *Done* — ${toolCount} tool call${toolCount === 1 ? '' : 's'} in ${elapsedSec}s`
        : `🔄 *Working...* (${elapsedSec}s, ${toolCount} tool call${toolCount === 1 ? '' : 's'})`;
      const lines = visible.length === 0 ? ['▸ thinking…'] : visible.map(l => `▸ ${l}`);
      const hangNote = hung ? '\n⚠️ no activity for >60s — claude may be stuck' : '';
      return [header, lines.join('\n')].join('\n') + hangNote;
    };

    const flushStatus = async ({ done = false, hung = false } = {}) => {
      lastStatusUpdateAt = Date.now();
      const text = renderStatus({ done, hung });
      try {
        if (!statusTs) statusTs = await slackPostStatus(channel, threadTs, text);
        else await slackUpdateStatus(channel, statusTs, text);
      } catch (e) { log(`status flush error: ${e.message}`); }
    };

    const scheduleStatus = () => {
      if (pendingStatusTimer || exited) return;
      const delay = Math.max(50, STATUS_THROTTLE_MS - (Date.now() - lastStatusUpdateAt));
      pendingStatusTimer = setTimeout(async () => {
        pendingStatusTimer = null;
        if (exited) return;
        await flushStatus();
      }, delay);
    };

    const handleEvent = ev => {
      lastEventAt = Date.now();
      if (hangNotified) hangNotified = false;
      switch (ev.type) {
        case 'system': scheduleStatus(); break;
        case 'assistant': {
          const content = ev.message?.content;
          if (!Array.isArray(content)) break;
          let added = false;
          for (const block of content) {
            if (block.type === 'tool_use') {
              const summary = summarizeToolUse(block);
              traceLines.push(summary);
              toolCount += 1;
              added = true;
              appendEvent({
                type: 'tool_use',
                thread_ts: threadTs,
                event_ts: job.event.ts,
                tool: block.name || 'Tool',
                summary,
              });
            }
          }
          if (added) scheduleStatus();
          break;
        }
        case 'result': resultEvent = ev; break;
      }
    };

    child.stdout.on('data', d => {
      stdoutBuf += d.toString();
      let nl;
      while ((nl = stdoutBuf.indexOf('\n')) !== -1) {
        const line = stdoutBuf.slice(0, nl).trim();
        stdoutBuf = stdoutBuf.slice(nl + 1);
        if (!line) continue;
        let ev;
        try { ev = JSON.parse(line); } catch { continue; }
        try { handleEvent(ev); } catch (e) { log(`handleEvent error: ${e.message}`); }
      }
    });
    child.stderr.on('data', d => { stderrBuf += d.toString(); });

    const hangCheck = setInterval(() => {
      if (exited) return;
      if ((Date.now() - lastEventAt) > STATUS_HANG_MS && !hangNotified && statusTs) {
        hangNotified = true;
        flushStatus({ hung: true }).catch(() => {});
      }
    }, STATUS_HANG_CHECK_MS);

    child.on('exit', async (code, signal) => {
      exited = true;
      clearInterval(hangCheck);
      if (pendingStatusTimer) { clearTimeout(pendingStatusTimer); pendingStatusTimer = null; }

      const dur = ((Date.now() - startedAt) / 1000).toFixed(1);
      let sessionId = null, resultText = null, costUsd = null;
      if (resultEvent) {
        sessionId = resultEvent.session_id || null;
        resultText = (resultEvent.result || '').slice(0, 200);
        costUsd = resultEvent.total_cost_usd;
      } else {
        log(`no result event in stream (code=${code} signal=${signal || ''})`);
      }

      if (sessionId && sessionId !== existingSession) {
        const isParent = job.event.thread_ts == null || job.event.thread_ts === job.event.ts;
        const firstMessage = isParent ? (job.text || '').slice(0, 280) : null;
        saveThreadSession(job.threadTs, sessionId, firstMessage);
        log(`saved session ${sessionId.slice(0,8)}… for thread=${job.threadTs}`);
      }

      activeChildren.delete(child);
      if (code === 0) {
        clearInflight(job.event.ts);
      } else {
        const stillInflight = readInflight().some(x => x.event_ts === job.event.ts);
        if (stillInflight) log(`leaving inflight entry for ${job.event.ts} for retry on next start (code=${code} signal=${signal || ''})`);
        else log(`inflight entry for ${job.event.ts} externally cleared (likely coach.sh stop-job); not retrying (code=${code} signal=${signal || ''})`);
      }
      log(`claude exited code=${code} after ${dur}s${costUsd != null ? ` cost=$${costUsd.toFixed(4)}` : ''}${resultText ? ` result="${resultText}"` : ''}`);
      if (stderrBuf && code !== 0) log(`STDERR: ${stderrBuf.slice(0, 800)}`);
      appendEvent({
        type: 'end',
        thread_ts: job.threadTs,
        event_ts: job.event.ts,
        code,
        signal: signal || null,
        duration_s: parseFloat(dur),
        cost_usd: costUsd ?? null,
        tool_count: toolCount,
        result: resultText || null,
      });

      if (statusTs) {
        try { await flushStatus({ done: code === 0 }); }
        catch (e) { log(`final status flush error: ${e.message}`); }
      }
      resolve();
    });
    child.on('error', e => {
      exited = true;
      clearInterval(hangCheck);
      activeChildren.delete(child);
      log(`spawn error: ${e.message}`);
      resolve();
    });
  });
}

// ---------- backfill (catches messages while listener was offline) ----------

async function slackApi(method, params = {}) {
  if (!BOT_TOKEN) throw new Error('bot token not loaded');
  const url = new URL(`https://slack.com/api/${method}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, String(v));
  const r = await fetch(url, { headers: { Authorization: `Bearer ${BOT_TOKEN}` } });
  const j = await r.json();
  if (!j.ok) throw new Error(`${method} failed: ${j.error}`);
  return j;
}

async function backfill() {
  if (!BOT_TOKEN) { log('backfill skipped: bot token not loaded'); return; }
  const oldestSec = Math.floor((Date.now() - BACKFILL_WINDOW_MS) / 1000);
  log(`backfill: scanning ${TARGET_CHANNEL} since ${new Date(oldestSec * 1000).toISOString()}`);

  let history;
  try {
    history = await slackApi('conversations.history', {
      channel: TARGET_CHANNEL,
      oldest: oldestSec,
      limit: 200,
    });
  } catch (e) { log(`backfill error (history): ${e.message}`); return; }

  const topLevel = (history.messages || []).slice().sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));
  const candidates = [];

  for (const m of topLevel) {
    if (m.user === OWNER_USER && (!m.subtype || m.subtype === 'file_share')) candidates.push(m);
    if (m.thread_ts && m.thread_ts === m.ts && (m.reply_count || 0) > 0) {
      try {
        const thread = await slackApi('conversations.replies', { channel: TARGET_CHANNEL, ts: m.ts, limit: 200 });
        for (const r of (thread.messages || [])) {
          if (r.ts === m.ts) continue;
          if (r.user === OWNER_USER && (!r.subtype || r.subtype === 'file_share')) candidates.push(r);
        }
      } catch (e) { log(`backfill error (replies for ${m.ts}): ${e.message}`); }
    }
  }

  candidates.sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));
  const unprocessed = candidates.filter(m => !processed.has(m.ts));
  log(`backfill: ${candidates.length} owner message(s) in window, ${unprocessed.length} unprocessed`);

  for (const m of unprocessed) {
    const text = (m.text || '').trim();
    const files = Array.isArray(m.files) ? m.files : [];
    if (!text && files.length === 0) continue;
    const threadTs = m.thread_ts || m.ts;
    log(`backfill enqueue: thread=${threadTs} reply=${m.ts} text="${text.slice(0, 80)}"`);
    markProcessed(m.ts);
    enqueue({ event: { ...m, channel: TARGET_CHANNEL }, text, threadTs, files });
  }
}

// ---------- Socket Mode client + handlers ----------

const client = new SocketModeClient({ appToken: APP_TOKEN });

client.on('message', async ({ event, ack }) => {
  if (ack) { try { await ack(); } catch {} }
  lastSuccessfulEventAt = Date.now();
  if (!event) return;
  if (event.subtype && event.subtype !== 'file_share') return;
  if (event.bot_id) return;
  if (event.user === BOT_USER) return;
  if (event.user !== OWNER_USER) return;
  if (event.channel !== TARGET_CHANNEL) return;
  if (processed.has(event.ts)) return;

  const text = (event.text || '').trim();
  const files = Array.isArray(event.files) ? event.files : [];
  if (!text && files.length === 0) return;

  const threadTs = event.thread_ts || event.ts;
  log(`MATCH thread=${threadTs} reply=${event.ts} text="${text.slice(0, 80)}" files=${files.length}`);
  markProcessed(event.ts);
  enqueue({ event, text, threadTs, files });
});

client.on('error', err => log(`SOCKET ERROR: ${err.message || err}`));

client.on('disconnect', () => {
  const now = Date.now();
  recentDisconnects.push(now);
  recentDisconnects = recentDisconnects.filter(t => now - t < FLAP_WINDOW_MS);
  log(`socket disconnected (${recentDisconnects.length} in last ${FLAP_WINDOW_MS / 60000}min)`);
  if (recentDisconnects.length >= FLAP_THRESHOLD) {
    log(`FLAPPING: ${recentDisconnects.length} disconnects in last ${FLAP_WINDOW_MS / 60000}min — exiting for launchd to restart`);
    setTimeout(() => process.exit(2), 100);
  }
});

client.on('connected', () => {
  log('socket connected');
  const sinceLast = Date.now() - lastBackfillAt;
  if (sinceLast < BACKFILL_REFRESH_MS) {
    log(`backfill skipped — ran ${(sinceLast / 1000).toFixed(0)}s ago (throttle=${BACKFILL_REFRESH_MS / 1000}s)`);
    return;
  }
  lastBackfillAt = Date.now();
  setTimeout(() => backfill().catch(e => log(`backfill threw: ${e.message}`)), 1500);
});

client.on('unable_to_socket_mode_start', err => {
  log(`unable to start: ${err && err.message}`);
  setTimeout(() => process.exit(3), 100);
});

// Periodic backfill safety net — Socket Mode can silently lose events without
// firing a disconnect. Polling every 3min ensures messages get picked up.
setInterval(() => {
  const sinceLast = Date.now() - lastBackfillAt;
  if (sinceLast < BACKFILL_REFRESH_MS) return;
  lastBackfillAt = Date.now();
  log(`periodic backfill (last ran ${(sinceLast / 60000).toFixed(1)}min ago)`);
  backfill().catch(e => log(`periodic backfill threw: ${e.message}`));
}, PERIODIC_BACKFILL_MS);

setInterval(() => {
  const uptimeMin = (process.uptime() / 60).toFixed(1);
  const lastEventAgo = Math.round((Date.now() - lastSuccessfulEventAt) / 60000);
  log(`heartbeat — uptime ${uptimeMin}min, queue=${queue.length}, busy=${busy}, active_children=${activeChildren.size}, last_event_received=${lastEventAgo}min ago, recent_disconnects=${recentDisconnects.length}`);
}, HEARTBEAT_MS);

rotateEventLog();
recoverInflight();

client.start().then(
  () => {
    log(`listener started — watching #__SLACK_CHANNEL_NAME__ (slug=${SLUG})`);
    if (process.env.ANTHROPIC_BASE_URL) log(`routing claude -p via ${process.env.ANTHROPIC_BASE_URL} · model=${process.env.ANTHROPIC_MODEL}`);
    else log('claude -p using default Anthropic auth (no OpenRouter routing)');
  },
  err => { log(`start failed: ${err.message || err}`); process.exit(1); }
);

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  const n = activeChildren.size;
  log(`${signal} received — killing ${n} active claude child${n === 1 ? '' : 'ren'}, exiting`);
  for (const c of activeChildren) { try { c.kill('SIGTERM'); } catch {} }
  setTimeout(() => {
    if (activeChildren.size > 0) for (const c of activeChildren) { try { c.kill('SIGKILL'); } catch {} }
    process.exit(0);
  }, 1000);
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
