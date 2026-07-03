---
name: task-assistance
description: On-demand bot that assists a task's assignee with platform-specific research and content drafts. Given a task like "Post on Quora for RapidNative", it looks up today's marketing-recon cache, finds the matching thread suggestions + reply drafts, and posts them as a thread reply under the task's Slack notification. Runs via `accountability/routines/task-assist.sh <task_id>`.
when_to_load: |
  Load when ANY of the following:
  - User in Slack says: "assist T142" / "help me with T142" / "give assistance for task 142" / "recon for T142"
  - User asks in the task's own thread: "what should I post here?" / "any suggestions?" / "help"
  - User invokes the shell script directly and needs to know what it does
voice_source: ../../profile.md
---

# task-assistance

A per-task assistance layer that sits on top of the sqlite `tasks` table and the daily marketing-recon cache. It does NOT own writes to the tasks table; it only reads a task, classifies it, and posts a helpful thread reply.

## What it can help with today (Phase 1)

- **Community engagement tasks** (HN / Reddit / Quora / LinkedIn / Twitter / Facebook / Community forums) — surfaces the top 3–4 thread findings from `marketing-recon` for that product × platform, each with a suggested reply draft.
- **Personal-account posts** (LinkedIn / Twitter / Quora personal) — surfaces the LLM-drafted post text the recon prepared for THIS assignee (matched by Slack ID via `intended_for`), plus an angle and — for Quora — the specific question URL to answer.
- **Article submissions** (GFG / Medium / Hashnode / dev.to / Substack / Vocal / LinkedIn long-form) — surfaces the full outline + draft body from `recon.<product>.article_drafts.<TPL-*>.drafts[intended_for=<assignee>]`.
- **Blog amplification tasks** ("Publish a blog for X") — surfaces the blog URL + suggested social caption from `recon.blog_amplification`.

## What it can't help with today (deferred)

- **Ad-hoc / non-marketing tasks** ("review Riya's work", "book flight", bug reports) — Phase 2 will call an LLM on-demand for these. Today the bot posts "No pre-computed assistance" with a reason.
- **Quota-only tasks** ("Write 6 articles for Distribution") — no target platform, no thread to enrich. The bot skips these.
- **Tasks created without `--notify`** (no `slack_message_ts` on the row) — no parent post to thread-reply under. The bot refuses with a clear error.
- **Fresh scraping** when the recon cache is stale or missing — Phase 3.

## How to invoke

**Shell (any time):**

```bash
accountability/routines/task-assist.sh <task_id>            # post to Slack
accountability/routines/task-assist.sh <task_id> --dry-run  # print the message + metadata, no Slack post
```

**Slack (via this skill):** when a teammate types something like *"assist T142"* or *"help me with T142"* in `#tasks` or in the task's own thread, load this SKILL.md and run the shell script.

## What gets posted

A thread reply under the task's original `slack_message_url`, formatted as:

```
:robot_face: *Task-Assistance-Bot* — for T142

*Suggested Quora posts* — pick 1–2 to reply to (skim the rest for context):

*1.* <https://quora.com/…|Why did Apple reject my app?>
    _(context: 12 answers, 3 months old)_
    💬 *Suggested reply:* "Rejection code 2.1 is usually…"

*2.* <https://quora.com/…|How do I integrate Stripe with React Native?>
    _(context: 5 answers, 2 weeks old)_
    💬 *Suggested reply:* "The RN Stripe SDK's `useStripe` hook…"

_letsdeployit · marketing_
```

## Anti-hallucination guards

1. **Never invent thread URLs or reply text.** Everything in the assistance block comes from the recon cache. If the cache has nothing, post the "No pre-computed assistance" fallback with a reason — don't fabricate.
2. **Never edit the task itself.** This bot is read-only against sqlite `tasks` (with one exception: it writes its own metadata into the row's `metadata` JSON column so the Kanban UI can render the assistance later without re-posting to Slack). It never touches `title / assignee / status / priority / etc.`.
3. **Never post outside the task's own thread.** The whole point is to keep the ledger clean. Assistance is a thread reply under the parent — never a new top-level in `#tasks`.
4. **Never re-post assistance for the same task twice** without user confirmation. Re-invocations should first check `metadata.assist_posted_ts` (set on first successful post) and warn if it's already there.
5. **Only match `intended_for` against the task's assignee.** Recon prepares drafts per Slack ID; posting another person's LinkedIn draft would be misleading.

## Composes with

- `tasks.sh get <id> --json` — read the task
- `slack-post.sh` — post the thread reply
- `_lib.sh` — sqlite helpers for the metadata stash
- `marketing-recon` output (`marketing/.state/recon-<date>.json`) — the source of all suggestions today
- Kanban UI (`tasks-ui/`) — future: renders the metadata block in the flyout when Phase 2 wires the API

## Files

- `accountability/routines/task-assist.sh` — the shell entry point
- `accountability/routines/gen-task-assistance.py` — Python helper (JSON parsing, classification, formatting)
- `.claude/skills/task-assistance/SKILL.md` — this file
