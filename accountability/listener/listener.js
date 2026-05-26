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

const SLUG = 'rapidnative-coach';
const PROJECT = '/Users/agni/Documents/rapidclaw';
const HOME = process.env.HOME;
// Channels the bot is configured to respond in. Populated at startup from
// channels/*.md files (Stage A multi-channel). CHANNELS_BY_ID is the
// authoritative lookup keyed by Slack channel_id; CHANNELS_BY_NAME mirrors it
// by short name for human-friendly logging and prompt substitution. A channel
// is "live" if (a) channels/<name>.md exists with a channel_id in frontmatter
// AND (b) the bot is actually a member of that channel per the Slack API.
// KNOWN_CHANNELS is the intersection; the message handler filters by it.
let CHANNELS_BY_ID = new Map();         // channel_id → { name, file, frontmatter, body }
let CHANNELS_BY_NAME = new Map();       // name → channel_id
let BOT_CHANNEL_MEMBERSHIPS = new Set(); // channel_ids the bot is in (per Slack)
let KNOWN_CHANNELS = new Set();          // intersection of the two
// TEAM_USERS, SUPERADMIN_USERS, and OWNER_USER_ID are populated after
// loadDotEnvIntoProcess() runs. Declared as `let` so they can be assigned
// post-dotenv-load.
let TEAM_USERS = new Set();
let SUPERADMIN_USERS = new Set();
let OWNER_USER_ID = '';
const BOT_USER = 'U0B4CBTR22H';
const CHANNEL_REFRESH_INTERVAL_MS = 5 * 60 * 1000;
const CLAUDE_PATH = '/opt/homebrew/bin/claude';
const NODE_BIN = '/opt/homebrew/bin';
const PATH_VAR = `${NODE_BIN}:${HOME}/.browser-use-env/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin`;

// ---------- file paths (all namespaced by slug) ----------

const APP_TOKEN_PATH = path.join(HOME, '.config/claude', `${SLUG}-slack-app-token`);
const BOT_TOKEN_PATH = path.join(HOME, '.config/claude', `${SLUG}-slack-bot-token`);
const PROCESSED_LOG = path.join(HOME, '.config/claude', `${SLUG}-processed-ts.log`);
const SESSION_STATE_PATH = path.join(HOME, '.config/claude', `${SLUG}-thread-sessions.json`);
const WORKTREE_STATE_PATH = path.join(HOME, '.config/claude', `${SLUG}-thread-worktrees.json`);
const INFLIGHT_PATH = path.join(HOME, '.config/claude', `${SLUG}-inflight.json`);
const EVENTS_LOG_PATH = path.join(HOME, '.config/claude', `${SLUG}-events.jsonl`);
const LISTENER_LOG = `/tmp/${SLUG}-listener.log`;
const BOOTSTRAP_PROMPT_FILE = path.join(PROJECT, 'accountability/listener/bootstrap-prompt.md');
const RESUME_PROMPT_FILE = path.join(PROJECT, 'accountability/listener/resume-prompt.md');

// Per-thread git worktrees. Each Slack thread gets its own checkout at
// ~/rapidclaw-worktrees/<safe_ts>/ on branch thread/<safe_ts>. Two teammates
// messaging at once write to different worktrees and don't collide on
// drafts/, sites/, the git index, etc. Memory dir is symlinked so the team
// roster + project memories are shared across worktrees. Bot Chrome is still
// singleton (separately serialized via shlock in browser-open.sh).
const WORKTREE_ROOT = path.join(HOME, 'rapidclaw-worktrees');
const SITE_WORKTREE_ROOT = path.join(HOME, 'rapidclaw-site-worktrees');
const WORKTREE_MAX_AGE_DAYS = 14;

// Mirror Claude Code's project-dir encoding so the worktree symlink lands at
// the same name Claude Code computes from cwd. The rule: leading slash → '-',
// then EVERY non-[a-zA-Z0-9-] character (so /, _, . are all mapped to '-').
// We verified empirically: spawning claude with cwd=
//   /Users/agni/rapidclaw-worktrees/1779440929_459699
// creates a project dir named
//   -Users-agni-rapidclaw-worktrees-1779440929-459699
// (the underscore becomes a dash). An earlier version of this encoder only
// handled '/' which silently broke the memory symlink for any path with '_'.
function encodeProjectPath(p) {
  return '-' + p.replace(/^\//, '').replace(/[^a-zA-Z0-9-]/g, '-');
}
const PROJECT_MEMORY_DIR_NAME = encodeProjectPath(PROJECT);

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

// Populate the team allowlist from .env. Listener silently drops messages
// from anyone not in this set. Exit early if it's empty — otherwise the bot
// would ignore every message and look broken.
TEAM_USERS = new Set(
  (process.env.TEAM_USERS || '').split(',').map(s => s.trim()).filter(Boolean)
);
SUPERADMIN_USERS = new Set(
  (process.env.SUPERADMIN_USERS || '').split(',').map(s => s.trim()).filter(Boolean)
);
OWNER_USER_ID = process.env.SLACK_USER_ID || '';
if (TEAM_USERS.size === 0) {
  console.error('FATAL: TEAM_USERS not set in .env — listener would reject every message. Edit .env and restart.');
  process.exit(1);
}

// senderTier returns the permission tier of a Slack user id:
//   'owner'      — the project owner (SLACK_USER_ID); full ship authority
//   'superadmin' — listed in SUPERADMIN_USERS; full ship authority
//   'teammate'   — in TEAM_USERS but no ship authority; can draft/read/research
//   'unknown'    — not in any list; should never happen because the message
//                  filter at the top of the handler already drops them, but
//                  surfaced as a tier name for prompt completeness.
function senderTier(userId) {
  if (!userId) return 'unknown';
  if (userId === OWNER_USER_ID) return 'owner';
  if (SUPERADMIN_USERS.has(userId)) return 'superadmin';
  if (TEAM_USERS.has(userId)) return 'teammate';
  return 'unknown';
}

// ---------- channel persona loading ----------

// Minimal YAML frontmatter parser. Handles the subset we use:
//   key: value
//   key: [a, b, c]
//   key: |   (we don't use block scalars; treat anything else as literal)
// Anything fancier (nested objects, multi-line strings) falls through as a
// string. Don't bring in a dep just for this.
function parseFrontmatter(text) {
  const m = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/);
  if (!m) return { frontmatter: {}, body: text };
  const fmRaw = m[1];
  const body = m[2];
  const fm = {};
  for (const line of fmRaw.split('\n')) {
    const km = line.match(/^([A-Za-z0-9_-]+)\s*:\s*(.*)$/);
    if (!km) continue;
    let v = km[2].trim();
    // Strip surrounding quotes
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    // Array form [a, b, c]
    if (v.startsWith('[') && v.endsWith(']')) {
      v = v.slice(1, -1).split(',').map(s => s.trim().replace(/^["']|["']$/g, '')).filter(Boolean);
    }
    fm[km[1]] = v;
  }
  return { frontmatter: fm, body };
}

function loadChannelsFromDisk() {
  const dir = path.join(PROJECT, 'channels');
  const map = new Map();
  let files;
  try { files = fs.readdirSync(dir).filter(f => f.endsWith('.md')); }
  catch { return map; }
  for (const f of files) {
    const full = path.join(dir, f);
    let raw;
    try { raw = fs.readFileSync(full, 'utf8'); }
    catch (e) { log(`channels: cannot read ${f}: ${e.message}`); continue; }
    const { frontmatter, body } = parseFrontmatter(raw);
    const channelId = frontmatter.channel_id;
    const name = frontmatter.name || f.replace(/\.md$/, '');
    if (!channelId || !/^[CG][A-Z0-9]+$/.test(channelId)) {
      log(`channels: ${f} has no valid channel_id in frontmatter — skipping`);
      continue;
    }
    if (map.has(channelId)) {
      log(`channels: duplicate channel_id ${channelId} between ${map.get(channelId).file} and ${f} — keeping first`);
      continue;
    }
    map.set(channelId, { name, file: f, path: full, frontmatter, body });
  }
  return map;
}

async function fetchBotChannelMemberships() {
  // users.conversations returns channels the auth user (bot) is a member of.
  // No user_id param → uses the auth token's user. Paginate just in case.
  //
  // Requires bot OAuth scopes: channels:read (public) and groups:read
  // (private). If those aren't granted on the bot's Slack app config, the
  // call returns missing_scope and we fall back to "trust the persona file"
  // mode in refreshKnownChannels.
  //
  // Returns { ok: boolean, ids: Set<string>, err?: string }.
  if (!BOT_TOKEN) return { ok: false, ids: new Set(), err: 'no bot token' };
  const ids = new Set();
  let cursor = '';
  for (let i = 0; i < 10; i++) {
    let resp;
    try {
      const params = { types: 'public_channel,private_channel', limit: 200 };
      if (cursor) params.cursor = cursor;
      resp = await slackApi('users.conversations', params);
    } catch (e) {
      return { ok: false, ids, err: e.message };
    }
    for (const c of (resp.channels || [])) ids.add(c.id);
    cursor = (resp.response_metadata && resp.response_metadata.next_cursor) || '';
    if (!cursor) break;
  }
  return { ok: true, ids };
}

let MEMBERSHIP_CHECK_HEALTHY = false;

async function refreshKnownChannels() {
  const onDisk = loadChannelsFromDisk();
  const memberships = await fetchBotChannelMemberships();
  CHANNELS_BY_ID = onDisk;
  CHANNELS_BY_NAME = new Map([...onDisk].map(([id, c]) => [c.name, id]));
  BOT_CHANNEL_MEMBERSHIPS = memberships.ids;

  if (memberships.ok) {
    if (!MEMBERSHIP_CHECK_HEALTHY) log('channel membership check: API healthy — using strict mode (persona file AND bot membership both required)');
    MEMBERSHIP_CHECK_HEALTHY = true;
    const known = new Set();
    for (const id of onDisk.keys()) {
      if (memberships.ids.has(id)) known.add(id);
    }
    const fileButNotMember = [...onDisk.keys()].filter(id => !memberships.ids.has(id));
    const memberButNoFile = [...memberships.ids].filter(id => !onDisk.has(id));
    KNOWN_CHANNELS = known;
    log(`channels refresh: ${known.size} live (${[...known].map(id => onDisk.get(id).name).join(', ') || 'none'})`);
    if (fileButNotMember.length) {
      log(`channels: persona file exists but bot is NOT a member of: ${fileButNotMember.map(id => onDisk.get(id).name + '(' + id + ')').join(', ')} — invite the bot or remove the file`);
    }
    if (memberButNoFile.length) {
      log(`channels: bot is a member but no persona file for: ${memberButNoFile.join(', ')} — silently ignored; create channels/<name>.md to activate`);
    }
  } else {
    // Slack API check unavailable (most often: missing OAuth scope). Fall
    // back to trusting the persona file — if the owner wrote a channels/*.md
    // file with a channel_id, that's an explicit declaration that the bot
    // should respond there. We log loudly so this isn't silent.
    if (MEMBERSHIP_CHECK_HEALTHY || MEMBERSHIP_CHECK_HEALTHY === false) {
      log(`channel membership check: FALLBACK MODE — Slack API call failed (${memberships.err}). Trusting channels/*.md persona files as authoritative.`);
      if (/missing_scope/i.test(memberships.err || '')) {
        log(`channel membership check: to enable strict mode, add OAuth scopes 'channels:read' and 'groups:read' to the bot's Slack app config, then reinstall to the workspace.`);
      }
    }
    MEMBERSHIP_CHECK_HEALTHY = false;
    KNOWN_CHANNELS = new Set(onDisk.keys());
    log(`channels refresh: ${KNOWN_CHANNELS.size} live (${[...KNOWN_CHANNELS].map(id => onDisk.get(id).name).join(', ') || 'none'}) [fallback mode]`);
  }

  // Cross-channel routines depend on CHANNELS_BY_NAME for target lookup, so
  // refresh them every time channels are refreshed.
  refreshCrossChannelRoutines();
}

function channelName(channelId) {
  const e = CHANNELS_BY_ID.get(channelId);
  return e ? e.name : channelId;
}

// ---------- cross-channel routines (Stage B) ----------
//
// Routines under accountability/routines/cross-channel/*.md. Each declares
// in frontmatter: name, target_channel (channel NAME — looked up against
// CHANNELS_BY_NAME), required_tier (owner / superadmin / teammate),
// trigger_phrases (array). Bot reads the file body for full instructions
// when invoking; the prompt only carries an INDEX so trigger recognition is
// cheap and the bot doesn't have to walk dirs every turn.
let CROSS_CHANNEL_ROUTINES = new Map(); // name → { ...frontmatter, file, target_channel_id }

function loadCrossChannelRoutinesFromDisk() {
  const dir = path.join(PROJECT, 'accountability/routines/cross-channel');
  const map = new Map();
  let files;
  try { files = fs.readdirSync(dir).filter(f => f.endsWith('.md')); }
  catch { return map; }
  for (const f of files) {
    const full = path.join(dir, f);
    let raw;
    try { raw = fs.readFileSync(full, 'utf8'); }
    catch (e) { log(`cross-channel: cannot read ${f}: ${e.message}`); continue; }
    const { frontmatter } = parseFrontmatter(raw);
    const name = frontmatter.name || f.replace(/\.md$/, '');
    const targetChannelName = frontmatter.target_channel;
    if (!targetChannelName) {
      log(`cross-channel: ${f} has no target_channel in frontmatter — skipping`);
      continue;
    }
    const targetChannelId = CHANNELS_BY_NAME.get(targetChannelName) || null;
    map.set(name, {
      name,
      file: `accountability/routines/cross-channel/${f}`,
      target_channel: targetChannelName,
      target_channel_id: targetChannelId,
      required_tier: frontmatter.required_tier || 'superadmin',
      trigger_phrases: Array.isArray(frontmatter.trigger_phrases) ? frontmatter.trigger_phrases : [],
      description: frontmatter.description || '(no description)',
    });
  }
  return map;
}

function refreshCrossChannelRoutines() {
  // Channels must be loaded first so target_channel_id resolves.
  CROSS_CHANNEL_ROUTINES = loadCrossChannelRoutinesFromDisk();
  const orphaned = [...CROSS_CHANNEL_ROUTINES.values()].filter(r => !r.target_channel_id);
  log(`cross-channel routines: ${CROSS_CHANNEL_ROUTINES.size} loaded (${[...CROSS_CHANNEL_ROUTINES.keys()].join(', ') || 'none'})`);
  if (orphaned.length) {
    log(`cross-channel: ${orphaned.length} routine(s) target an unknown channel: ${orphaned.map(r => r.name + '→' + r.target_channel).join(', ')} — fix target_channel or add the persona file`);
  }
}

// Render the routine index for prompt substitution. Returns a markdown block
// the bot can scan in O(routines) at semantic-match time.
function renderCrossChannelRoutineIndex() {
  if (CROSS_CHANNEL_ROUTINES.size === 0) {
    return '_(no cross-channel routines defined)_';
  }
  const lines = [];
  for (const r of CROSS_CHANNEL_ROUTINES.values()) {
    const triggers = r.trigger_phrases.length
      ? r.trigger_phrases.map(t => `"${t}"`).join(', ')
      : '(no triggers — invoked only by explicit name)';
    const targetDisplay = r.target_channel_id
      ? `#${r.target_channel}`
      : `#${r.target_channel} ⚠ unknown channel (orphaned)`;
    lines.push(`- **\`${r.name}\`** → posts to ${targetDisplay} · requires tier: \`${r.required_tier}\` · triggers: ${triggers}`);
    lines.push(`  · full instructions: \`${r.file}\``);
    lines.push(`  · ${r.description}`);
  }
  return lines.join('\n');
}

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
function saveThreadSession(threadTs, sessionId, firstMessage, channelId) {
  const m = loadThreadSessions();
  const existing = m[threadTs] || {};
  m[threadTs] = {
    session_id: sessionId,
    last_used: new Date().toISOString(),
    first_message: existing.first_message || firstMessage || null,
    // Stage A: record which channel this thread lives in so cross-channel
    // backfill can scan the right channel. Legacy entries without channel_id
    // are still readable; backfill skips active-thread scan for those (they
    // catch up via the per-channel history pass).
    channel_id: existing.channel_id || channelId || null,
  };
  try { fs.writeFileSync(SESSION_STATE_PATH, JSON.stringify(m, null, 2)); }
  catch (e) { log(`session save error: ${e.message}`); }
}

// ---------- per-thread git worktrees ----------

const { execFileSync } = require('child_process');

function loadWorktreeMap() {
  try { return JSON.parse(fs.readFileSync(WORKTREE_STATE_PATH, 'utf8')); }
  catch { return {}; }
}
function saveWorktreeMap(m) {
  try { fs.writeFileSync(WORKTREE_STATE_PATH, JSON.stringify(m, null, 2)); }
  catch (e) { log(`worktree-state save error: ${e.message}`); }
}
function getThreadWorktree(threadTs) {
  const m = loadWorktreeMap();
  const entry = m[threadTs];
  if (!entry) return null;
  // If the dir was manually deleted, treat as missing
  if (!fs.existsSync(entry.path)) return null;
  return entry.path;
}
function setThreadWorktree(threadTs, wtPath, branch) {
  const m = loadWorktreeMap();
  m[threadTs] = { path: wtPath, branch, created_at: new Date().toISOString() };
  saveWorktreeMap(m);
}
function safeThreadTs(threadTs) {
  // Slack ts is like "1779379100.123456" — git branch names allow '.' but the
  // dir name is cleaner without it.
  return String(threadTs).replace(/\./g, '_');
}

// Symlink one path into the worktree if its source exists. Creates parent
// dirs. Removes any existing entry at the dst first.
function linkInto(workdir, relPath) {
  const src = path.join(PROJECT, relPath);
  const dst = path.join(workdir, relPath);
  if (!fs.existsSync(src) && !(() => { try { fs.lstatSync(src); return true; } catch { return false; } })()) return;
  try { fs.mkdirSync(path.dirname(dst), { recursive: true }); } catch {}
  try {
    if (fs.existsSync(dst) || (() => { try { fs.lstatSync(dst); return true; } catch { return false; } })()) {
      // Remove existing file/dir/symlink at dst
      try { fs.unlinkSync(dst); } catch { try { fs.rmSync(dst, { recursive: true, force: true }); } catch {} }
    }
    fs.symlinkSync(src, dst);
  } catch (e) {
    log(`worktree symlink ${relPath} failed: ${e.message}`);
  }
}

// Symlink the Claude Code project memory dir so each worktree shares team
// roster + project memories with the main project. Without this, every
// worktree thread starts cold and the bot can't identify teammates.
function linkMemoryDir(workdir) {
  const mainEncoded = PROJECT_MEMORY_DIR_NAME;
  const wtEncoded = encodeProjectPath(workdir);
  const mainMemDir = path.join(HOME, '.claude/projects', mainEncoded);
  const wtMemDir = path.join(HOME, '.claude/projects', wtEncoded);
  try { fs.mkdirSync(path.join(HOME, '.claude/projects'), { recursive: true }); } catch {}
  if (!fs.existsSync(mainMemDir)) {
    log(`memory link: main memory dir ${mainMemDir} doesn't exist yet — skipping (will appear once claude writes memory)`);
    return;
  }
  try {
    if (fs.existsSync(wtMemDir) || (() => { try { fs.lstatSync(wtMemDir); return true; } catch { return false; } })()) {
      try { fs.unlinkSync(wtMemDir); } catch { try { fs.rmSync(wtMemDir, { recursive: true, force: true }); } catch {} }
    }
    fs.symlinkSync(mainMemDir, wtMemDir);
    log(`memory link: ${wtEncoded} → ${mainEncoded}`);
  } catch (e) {
    log(`memory link failed: ${e.message}`);
  }
}

function createWorktreeForThread(threadTs) {
  try { fs.mkdirSync(WORKTREE_ROOT, { recursive: true }); } catch {}
  const safeTs = safeThreadTs(threadTs);
  const wtPath = path.join(WORKTREE_ROOT, safeTs);
  const branch = `thread/${safeTs}`;

  // Already exists and is a valid worktree — just return it
  if (fs.existsSync(wtPath)) {
    log(`worktree for ${threadTs} already exists at ${wtPath}`);
    return { wtPath, branch };
  }

  // Try `git worktree add -b <branch> <path> HEAD`
  try {
    execFileSync('git', ['-C', PROJECT, 'worktree', 'add', '-b', branch, wtPath, 'HEAD'], { stdio: 'pipe' });
    log(`worktree created: ${wtPath} on new branch ${branch}`);
  } catch (e1) {
    // Branch likely already exists (from a previous worktree that was deleted)
    try {
      execFileSync('git', ['-C', PROJECT, 'worktree', 'add', wtPath, branch], { stdio: 'pipe' });
      log(`worktree re-attached: ${wtPath} on existing branch ${branch}`);
    } catch (e2) {
      log(`worktree creation failed for ${threadTs}: ${e1.message.trim()} / retry: ${e2.message.trim()}`);
      // Clean up any partial dir
      try { fs.rmSync(wtPath, { recursive: true, force: true }); } catch {}
      return null;
    }
  }

  // Symlink gitignored runtime files the bot needs
  linkInto(wtPath, '.env');

  // sites/ is special: instead of one symlink to main's sites/ (which would
  // make two threads write to the same linked repo), create a real dir with
  // per-site symlinks. Each entry initially points at the same real repo as
  // main's sites/<name> (so routines that read from sites/<name> still work).
  // sites-prepare.sh later replaces individual entries with per-thread
  // worktrees of the underlying real repo, isolating concurrent edits.
  populateSitesDir(wtPath);

  // Symlink memory dir so team roster + auto-memory is shared
  linkMemoryDir(wtPath);

  return { wtPath, branch };
}

function populateSitesDir(wtPath) {
  const mainSites = path.join(PROJECT, 'sites');
  const wtSites = path.join(wtPath, 'sites');
  if (!fs.existsSync(mainSites)) return;
  // git worktree add already created an empty sites/ (tracked? gitignored?).
  // Either way, ensure it's a real dir, not a symlink, and is empty.
  try {
    if (fs.existsSync(wtSites) || (() => { try { fs.lstatSync(wtSites); return true; } catch { return false; } })()) {
      try { fs.unlinkSync(wtSites); } catch { try { fs.rmSync(wtSites, { recursive: true, force: true }); } catch {} }
    }
    fs.mkdirSync(wtSites, { recursive: true });
  } catch (e) {
    log(`populateSitesDir: failed to make ${wtSites}: ${e.message}`);
    return;
  }
  let entries = [];
  try { entries = fs.readdirSync(mainSites, { withFileTypes: true }); } catch { return; }
  for (const ent of entries) {
    const mainEntry = path.join(mainSites, ent.name);
    const wtEntry = path.join(wtSites, ent.name);
    try {
      let lst;
      try { lst = fs.lstatSync(mainEntry); } catch { continue; }
      if (lst.isSymbolicLink()) {
        // Mirror the symlink target. Bot uses sites-prepare.sh to swap this
        // to a per-thread worktree later.
        const target = fs.readlinkSync(mainEntry);
        fs.symlinkSync(target, wtEntry);
      } else if (lst.isFile()) {
        // Pointer .md file (e.g., sites/foo.md). Copy it verbatim.
        fs.copyFileSync(mainEntry, wtEntry);
      } else {
        // Skip unknown entry kinds
      }
    } catch (e) {
      log(`populateSitesDir: failed to mirror ${ent.name}: ${e.message}`);
    }
  }
}

function pruneSiteWorktreesForThread(safeTs) {
  // Remove any per-thread site worktrees under ~/rapidclaw-site-worktrees/<safeTs>/.
  // Each entry is a worktree of a linked site's real repo, so we have to call
  // `git worktree remove` from each real repo's perspective, then rmdir the
  // per-thread parent dir.
  const perThreadDir = path.join(SITE_WORKTREE_ROOT, safeTs);
  let siteEntries = [];
  try { siteEntries = fs.readdirSync(perThreadDir, { withFileTypes: true }); } catch { return 0; }
  const touchedRepos = new Set();
  let removed = 0;
  for (const ent of siteEntries) {
    const sitePerThreadWt = path.join(perThreadDir, ent.name);
    // Find the real repo: walk into the worktree's .git pointer to learn.
    // A worktree's .git is a regular file containing "gitdir: <real-repo>/.git/worktrees/<id>".
    let realRepo = null;
    try {
      const gitFile = path.join(sitePerThreadWt, '.git');
      const txt = fs.readFileSync(gitFile, 'utf8');
      const m = txt.match(/^gitdir:\s*(.*?)\/\.git\/worktrees\//m);
      if (m) realRepo = m[1];
    } catch {}
    if (realRepo) {
      try {
        execFileSync('git', ['-C', realRepo, 'worktree', 'remove', '--force', sitePerThreadWt], { stdio: 'pipe' });
        touchedRepos.add(realRepo);
      } catch {
        try { fs.rmSync(sitePerThreadWt, { recursive: true, force: true }); } catch {}
      }
    } else {
      try { fs.rmSync(sitePerThreadWt, { recursive: true, force: true }); } catch {}
    }
    removed++;
  }
  try { fs.rmdirSync(perThreadDir); } catch {}
  for (const r of touchedRepos) {
    try { execFileSync('git', ['-C', r, 'worktree', 'prune'], { stdio: 'pipe' }); } catch {}
  }
  return removed;
}

function pruneOldWorktrees(maxAgeDays = WORKTREE_MAX_AGE_DAYS) {
  let pruned = 0;
  let listed = [];
  try {
    listed = fs.readdirSync(WORKTREE_ROOT, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => path.join(WORKTREE_ROOT, d.name));
  } catch { return; }
  const cutoff = Date.now() - maxAgeDays * 24 * 60 * 60 * 1000;
  const map = loadWorktreeMap();
  let siteWtsRemoved = 0;
  for (const wt of listed) {
    let mtime = 0;
    try { mtime = fs.statSync(wt).mtimeMs; } catch { continue; }
    if (mtime >= cutoff) continue;
    const safeTs = path.basename(wt);
    // First clean up any per-thread site worktrees that hang off this thread
    siteWtsRemoved += pruneSiteWorktreesForThread(safeTs);
    try {
      execFileSync('git', ['-C', PROJECT, 'worktree', 'remove', '--force', wt], { stdio: 'pipe' });
    } catch (e) {
      // Force-remove the dir anyway if git refused (e.g., locked/corrupt)
      try { fs.rmSync(wt, { recursive: true, force: true }); } catch {}
    }
    // Drop matching entries from the map
    for (const [ts, entry] of Object.entries(map)) {
      if (entry.path === wt) delete map[ts];
    }
    pruned++;
    log(`pruned old worktree: ${safeTs} (idle ≥ ${maxAgeDays}d)`);
  }
  if (pruned > 0) saveWorktreeMap(map);
  try { execFileSync('git', ['-C', PROJECT, 'worktree', 'prune'], { stdio: 'pipe' }); } catch {}
  if (pruned > 0 || listed.length > 0) log(`worktree GC: pruned=${pruned} bot-wt + ${siteWtsRemoved} site-wt, retained=${listed.length - pruned}`);
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

function channelPromptVars(channelId) {
  const entry = CHANNELS_BY_ID.get(channelId);
  if (!entry) {
    return {
      CHANNEL_NAME: 'unknown',
      CHANNEL_PERSONA_PATH: '(no persona file)',
      CHANNEL_PURPOSE: '(unknown channel)',
      CROSS_CHANNEL_ROUTINES_INDEX: renderCrossChannelRoutineIndex(),
    };
  }
  return {
    CHANNEL_NAME: entry.name,
    CHANNEL_PERSONA_PATH: `channels/${entry.file}`,
    CHANNEL_PURPOSE: entry.frontmatter.purpose || '(no purpose stated in frontmatter)',
    CROSS_CHANNEL_ROUTINES_INDEX: renderCrossChannelRoutineIndex(),
  };
}

function buildBootstrapPrompt({ event, text, threadTs, files }) {
  const isFirstTurn = (event.thread_ts == null) || (event.thread_ts === event.ts);
  const tmpl = fs.readFileSync(BOOTSTRAP_PROMPT_FILE, 'utf8');
  return substitute(tmpl, {
    TEXT_JSON: JSON.stringify(text),
    CHANNEL: event.channel,
    ...channelPromptVars(event.channel),
    REPLY_TS: event.ts,
    THREAD_TS: threadTs,
    SENDER_USER_ID: event.user || 'unknown',
    SENDER_TIER: senderTier(event.user),
    OWNER_USER_ID: OWNER_USER_ID || 'unknown',
    SUPERADMIN_PINGS: [...SUPERADMIN_USERS].map(u => `<@${u}>`).join(', ') || '(none)',
    BOT_USER_ID: BOT_USER,
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
    ...channelPromptVars(event.channel),
    REPLY_TS: event.ts,
    THREAD_TS: threadTs,
    SENDER_USER_ID: event.user || 'unknown',
    SENDER_TIER: senderTier(event.user),
    OWNER_USER_ID: OWNER_USER_ID || 'unknown',
    SUPERADMIN_PINGS: [...SUPERADMIN_USERS].map(u => `<@${u}>`).join(', ') || '(none)',
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

    // Pick the working directory: per-thread worktree if available, else
    // fall back to the main project (preserves old behavior if worktree
    // creation fails).
    let workdir = getThreadWorktree(job.threadTs);
    if (!workdir) {
      const created = createWorktreeForThread(job.threadTs);
      if (created) {
        workdir = created.wtPath;
        setThreadWorktree(job.threadTs, created.wtPath, created.branch);
      } else {
        log(`falling back to main project dir for thread ${job.threadTs} (worktree creation failed)`);
        workdir = PROJECT;
      }
    }

    const args = [
      '-p',
      '--dangerously-skip-permissions',
      '--add-dir', workdir,
      '--output-format', 'stream-json',
      '--verbose',
    ];
    if (isResume) args.push('--resume', existingSession);

    log(`spawning claude -p ${isResume ? `(RESUME ${existingSession.slice(0,8)}…)` : '(FRESH session)'} prompt=${prompt.length}b thread=${job.threadTs} cwd=${workdir === PROJECT ? 'PROJECT' : path.basename(workdir)}`);
    appendEvent({
      type: 'start',
      thread_ts: job.threadTs,
      event_ts: job.event.ts,
      is_resume: isResume,
      session_id: existingSession || null,
      prompt_bytes: prompt.length,
      workdir,
      text: (job.text || '').slice(0, 200),
    });

    const child = spawn(CLAUDE_PATH, args, {
      cwd: workdir,
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, PATH: PATH_VAR, HOME, SLACK_THREAD_TS: job.threadTs, SLACK_CHANNEL: job.event.channel, SLACK_SENDER_USER_ID: job.event.user || '', SLACK_SENDER_TIER: senderTier(job.event.user), SLACK_THREAD_WORKDIR: workdir },
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
        saveThreadSession(job.threadTs, sessionId, firstMessage, job.event.channel);
        log(`saved session ${sessionId.slice(0,8)}… for thread=${job.threadTs} channel=${channelName(job.event.channel)}`);
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

async function backfillChannel(channelId, sessions, activeCutoffMs, scannedThreadsByChannel) {
  const oldestSec = Math.floor((Date.now() - BACKFILL_WINDOW_MS) / 1000);
  const name = channelName(channelId);
  log(`backfill[${name}]: scanning since ${new Date(oldestSec * 1000).toISOString()}`);

  let history;
  try {
    history = await slackApi('conversations.history', { channel: channelId, oldest: oldestSec, limit: 200 });
  } catch (e) { log(`backfill[${name}] error (history): ${e.message}`); return []; }

  const topLevel = (history.messages || []).slice().sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));
  const candidates = [];
  const scannedThreads = new Set();

  for (const m of topLevel) {
    if (TEAM_USERS.has(m.user) && (!m.subtype || m.subtype === 'file_share')) {
      candidates.push({ ...m, channel: channelId });
    }
    if (m.thread_ts && m.thread_ts === m.ts && (m.reply_count || 0) > 0) {
      try {
        const thread = await slackApi('conversations.replies', { channel: channelId, ts: m.ts, limit: 200 });
        scannedThreads.add(m.ts);
        for (const r of (thread.messages || [])) {
          if (r.ts === m.ts) continue;
          if (TEAM_USERS.has(r.user) && (!r.subtype || r.subtype === 'file_share')) {
            candidates.push({ ...r, channel: channelId });
          }
        }
      } catch (e) { log(`backfill[${name}] error (replies for ${m.ts}): ${e.message}`); }
    }
  }

  // Active-thread sweep: threads recorded in session state belonging to this
  // channel that weren't already covered by the history scan.
  const activeThreads = Object.entries(sessions)
    .filter(([ts, info]) => {
      if (!info || info.channel_id !== channelId) return false;
      if (scannedThreads.has(ts)) return false;
      const lu = info.last_used ? Date.parse(info.last_used) : 0;
      return lu >= activeCutoffMs;
    })
    .map(([ts]) => ts);
  for (const threadTs of activeThreads) {
    try {
      const thread = await slackApi('conversations.replies', { channel: channelId, ts: threadTs, limit: 200 });
      for (const r of (thread.messages || [])) {
        if (r.ts === threadTs) continue;
        if (TEAM_USERS.has(r.user) && (!r.subtype || r.subtype === 'file_share')) {
          candidates.push({ ...r, channel: channelId });
        }
      }
    } catch (e) { log(`backfill[${name}] error (active-thread replies for ${threadTs}): ${e.message}`); }
  }

  scannedThreadsByChannel.set(channelId, scannedThreads);
  return candidates;
}

async function backfill() {
  if (!BOT_TOKEN) { log('backfill skipped: bot token not loaded'); return; }
  if (KNOWN_CHANNELS.size === 0) { log('backfill skipped: no known channels'); return; }

  const sessions = loadThreadSessions();
  const activeCutoffMs = Date.now() - 7 * 24 * 3600 * 1000;
  const scannedThreadsByChannel = new Map();

  // Scan each known channel. Sequential rather than parallel to be polite to
  // Slack's tier-3 rate limits and to keep logs in order.
  const all = [];
  for (const channelId of KNOWN_CHANNELS) {
    const c = await backfillChannel(channelId, sessions, activeCutoffMs, scannedThreadsByChannel);
    all.push(...c);
  }

  all.sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));
  const unprocessed = all.filter(m => !processed.has(m.ts));
  log(`backfill: ${all.length} candidate(s) across ${KNOWN_CHANNELS.size} channel(s), ${unprocessed.length} unprocessed`);

  for (const m of unprocessed) {
    const text = (m.text || '').trim();
    const files = Array.isArray(m.files) ? m.files : [];
    if (!text && files.length === 0) continue;
    const threadTs = m.thread_ts || m.ts;
    log(`backfill enqueue: channel=${channelName(m.channel)} thread=${threadTs} reply=${m.ts} text="${text.slice(0, 80)}"`);
    markProcessed(m.ts);
    enqueue({ event: m, text, threadTs, files });
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
  if (!TEAM_USERS.has(event.user)) return;
  if (!KNOWN_CHANNELS.has(event.channel)) return;
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
pruneOldWorktrees();

// Channel discovery has to populate KNOWN_CHANNELS before the socket's
// `connected` event triggers the first backfill (which short-circuits when
// the set is empty). Do the initial Slack API call here, synchronously
// awaited, before client.start(). Then start the socket and schedule periodic
// refreshes for newly-invited channels.
(async () => {
  await refreshKnownChannels();
  setInterval(() => {
    refreshKnownChannels().catch(e => log(`channel refresh failed: ${e.message}`));
  }, CHANNEL_REFRESH_INTERVAL_MS);
  client.start().then(
    () => {
      log(`listener started — slug=${SLUG}, ${TEAM_USERS.size} team / ${SUPERADMIN_USERS.size} super-admins, ${KNOWN_CHANNELS.size} live channel(s)`);
      if (process.env.ANTHROPIC_BASE_URL) log(`routing claude -p via ${process.env.ANTHROPIC_BASE_URL} · model=${process.env.ANTHROPIC_MODEL}`);
      else log('claude -p using default Anthropic auth (no OpenRouter routing)');
    },
    err => { log(`start failed: ${err.message || err}`); process.exit(1); }
  );
})().catch(err => { log(`startup failed: ${err.message || err}`); process.exit(1); });

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
