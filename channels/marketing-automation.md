---
channel_id: C0BBQ7PV34N
name: marketing-automation
product: all
owner: <@U09DC8L7PCZ>
members: [<@U0B4FCJ8Z1Q>, <@U09DC8L7PCZ>, <@U09CUJ9ATM1>, <@U09DFJJGS1X>, <@U09LL9JTDM5>]
purpose: Distribution + growth crew daily-task drops. Bot posts per-crew morning task slates here; teammates reply in-thread with done-claims; bot's evening routine parses + recaps.
voice_source: profile.md
publish_tier: superadmin
allowed_routines: [marketing-morning, marketing-evening, marketing-recon, blog-internal]
allowed_skills: [growth-marketing, leave]
---

# Purpose

This is the operational channel for the **growth-marketing** crew (the Growth Squad v2). It's where the bot's daily distribution cycle lives:

| Routine | Time (IST) | What lands here |
|---|---|---|
| `marketing-recon` | 06:00 Mon-Fri | (nothing — recon writes a cache only) |
| `marketing-morning` | 07:00 Mon-Fri | One top-level message per crew member with today's slate |
| `marketing-evening` | 19:30 Mon-Fri | One top-level EOD recap per crew member |
| `blog-internal` | 12:00 daily | Editorial post + clean task message for @famitha + @russel |

# Voice

Bot-to-crew voice — direct, taskable, no fluff. From `profile.md`: no em-dashes, no buzzwords, no "let me know if I can help".

Per-crew messages format (see `.claude/skills/growth-marketing/SKILL.md` for canonical):

```
*<crew member>* — today's slate (<date>)

T01 · <task description> · <link/account>
T02 · <task description> · <link/account>
...
```

# Scope

ONLY:
- Daily distribution-task drops + EOD recaps
- Blog amplification clean-task pings
- Crew thread replies (done-claims, blockers)

NOT here:
- General marketing strategy (use #marketing)
- Specific GTM picks (use #marketing — gtm-weekly-pick posts there)
- Newsletter coordination (TBD — newsletter skill is design-only)

# Notes for the bot

- The bot uses `<@U…>` member-id form for all pings (never `@handle` text).
- On-leave crew are silently skipped (per `sqlite_is_on_leave`).
- The morning routine writes a sentinel at `marketing/.state/morning-ts-YYYY-MM-DD.json` keyed by Slack ID → parent message ts. The evening routine reads this to know which threads to parse.
- If a teammate isn't in the `definitions/people.md` "Active" list (or its skill-side mirror at `.claude/skills/growth-marketing/references/accounts.md`), they don't get a slate. To onboard a new crew member, edit BOTH files until the legacy `marketing/` is deleted in a future commit.
