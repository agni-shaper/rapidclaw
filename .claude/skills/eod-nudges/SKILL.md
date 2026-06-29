---
name: eod-nudges
description: Detect teammates who haven't posted an EOD update in #eod-updates today and ping them. Leave-aware (uses the `leave` skill); skips weekends/holidays.
when_to_load: |
  Load when ANY of the following:
  - Cron routine `eod-streak-check` fires (19:00 IST Mon-Fri)
  - User asks "who hasn't posted an EOD today?" / "ping the EOD slackers"
  - User asks to check a teammate's EOD streak / record
voice_source: ../../profile.md
---

# eod-nudges

Drives the daily 19:00 IST end-of-day nudge in `#eod-updates` (`C0A8Q9HM5BN`). Reads who posted today, who didn't, and pings the no-shows — with full leave + holiday awareness so nobody gets pinged unfairly.

## Read these before doing any work

Already loaded by bootstrap, just re-anchor to:

- `definitions/people.md` — roster (who counts as a teammate)
- `definitions/channels.md` — `#eod-updates` channel id (`C0A8Q9HM5BN`)
- `channels/eod-updates.md` — channel persona + tier (teammate-tier; non-superadmin posts allowed)

Load this skill's complement:

- `../leave/SKILL.md` — for the `is_on_leave` contract (don't ping anyone covered by today's IST date)

## The protocol

Step 0 — guard:
```bash
source accountability/routines/_lib.sh
guard_working_day eod-nudges   # exits 0 on weekends + IST holidays
```

Step 1 — for each `<@SLACK_ID>` in `definitions/people.md` with `Kind: human` and `Tier ∈ {owner, superadmin, teammate}`:

```bash
is_on_leave "<@$SID>" && continue   # silent skip on leave
# (or sqlite_is_on_leave — same exit-code contract, Phase 3 LIVE)
```

Step 2 — check whether they posted a top-level message in `#eod-updates` within the last **3 working days** (the threshold; raised from 2 on 2026-06-30):

```bash
CUTOFF=$(n_working_days_ago 3)              # YYYY-MM-DD IST — strictly-before-this = stale
WINDOW_START=$(n_working_days_ago 4)        # one extra working day for safety margin
# Fetch channel history back to WINDOW_START via Slack API conversations.history.
# Top-level messages only; thread replies don't count.
```

A teammate is **stale** iff their most recent top-level post's IST date is strictly before `$CUTOFF`. No posts in the window → stale by default.

Step 3 — compose the nudge. Voice:

- Concise. No "Hey team!". Direct.
- One ping per person (group ping > individual DMs unless a teammate has 3+ misses this week).
- Don't moralize. State the fact.

Example:
```
EOD missing today: <@U09CXCYV7D1> <@U09CUJ9ATM1>
```

(Note: use `<@U...>` form, not `@handle` text, so the ping actually notifies.)

Step 4 — post to `#eod-updates` as a top-level message (not a thread reply).

Step 5 — record the streak in sqlite (Phase 3) or — until Phase 3 — log to a runtime journal at `accountability/state/eod-streaks-YYYY-MM.md`.

## Streak handling

Phase 3 sqlite schema (proposed):

```sql
CREATE TABLE eod_streaks (
  slack_id    TEXT NOT NULL,
  date        TEXT NOT NULL,  -- YYYY-MM-DD IST
  posted      INTEGER NOT NULL,  -- 0/1
  on_leave    INTEGER NOT NULL,  -- 0/1 (so streaks don't reset on legit absences)
  PRIMARY KEY (slack_id, date)
);

CREATE INDEX idx_eod_recent ON eod_streaks(date DESC);
```

Until then, the routine just pings; streak tracking is best-effort.

## Anti-misfire rules

1. **Never ping someone on leave.** `is_on_leave` is a hard gate.
2. **Never ping on a non-working day.** `guard_working_day` covers weekends + holidays.
3. **Don't ping the bot itself.** Exclude `@bot-god` and the rapidnative-coach owner (`@agni`) from the human roster — neither posts EOD updates.
4. **Don't double-ping.** Scan today's channel history for a prior message from this bot containing the substring `*EOD nudge*` (the unique bold phrase). **Don't grep for the literal `👋` emoji** — Slack's history API returns it as the `:wave:` shortcode and a literal-unicode match fails. The bold phrase works for both encodings.
5. **If nobody missed EOD, post silently** — either skip entirely or post a one-line positive ("Everyone EOD'd today."). Default: skip; tunable.

## When a user asks "who's behind on EODs?"

1. Run the protocol above WITHOUT posting (read-only).
2. List the people with the day-count of each ("@riya missed Mon-Wed; @rishav missed Wed").
3. Don't ping in the response (the routine is the one that pings — ad-hoc requests are read-only).

## Migration status

- **Today:** runs via `accountability/routines/eod-streak-check.md` (84 lines). That routine should shrink to ≤80 lines and load this skill (replacement pending; safe to do anytime since the routine is small and easy to test).
- **Phase 3:** sqlite `eod_streaks` table replaces any markdown projection of streak data.

## Voice when reporting EOD status (non-routine ad-hoc requests)

- Specific. "Riya missed Mon-Wed (3 days)" not "Riya is behind".
- Acknowledge leave when relevant. "@famitha was on leave Jun 11-12, missed Jun 13 only."
- Don't escalate ("you should talk to her"). Just report.

## Related skills

- `leave` — `is_on_leave` is consumed here
- `task-management` (Phase 2) — bug-report nudges also use this leave-aware pattern
