#!/usr/bin/env node
// Claude Code's (and anyone's) command line for tasker (tasks.rapidnative.com).
// Calls the same tools tasker's in-app assistant uses, as the person in your git config.
//
//   node ~/.claude/skills/tasker/tasker.mjs tools                 list the tools
//   node ~/.claude/skills/tasker/tasker.mjs tools <name>          one tool's description and input schema
//   node ~/.claude/skills/tasker/tasker.mjs whoami                who you act as, and whether the token is
//        your personal one (exit 0) or the team's shared one (exit 3: no Personal project)
//   node ~/.claude/skills/tasker/tasker.mjs set-token [-]         save your personal token from the clipboard
//        (or stdin with -) to ~/.config/tasker/token: copy it in tasker (user menu → Claude Code token), run this
//   node ~/.claude/skills/tasker/tasker.mjs <tool> '<json>'       run a tool (json may be "-" to read stdin)
//        --project <name>                         the project to work in (RapidNative, LetsDeployIt)
//
// Token: TASKER_AGENT_TOKEN, else ~/.config/tasker/token. URL: TASKER_URL (default production).
import { execFileSync } from "node:child_process";
import { readFileSync, existsSync, writeFileSync, mkdirSync, renameSync, chmodSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const URL_BASE = (process.env.TASKER_URL || "https://tasks.rapidnative.com").replace(/\/$/, "");

function token() {
  if (process.env.TASKER_AGENT_TOKEN) return process.env.TASKER_AGENT_TOKEN.trim();
  const f = join(homedir(), ".config", "tasker", "token");
  if (existsSync(f)) return readFileSync(f, "utf8").trim();
  fail("no token: set TASKER_AGENT_TOKEN or write it to ~/.config/tasker/token (ask Sanket)");
}

function git(key) {
  try {
    return execFileSync("git", ["config", key], { encoding: "utf8" }).trim();
  } catch {
    return "";
  }
}

function fail(msg, code = 1) {
  console.error(`tasker: ${msg}`);
  process.exit(code);
}

async function call(method, body) {
  const name = git("user.name");
  // `git config --global tasker.email you@rapidnative.com` when your git identity doesn't match you on tasker
  const email = git("tasker.email") || git("user.email");
  if (method === "POST" && !name && !email) fail("git user.name / user.email are not set; tasker acts as your git user");
  const res = await fetch(`${URL_BASE}/api/agent`, {
    method,
    headers: { authorization: `Bearer ${token()}`, "content-type": "application/json", "x-git-name": name, "x-git-email": email },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    fail(`HTTP ${res.status}: ${text.slice(0, 300)}`);
  }
  if (res.status === 403) fail(`${json.error}\nFix: git config --global tasker.email <you>@rapidnative.com`, 2);
  if (!res.ok) fail(`HTTP ${res.status}: ${JSON.stringify(json.issues ?? json.error ?? json)}`, 2);
  return json;
}

const args = process.argv.slice(2);
let project;
const pi = args.indexOf("--project");
if (pi !== -1) {
  project = args[pi + 1];
  args.splice(pi, 2);
}
const [cmd, arg] = args;

if (!cmd || cmd === "help" || cmd === "--help") {
  console.log(readFileSync(new URL(import.meta.url), "utf8").split("\n").filter((l) => l.startsWith("//")).map((l) => l.slice(3)).join("\n"));
  process.exit(0);
}

if (cmd === "tools") {
  const { tools } = await call("GET");
  if (arg) {
    const t = tools.find((x) => x.name === arg);
    if (!t) fail(`no tool "${arg}"`);
    console.log(JSON.stringify(t, null, 2));
  } else {
    for (const t of tools) console.log(`${t.name.padEnd(20)} ${(t.description ?? "").split(/(?<=\.)\s/)[0]}`);
  }
  process.exit(0);
}

// Which token is this? A personal one (made in tasker: user menu → Claude Code token) says who you are and
// reaches your Personal project; the team's shared one goes by your git identity and reaches no one's.
if (cmd === "whoami") {
  const out = await call("POST", { tool: "find_nodes", input: { query: "whoami", limit: 1 } });
  const personal = out.token === "personal";
  console.log(
    personal
      ? `${out.as} · personal token: your Personal project is reachable`
      : `${out.as} · the team's shared token: your Personal project isn't reachable.\n` +
          `Make your own: ${URL_BASE} → your user menu → Claude Code token → Create, copy it (copy nothing\n` +
          `else after it), then run: node ~/.claude/skills/tasker/tasker.mjs set-token`,
  );
  process.exit(personal ? 0 : 3);
}

// Save a personal token: from the clipboard (copying a command to paste would replace the token there,
// so this reads it directly) or stdin. Only a tk_ token is written, and it's checked against tasker first.
if (cmd === "set-token") {
  let raw = "";
  try {
    raw = arg === "-" ? readFileSync(0, "utf8") : execFileSync("pbpaste", { encoding: "utf8" });
  } catch {
    fail("couldn't read the clipboard: pipe the token in instead, `... | tasker.mjs set-token -`");
  }
  const t = raw.trim();
  if (!/^tk_[A-Za-z0-9_-]{20,}$/.test(t)) {
    fail(`that isn't a personal token (they start with tk_). Copy it again in ${URL_BASE} → user menu → Claude Code token, then rerun this without copying anything else. Nothing was saved.`);
  }
  const check = await fetch(`${URL_BASE}/api/agent`, {
    method: "POST",
    headers: { authorization: `Bearer ${t}`, "content-type": "application/json" },
    body: JSON.stringify({ tool: "find_nodes", input: { query: "whoami", limit: 1 } }),
  });
  const body = await check.json().catch(() => ({}));
  if (!check.ok || body.token !== "personal") fail(`tasker didn't accept that token (HTTP ${check.status}). Make a new one and try again. Nothing was saved.`);
  const dir = join(homedir(), ".config", "tasker");
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const file = join(dir, "token");
  const shared = existsSync(file) && !readFileSync(file, "utf8").trim().startsWith("tk_");
  if (shared) renameSync(file, `${file}.shared`); // the team token, kept to switch back to
  writeFileSync(`${file}.new`, t, { mode: 0o600 });
  renameSync(`${file}.new`, file);
  chmodSync(file, 0o600);
  console.log(`Saved. You act as ${body.as}, with your Personal project.${shared ? " The shared token is in ~/.config/tasker/token.shared." : ""}`);
  process.exit(0);
}

let input = {};
if (arg === "-") input = JSON.parse(readFileSync(0, "utf8") || "{}");
else if (arg) {
  try {
    input = JSON.parse(arg);
  } catch {
    fail(`input must be JSON, got: ${arg}`);
  }
}
const out = await call("POST", { tool: cmd, input, project });
console.log(JSON.stringify(out, null, 2));
