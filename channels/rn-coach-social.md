---
channel_id: C0B6Q8TUVL2
name: rn-coach-social
purpose: Social engagement workspace for rapidnative-coach — scheduled scans surface candidate posts on X/LinkedIn/Reddit, the owner reviews and ships originals from here. Engagement-only; no accountability, blogs, or user-testing posts land here.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: [engagement]
---

# Purpose

Dedicated home for the `engagement` routine. The bot scans X (primary), LinkedIn, and any other platform listed in `profile.md`, scores posts against the bot's pillars, and lands 2-3 candidate cards per scan as top-level messages with threaded detail (drafted text, screenshot, intent URL).

Splitting this out of `#rapidnative-coach` keeps the main channel focused on accountability/check-ins/blog reports and gives the owner a clean review surface where every message is "post or skip this draft."

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

# Notes for the bot

- Posting target for the engagement routine is this channel (`C0B6Q8TUVL2`), not `#rapidnative-coach`. The routine file and helpers are the source of truth for the channel ID — don't hardcode it in ad-hoc work.
- Scoring uses pillars defined in `profile.md`. If pillars change, the next scan reflects them — no extra wiring.
- Bot Chrome lifecycle: open tabs via `browser-open.sh`, close just the opened tabs with `browser-use tab close` at the end (NEVER `browser-use close` — that kills the bot Chrome and forces a slow relaunch).
- LinkedIn / Reddit candidates land here too. They use the same 1-line + thread pattern but the thread reply is a code-block draft (for one-click copy) plus a clickable link to the original — the owner pastes manually since those platforms don't have an intent URL equivalent.
- Cleanup: per `engagement.md`, the closer line ("N candidates above… what's one original you'd ship today?") posts here too, not in `#rapidnative-coach`. Every part of one scan stays in one channel.
