# Subagent model (addendum to plan.md)

> **REFRAME (2026-06-25, @sanket reply `1782382397.400179`):** subagents are an **escape hatch**, not the spine. The 80% case is single-thread, single-context, main coach handles directly. Subagents are for one-shot artifact generation (banners, images, screenshots, rendered HTML) and the rare genuinely-async "go open a PR while I sleep". **The real architecture is top-level memory + skills that load more skills recursively.** This addendum still applies for the cases where subagents DO fire, but the centre of gravity is the skills system documented in plan.md §2.3 — not this file.
>
> Concretely: the 12 capability domains are **skills** (not subagents). Distribution = skill that recursively loads per-brand strategy + per-account reference files. Task-ops = skill. Newsletter = skill. Etc. Main coach reads them inline and preserves thread continuity. Site subagents come into play only for one-shot artifact gen and async background work; handoff/handback mode (designed below) exists for the rare sustained-subagent case.


In response to Sanket's question in thread `1782373569.212709`:
> "Do we now have concept of subagents (either say Distribution agent for eg, or when working inside a site repo)?"

**Yes — and we should formalize it as the core orchestration model.** The precedent already exists at `sites/tasks/agents/bot-god/` (full system-prompt.md + config.yaml + heartbeat cron + per-task git worktrees). This addendum extends the plan to make subagents first-class.

---

## Why subagents (not just skills)

A skill is a procedure Claude loads inline. A subagent is a **separate `claude -p` invocation** with its own scoped context, system prompt, and tool set. They solve different problems:

| Concern | Skill | Subagent |
|---|---|---|
| Context bloat | shares main agent's context | fresh context window, only loads what its scope needs |
| Tool scope | inherits main agent's tools | can restrict tools (e.g. site subagent can't post to Slack directly) |
| Parallelism | sequential | multiple can run concurrently |
| Failure isolation | error pollutes main turn | subagent crash ≠ main agent state |
| Repo independence | impossible (main agent loads it) | natural — site subagent IS the repo's agent |

For Shaper Studio OS, **big-context / multi-step capabilities become subagents; small CRUD-style capabilities stay as skills.**

---

## Three-tier architecture

```
                                    ┌──────────────────────────────────┐
                                    │  MAIN COACH (orchestrator)        │
                                    │                                  │
                                    │  context: COMPANY.md + channel  │
       Slack event / cron ─────────►│  persona + definitions/ index   │
                                    │  + auto-memory                  │
                                    │                                  │
                                    │  job: route, permission-gate,   │
                                    │  post final reply, persist log  │
                                    └──────────────┬───────────────────┘
                                                   │
                ┌──────────────────────────────────┼──────────────────────────────────┐
                │                                  │                                  │
                ▼                                  ▼                                  ▼
   ┌────────────────────────┐      ┌────────────────────────┐         ┌────────────────────────┐
   │  DOMAIN SUBAGENT       │      │  INLINE SKILL          │         │  SITE SUBAGENT         │
   │  (.claude/agents/<X>/) │      │  (.claude/skills/<X>/) │         │  (sites/<X>/.claude/  │
   │                        │      │                        │         │   agents/<X>-agent/)   │
   │  e.g. distribution,    │      │  e.g. leave, eod-      │         │  e.g. rn-website,      │
   │  task-ops, newsletter, │      │  nudges, scheduler,    │         │  applighter-website,   │
   │  weekly-wrap,          │      │  repo-edit, bug-       │         │  branding, tasks,      │
   │  user-testing          │      │  tracking              │         │  letsdeployit          │
   │                        │      │                        │         │                        │
   │  loaded via Agent      │      │  loaded inline in main │         │  spawned as child      │
   │  tool (in-process,     │      │  coach's reasoning     │         │  `claude -p` process   │
   │  fresh context window) │      │  loop                  │         │  with cwd=site repo    │
   │                        │      │                        │         │  (a la bot-god)        │
   │  invocation: sync      │      │  invocation: inline    │         │  invocation: sync OR   │
   │                        │      │                        │         │  async via inbox       │
   └────────────────────────┘      └────────────────────────┘         └────────────────────────┘
```

---

## Tier 1 — Main coach (the orchestrator)

**Cwd:** `/Users/agni/Documents/rapidclaw/`
**Spawned by:** listener.js (per Slack turn) or run.sh (per cron fire)
**Context loaded:** CLAUDE.md + COMPANY.md + the active channels/<X>.md persona + definitions/skills.md + definitions/routines.md + auto-memory. **No skill bodies, no subagent system prompts.**

**Responsibilities:**
- Route the request: which domain subagent / site subagent / inline skill handles this?
- Apply permission gate (tier-based, per bootstrap)
- Post the final Slack reply (only the orchestrator posts back to the user-facing thread)
- Persist outcome to sqlite (routine_runs, etc.)

**Does NOT:** generate marketing copy, edit site code, compose newsletters, draft weekly wraps. Those are subagent jobs.

---

## Tier 2 — Domain subagents (capability scope)

Live in `.claude/agents/<name>/` at coach root. Each is a Claude Code subagent definition:

```
.claude/agents/distribution/
  SUBAGENT.md        # system prompt + tool allowlist + when to invoke
  references/        # per-brand strategy files, account lists, voice rules
  templates/         # post templates, draft schemas
```

Invoked by the main coach via the **Agent tool** (`subagent_type: distribution`). Runs in-process but with a fresh context window — only the subagent's references load. Returns a structured result the main coach uses.

| Subagent | Owns | Triggers it |
|---|---|---|
| `distribution` | growth-marketing (3 brands), marketing-recon/morning/evening, gtm-weekly-pick, biweekly-shoutouts | routines firing in #C0BBQ7PV34N, or owner asking "draft a LinkedIn post for Applighter" |
| `task-ops` | task-management — feeds `sites/tasks/` from #standup + #eod + #user-testing + git logs, runs tasks-cleanup scan | tasks-cleanup cron, owner asking "what's on my plate" |
| `newsletter` | drafts/newsletter-next/ → ship cycle, own memory + tracker | newsletter routine fire, owner asking "what's in the newsletter" |
| `weekly-wrap` | cross-channel weekly-wrap composition (already prototyped) | weekly-wrap trigger phrase, Fri afternoon cron |
| `user-testing` | daily diff of #user-testing → issues-log.md, sqlite user_testing_issues | user-testing-capture cron |

**Why these are subagents not skills:** each carries thick references (per-brand strategies, multi-source data, draft templates). Loading them all on every main-coach turn = the current hallucination problem. Scoping them to subagent context fixes it.

---

## Tier 3 — Inline skills (small, single-purpose)

Stay as `.claude/skills/<name>/` because they're light:

| Skill | Why inline | Storage |
|---|---|---|
| `leave` | sqlite CRUD + working-day guard. Small reference data. | sqlite leave_entries + holidays |
| `eod-nudges` | sqlite query + scheduled post. No big context. | sqlite eod_streaks |
| `scheduler` | sqlite CRUD for reminders + routine_runs. | sqlite reminders + routine_runs |
| `bug-tracking` | parse + append to sites/tasks/intake/bugs.md. Thin. | (part of task-ops if it grows) |
| `repo-edit` | procedural guidance (sites-prepare, branch, PR). No data. | none |

If any of these grow heavy, promote to a subagent.

---

## Tier 3' — Site subagents (repo scope)

Each linked site owns its agent definition inside the repo:

```
sites/<X>/
  .claude/
    agents/
      <X>-agent/
        SUBAGENT.md      # system prompt — this agent's voice, conventions, PR rules
        config.yaml      # model, timeouts (a la bot-god's config.yaml)
    skills/              # ALL the repo's skills — content-studio, design-system,
                         # creator-studio, bi-*, saas-*, etc. Only this subagent
                         # loads them.
```

**The main coach NEVER loads site-level skills directly.** When work needs to happen in a site repo, the main coach spawns the site subagent. Two invocation modes:

**Sync** — main coach spawns `claude -p --cwd sites/<X>/ -p "<task>"` as a subprocess (think: shell-out, not Agent tool). Waits for the subagent to finish. Captures stdout. Used for short tasks during a Slack turn ("generate the banner now").

**Async** — main coach drops a task JSON into `sites/<X>/.claude/agents/<X>-agent/inbox/`. A heartbeat cron (modelled on `bot-god`'s `bin/agent-heartbeat.sh`) picks it up, runs the subagent, commits results, posts back via Slack webhook. Used for multi-step work that may take minutes ("refactor the pricing page and open a PR").

| Site subagent | Repo | Owns |
|---|---|---|
| `rn-website-agent` | sites/rapidnative-website/ | all RN site skills (content-studio*, design-system, bi-*, saas-*, writing-style). Already has ~30 skills today. |
| `applighter-agent` | sites/applighter-website/ | creator-studio (NEW), content-studio variants for Applighter brand |
| `branding-agent` | sites/branding/ | strict AGENTS.md workflow (already documented) |
| `tasks-agent` | sites/tasks/ | THIS IS `bot-god` — formalize as `tasks-agent` per the new naming |
| `letsdeployit-agent` | sites/letsdeploy.it/ (future) | creator-studio + repo edits |

---

## Concrete examples — how a request flows

### Example 1: "Draft a LinkedIn banner for Applighter"

1. Main coach reads channel persona (#rapidnative-coach), tier (superadmin), and definitions/skills.md (which routes "banner generation" to site subagent).
2. Main coach calls `sites-prepare.sh applighter-website` (per CLAUDE.md rule for thread-scoped sites work).
3. Main coach spawns site subagent: `claude -p --cwd sites/applighter-website/ "Generate a LinkedIn banner per creator-studio/DESIGN.md. Topic: <X>."`
4. Subagent loads `sites/applighter-website/.claude/skills/creator-studio/DESIGN.md` + generates HTML + uses `gen-image.sh` or `render-html.sh`. Returns PNG path on stdout.
5. Main coach uploads to Slack via `slack-upload.sh` in the user's thread. Done.

### Example 2: Cron fires marketing-morning at 07:00 IST

1. launchd → `run.sh marketing-morning` → `claude -p` with `routines/marketing-morning.md` (≤80 lines, just orchestrator).
2. That coach instance invokes `distribution` subagent via Agent tool with task "morning task slate".
3. Distribution subagent loads its references/strategies/{rn,applighter,letsdeploy}.md + references/accounts/*.md + sqlite recon cache from earlier 06:00 run.
4. Subagent composes per-crew task drops. Returns structured list to coach.
5. Coach posts each top-level message to #C0BBQ7PV34N via slack-post.sh.

### Example 3: Owner asks "what's on my plate today?"

1. Main coach reads channel persona + sender tier.
2. Main coach invokes `task-ops` subagent ("summarize today's tasks for <@U0B4FCJ8Z1Q>").
3. Task-ops subagent queries `sites/tasks/` (read-only — grep for handle in planning/sprint.md).
4. Returns formatted list. Coach posts in the Slack thread.

### Example 4: Sanket asks "open a PR fixing the typo on the pricing page"

1. Main coach sees this needs site work in RN site.
2. Main coach spawns `rn-website-agent` ASYNC (long-running) by dropping a task JSON into the agent's inbox.
3. Heartbeat picks it up, makes the edit, commits, opens PR via gh CLI, posts PR URL to source thread via Slack webhook.
4. Main coach acknowledges in thread: "queued — agent will post the PR URL when done."

---

## What this changes vs the original plan.md

1. **The 12 goals split**: 5 become domain subagents (Tier 2), 5 stay as inline skills (Tier 3), 4 become site subagent invocations (Tier 3' — RN/Applighter/branding/tasks site agents).
2. **`bot-god` rename**: standardize as `tasks-agent`. Same code, new home as one of the site subagents.
3. **Heartbeat infrastructure** gets factored: borrow `sites/tasks/bin/agent-heartbeat.sh` pattern → a generic `accountability/routines/agent-heartbeat.sh <site>` that any site subagent can use.
4. **definitions/skills.md becomes definitions/agents-and-skills.md**: lists both kinds with a "when to invoke" decision tree.
5. **Phase 2 of the original plan** now reads: "migrate to subagents + skills (not just skills)". Order unchanged — distribution first, then task-ops, then user-testing, weekly-wrap, newsletter. Inline skills (leave, eod-nudges, scheduler, repo-edit) are quick wins, fold them in.

---

## Thread continuity — addressing Sanket's "but my conversation persists across messages" concern

(Added in response to thread reply `1782381161.253669`: "if I'm building a new feature for RapidNative website then my conversation currently on Slack maintains the whole context, message after message — I am not sure if that would work with subagents.")

Real concern. Here's how each invocation mode actually interacts with the listener's per-thread `--resume` session — and where the gap is.

### Today's continuity guarantee (don't break this)

`listener.js` saves `threadTs → session_id` in `~/.config/claude/rapidnative-coach-thread-sessions.json` (line 51). Every reply spawns `claude -p --resume <session_id>`. The Anthropic prompt cache keeps the conversation hot. Message N has full context from messages 1..N-1.

The refactor must preserve this for the main coach. The question is whether subagent invocations break it.

### Mode-by-mode analysis

**Mode 1 — Agent tool (Tier 2 domain subagents).** Subagent runs *inside one turn* of the main coach. It returns a structured result; main coach incorporates it and replies. Next thread message resumes the SAME main-coach session — full continuity preserved. **No continuity loss.** Same goes for Tier 3 inline skills.

**Mode 2 — Subprocess sync (Tier 3' site subagent, called within a turn).** Identical from the thread's perspective: main coach spawns the site subagent, waits, captures stdout, posts the reply. Thread-session-of-main-coach is untouched. **No continuity loss.**

**Mode 3 — Subprocess async (site subagent inbox + heartbeat, "go open a PR and ping me when done").** Continuity intentionally broken: the owner has explicitly handed off; main coach replies "queued"; subagent posts the PR URL back into the thread later from its own process. This is the desired behaviour for fire-and-forget.

**Mode 4 (THE GAP) — Sustained iterative work where the subagent itself needs turn-over-turn memory.** Example: "Let's build a pricing toggle." Five messages of "make it horizontal", "smaller padding", "no, the lighter color", "add the annual discount". If each turn the main coach calls `rn-website-agent` fresh, the subagent has no memory of "horizontal" by the time "lighter color" lands. That IS a regression versus today.

### Solutions for Mode 4

Three options, in order of complexity:

**Option A — Default: main coach keeps the thread; loads site skills inline (NO subagent).** For in-thread iterative dev work, the main coach itself does `sites-prepare.sh rn-website` and loads `sites/rapidnative-website/.claude/skills/<skill>/SKILL.md` directly. We give up site-skill context isolation in exchange for thread continuity. **For iterative dev work this is the right tradeoff** — the human IS the loop providing context anyway, so the isolation argument is weaker.

**Option B — Project / handoff mode (recommended for sustained work).** Explicit opt-in: owner says `/handoff rn-website` or `/work-on rn-website` (or first sustained-dev message triggers an offer "want me to put this thread in rn-website mode?"). Listener then maintains a parallel map `threadTs → { main_session, subagent_session_by_agent }`. Subsequent replies route directly to the site subagent with `--resume <subagent_session>`. The subagent owns the thread until `/done` or `/handback`. Symmetric to today's main-coach mechanism; just adds a routing key.

```jsonc
// ~/.config/claude/rapidnative-coach-thread-sessions.json (extended)
{
  "1782373569.212709": {
    "active_agent": "rn-website-agent",     // NEW — null = main coach
    "main_session": "abc-…",
    "subagent_sessions": {                  // NEW
      "rn-website-agent": "def-…"
    }
  }
}
```

**Option C — Proxy mode (skip unless we hit a real need).** Main coach receives every reply; passes thread context + new message to the subagent's resumed session; gets back a draft; reformats and posts. Most flexible (main coach can interject), most complex (double the LLM call per turn). Defer.

### Recommendation

- **Default behaviour:** Option A. Main coach handles in-thread iteration directly, loading whatever skills it needs inline (per-site skills via `sites-prepare.sh` + Read). Subagents are reserved for the cases where isolation matters more than continuity (cron-fired routines, async queued work, one-shot artifacts within a turn).
- **Opt-in for sustained dev:** Option B. Add `/handoff <agent>` and `/handback` commands to the listener. Use when a thread is going to be 10+ messages of subagent-owned work and the user explicitly wants the subagent's context to persist.
- **Skip Option C** until a concrete use case forces it.

### Updated routing decision tree

When the main coach receives a Slack message, it decides per-turn:

```
1. Is this thread in handoff mode (active_agent != null)?
   → route to that subagent's --resume session. Done.
2. Is the request a one-shot artifact (banner, single draft, render)?
   → call subagent via Agent tool OR subprocess; result returns to main coach;
     main coach posts; main-coach session continues. Thread continuity preserved.
3. Is the request "go do this, ping me when done"?
   → async site subagent (inbox + heartbeat). Main coach replies "queued".
4. Is the request iterative dev/content work in-thread?
   → main coach handles directly. Loads site skills inline via sites-prepare +
     Read. Thread continuity preserved; context-isolation deliberately
     sacrificed.
5. Otherwise (normal conversation, planning, questions)?
   → main coach handles directly. May call inline skills.
```

### What this changes in the plan

- Tier 2 / Tier 3 / Tier 3' descriptions stay. The MODE of invocation is what's clarified.
- Listener.js gains:
  - extended thread-session schema (active_agent + subagent_sessions map)
  - `/handoff <agent>` / `/handback` command parsing
  - routing logic per the decision tree above
- Documentation: bootstrap-prompt.md Step 1 reading list includes "if the thread is in handoff mode, you ARE the handed-off subagent — don't try to act as the orchestrator"

---

## Open questions added by this addendum

8. **Sync vs async default for site subagents:** I propose sync by default (faster feedback), async only when the task body says "open a PR" or main coach estimates >2 min of work. OK?
9. **Heartbeat infra ownership:** keep `bin/agent-heartbeat.sh` inside each site repo (per bot-god today), or centralise in `accountability/routines/`?
10. **Subagent definition format:** Claude Code's `.claude/agents/<name>.md` (single file with frontmatter) vs the directory form bot-god uses (system-prompt.md + config.yaml). I lean directory for parity with bot-god; ok?
11. **Should domain subagents have their own auto-memory** (per-subagent learnings file), or all funnel back to coach-level auto-memory?
12. **Handoff mode UX:** explicit `/handoff <agent>` command vs the main coach offering it proactively ("this looks like sustained rn-website work — want me to switch the thread to rn-website-agent for the rest of it?"). I lean proactive offer + explicit accept.
13. **Handoff exit triggers:** `/handback` explicit, or auto-handback after N minutes of inactivity, or auto on detected scope-change ("can you also check the leave file" → leave is not rn-website scope, handback)?

---

## Decisions on 8/9/10/11 (locked in by @sanket on 2026-06-25 reply `1782382397.400179`)

**Q8 — Site subagent default mode:** **sync.** Async only when the task literally needs to span minutes (open a PR while owner is away). Subprocess returns to main coach; coach posts.

**Q9 — Heartbeat infra:** **centralised** in `accountability/routines/agent-heartbeat.sh` (or similar). The pattern factors out of `sites/tasks/bin/` into one driver that any site subagent can register against. Per-site dirs (`sites/<X>/.claude/agents/<X>-agent/inbox/`) still hold the queues; only the driver is shared.

**Q10 — Subagent definition format:** **Claude Code's standard.** Single file at `.claude/agents/<name>.md` with YAML frontmatter (name, description, tools, model). Drop bot-god's directory form when migrating it to `tasks-agent`. Per-task workspace creation and pause flags can still live alongside the agent file; just the *definition* is one file.

**Q11 (originally about per-subagent auto-memory):** **Claude Code's standard.** Auto-memory is per-project (the existing `~/.claude/projects/<encoded-cwd>/memory/`). When a site subagent spawns with `cwd=sites/<X>/`, it gets that site's auto-memory dir. No special per-subagent memory mechanism. Coach-level auto-memory at coach's cwd; each site agent gets its own at the site's cwd. Natural by-product of the cwd-based mechanism, no extra config needed.

---

## Decisions (locked in by @sanket on 2026-06-25 reply `1782381840.683309`)

**Q11 — Handoff trigger:** **Explicit only.** Main agent MAY ask if it thinks handoff would help, but the user must explicitly accept. **Slack slash commands (`/handoff`) do NOT work** — Slack intercepts `/` for its own slash-command system and our bot never sees them. Use a non-slash trigger.

**Q12 — Handback trigger:** **Both auto + explicit.** Auto-handback fires on detected scope drift (subagent's responsibility to detect — see below). Explicit handback always available as a fallback.

**Q13 — Visibility:** **Always visible.** Every bot reply during handoff must clearly identify which agent is responding. The handoff and handback events themselves get explicit marker messages in the thread.

### Resulting trigger syntax (no slash commands)

**Handoff (user → coach):** any of these in a message body
- natural language: *"handoff to rn-website"*  ·  *"hand this thread to applighter-agent"*  ·  *"switch to tasks-agent"*
- regex-detectable marker (for power users): `handoff: rn-website` on its own line, or `!handoff rn-website` anywhere

Listener parses the marker form deterministically before spawning. Natural-language form is detected by the main coach in-LLM. Either path lands at the same routing change.

**Handback (user → coach):** same idea
- natural language: *"handback"*  ·  *"back to main"*  ·  *"done with rn-website"*  ·  *"exit handoff"*
- marker: `handback` on its own line

**Handback (auto, subagent → coach):** the active subagent self-detects scope drift and emits a structured event (e.g. final stdout line `HANDBACK_REASON: <one line>`) that the listener acts on. Cases:
- the question isn't about this agent's domain (e.g. user asks "who's on leave?" while in rn-website handoff)
- the agent has nothing more to do ("✓ PR opened, handing back")

### Visible handoff UX (exact format)

**At handoff entry (one-time marker):**
```
🔁 *Thread handed off to rn-website-agent.*
> This agent owns the conversation now — every reply in this thread goes to it
> with full conversation memory. Say "handback" anytime to return to the main coach.
```

**On every subagent reply during handoff (prefix header):**
```
📨 *rn-website-agent* · handed-off mode

<the actual response>
```

**On auto-handback (subagent-initiated):**
```
🔁 *Handed back to main coach.*
> rn-website-agent: <handback reason — one line>
```

**On explicit handback (user-initiated):**
```
🔁 *Handed back to main coach.*
> Was: rn-website-agent.
```

### Listener implementation impact

1. **Parse handoff/handback markers** before spawning claude:
   ```js
   const HANDOFF_RE  = /(?:^|\n)\s*!?handoff\s+([a-z-]+-agent)\b/i;
   const HANDBACK_RE = /(?:^|\n)\s*!?handback\b/i;
   ```
   If a marker matches, flip `active_agent` in the thread-sessions JSON BEFORE spawning the next claude — so the right routing key is set when the coach/subagent starts.

2. **Route on `active_agent`** — when non-null, spawn `claude -p --cwd sites/<X>/ --resume <subagent_session>` instead of the main-coach session. Subagent's own session_id captured on first run, stored in `subagent_sessions[<agent>]`.

3. **Always prepend the visibility header** to subagent replies. Subagent's SUBAGENT.md system prompt requires it; listener also enforces (regex-check the outgoing payload and prepend the header if the agent forgot — belt + suspenders).

4. **Handback event from subagent:** subagent prints `HANDBACK_REASON: <reason>` as its final stdout line. Listener detects, posts the auto-handback marker, sets `active_agent = null`.

5. **No proactive auto-handoff** — main coach can SUGGEST handoff in a reply ("this looks like 5+ turns of rn-website work; want me to hand the thread to rn-website-agent? Reply 'handoff rn-website' to switch."), but never flips the routing key without an explicit user message.
