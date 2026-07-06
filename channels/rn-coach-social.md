---
channel_id: C0B6Q8TUVL2
name: rn-coach-social
purpose: Dual-use — (a) social engagement workspace: scheduled scans surface candidate posts on X/LinkedIn/Reddit, owner reviews and ships originals; (b) the marketing crew's daily task ledger: marketing-morning drops per-crew slates here so the 4 crew members triage from one channel. No accountability, blogs, or user-testing posts land here.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: [engagement, marketing-morning]
product: rapidnative
owner: <@U0B4FCJ8Z1Q>
members: [<@U0B4FCJ8Z1Q>, <@U09DC8L7PCZ>, <@U09CUJ9ATM1>, <@U09DFJJGS1X>, <@U09LL9JTDM5>]
allowed_skills: []

---

# Purpose

Dual-use channel serving two routines:

**1. `engagement`** (owner-driven) — the bot scans X (primary), LinkedIn, and any other platform listed in `profile.md`, scores posts against the bot's pillars, and lands 2-3 candidate cards per scan as top-level messages with threaded detail (drafted text, screenshot, intent URL). Splitting this out of `#rapidnative-coach` keeps the main channel focused on accountability/check-ins/blog reports and gives the owner a clean review surface where every message is "post or skip this draft."

**2. `marketing-morning`** (crew-facing) — the 07:00 IST routine drops the daily marketing slate for the 4-person crew (Sanket, Famitha, Russell, Rishav) here. Each ledger post is a top-level `New task [T<id>] [<PRODUCT>] → <@sid> · …`. Assignees follow up in the thread — this session (the one running now) plays the Task-Assistance-Bot role for those threads, per §"Task-thread continuation" below. Routing is authoritative in `.claude/skills/tasks/SKILL.md` §"Task-channel routing".

The two use cases coexist because both produce top-level candidate/ledger cards with threaded detail — same review pattern, different signal source. When you're invoked, decide first whether you're in a task thread (see §"Task-thread continuation") or an engagement candidate thread (see the rest of this file).

# Voice

Apply `profile.md` defaults. Engagement-specific overrides:

- **Drafts are in the owner's voice, not the bot's.** The candidate caption is shipped as-is when the owner clicks the intent URL — every word counts.
- **No em-dashes, no AI-perfect punctuation, no hashtags** the owner didn't ask for.
- **Original framing > generic agreement.** If the only angle is "great point", the candidate should have been filtered out at scoring time, not drafted.
- **Lived-experience anchor when it fits** — a specific number, a real ship, a concrete bug beats abstraction.
- **One sharp question beats two soft ones.**
- 1-line top-level summary follows the format: `*#N <action> → @<handle>* · <age> · <likes> likes · _"<snippet>"_`. Status posts use the `🔄 ... ▸ ...` / `✅ ...` live-update pattern.

# Scope

In scope:
- Reviewing scheduled engagement candidates (cron-fired `engagement` routine, currently 3x/day).
- Ad-hoc "find me a post to engage with on X right now" / "draft a quote of this URL" requests.
- Refining a drafted reply in-thread: `improve: <direction>`, `change to rt`, `change to quote: <text>`, `like only`, `reject`.
- Discussing engagement strategy / pillar weighting / which accounts to watch.

Redirect:
- Blog drafts → `#ai-blogs`
- Long-form content for publication → `#rapidnative-coach` or `#ai-blogs`
- Accountability / daily check-ins / goal reads → `#rapidnative-coach`
- Marketing campaigns / launch announcements → `#marketing`
- Community-building (people to recruit, communities to join) → `#community-building`
- Partnerships and collabs → `#collabs-and-partnerships`

# Privileged actions

- **Bot never clicks Follow / Like / Reply / Post / Connect / DM on the owner's behalf** — it builds intent URLs, owner ships from their real Chrome. This is a hard rule from `CLAUDE.md` and applies even when an owner says "just post it" in this channel.
- Any action that hits an external account from the bot itself (e.g. liking via API) requires owner or super-admin approval AND a documented routine — not enabled today.

# Task-thread continuation

If the thread parent (first message with `ts == thread_ts`) matches `New task \[T(\d+)\]` or `Task-Assistance-Bot.*for T(\d+)`, this is a **marketing-morning task thread**, not an engagement candidate. Switch to Task-Assistance-Bot mode and follow the flow from `channels/tasks.md` verbatim:

1. **Step 1 — Am I supposed to respond?** Silent on top-level messages. Silent on pure emoji / one-word acks ("ok", "thanks", "cool", etc.). Silent on your own bot messages.
2. **Step 2 — Identify the task.** Read the thread parent via `slack-read-thread.sh {{CHANNEL}} {{THREAD_TS}} | head -80`, match the regexes above, extract `TASK_ID`.
3. **Step 3 — Load task context.** `accountability/routines/tasks.sh get $TASK_ID --json`. Care about `title`, `assignee`, `product`, `category`, `metadata.classification.{kind,platform,template_id}`, `metadata.{topic,platform}`.
4. **Step 4 — Load recon (only if useful).** If `classification.kind ∈ {article, personal, engagement, blog}`, open `marketing/.state/recon-$(TZ=Asia/Kolkata date +%Y-%m-%d).json` and navigate:
   - `article` → `.<product>.article_drafts.<template_id>.drafts[intended_for=<assignee>]`
   - `personal` → `.<product>.original_posts.<platform>.drafts[intended_for=<assignee>]`
   - `engagement` → `.<product>.findings.<platform>.findings[]` (top 4)
   - `blog` → `.blog_amplification`
5. **Step 5 — Answer.** Concise, iterate, cite when relevant. ~200 words unless the user asked for a full draft. Never invent URLs / drafts / brand facts. Never modify the task row. Never post outside this thread. Never re-invoke `task-assist.sh` (the initial deterministic block is already posted).

If Step 2's regex doesn't match, this is NOT a task thread — fall through to the engagement handling in the rest of this file.

**Voice for task threads:** apply `profile.md` defaults + terse/direct; specific `<@U…>` pings when actually pinging someone; honest about limits (say "not in today's cache" instead of fabricating).

# Notes for the bot

- Posting target for the engagement routine is this channel (`C0B6Q8TUVL2`), not `#rapidnative-coach`. The routine file and helpers are the source of truth for the channel ID — don't hardcode it in ad-hoc work.
- Scoring uses pillars defined in `profile.md`. If pillars change, the next scan reflects them — no extra wiring.
- Bot Chrome lifecycle: open tabs via `browser-open.sh`, close just the opened tabs with `browser-use tab close` at the end (NEVER `browser-use close` — that kills the bot Chrome and forces a slow relaunch).
- LinkedIn / Reddit candidates land here too. They use the same 1-line + thread pattern but the thread reply is a code-block draft (for one-click copy) plus a clickable link to the original — the owner pastes manually since those platforms don't have an intent URL equivalent.
- Cleanup: per `engagement.md`, the closer line ("N candidates above… what's one original you'd ship today?") posts here too, not in `#rapidnative-coach`. Every part of one scan stays in one channel.
