---
name: user-testing
description: Maintain `accountability/user-testing/issues-log.md` by diffing recent activity in #user-testing against the existing log. Proposes additions to the log + new bug tasks; owner approves before mutation.
when_to_load: |
  Load when ANY of the following:
  - Cron routine `user-testing-capture` fires (daily, 10:00 IST)
  - User asks "what are the top user-testing issues?" / "summarize this week's user-testing"
  - User asks "what's new in #user-testing?"
  - Someone replies in a tasks-cleanup proposal thread with a user-testing-related change
voice_source: ../../profile.md
---

# user-testing

Owns the projection from `#user-testing` (channel `C09EU7C87BM`) → `accountability/user-testing/issues-log.md`. Read-only against the channel; write-only against the log (after approval).

## Read these before doing any work

1. `accountability/user-testing/README.md` — the team's own conventions for how the log is structured.
2. `accountability/user-testing/issues-log.md` — current open rows (summary + testers-hit count + priority + status).
3. `channels/user-testing.md` — channel persona + voice.
4. `definitions/people.md` — for Slack ID → handle lookups.

## The daily capture flow

```
0. guard_working_day user-testing-capture
   (Skip silently on weekends + IST holidays. The channel itself doesn't go on leave;
    the people responding to it do.)

1. Fetch the last ~36 hours of #user-testing messages via Slack API:
   curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
     "https://slack.com/api/conversations.history?channel=C09EU7C87BM&oldest=$SINCE_TS&limit=50"

2. For each new message:
   - Skip the bot's own messages
   - Skip thread replies (only top-level messages count as new observations)
   - Extract: poster, timestamp, content, any image attachments

3. Diff against issues-log.md:
   - Does this match an existing row? (semantic match on summary or screen-name keywords) → increment testers-hit count + add a "Last seen: <date>" note
   - No match → propose as a NEW row

4. Compose a PROPOSAL (not a commit) and post to #rapidnative-coach:
   *User testing capture* <date>
   - <NEW> rows to add
   - <UPDATE> rows to bump (testers-hit count or status)
   - <CLOSE> rows to mark resolved (if a teammate explicitly said "fixed in X")

5. Save proposal JSON to accountability/state/user-testing-proposal-<reply_ts>.json
6. WAIT for approval. Approval semantics same as tasks-cleanup: super-admin only.
7. On approval, edit issues-log.md + commit on the coach repo (not tasks repo — the log
   lives in the coach repo).
```

## When the user asks "what are the top user-testing issues?"

1. `Read accountability/user-testing/issues-log.md`.
2. Filter to open status; sort by testers-hit count desc.
3. Return top 5-10 with: summary, hit count, priority, who reported, last seen date.
4. Don't include closed/resolved rows unless explicitly asked.

## When a #user-testing observation also looks like a bug

If the message clearly describes a reproducible bug (not just a UX nit), include it in BOTH this skill's proposal AND the `bug-tracking` skill's proposal. The latter feeds `sites/tasks/intake/bugs.md`.

The line between "UX issue" and "bug":

- UX issue (this skill only) — "this is confusing", "I didn't know what to click", "the wording was unclear"
- Bug (both skills) — "the button doesn't work", "I get error X", "page Y crashes when I do Z"

## Anti-hallucination guards

1. **Don't paraphrase observations into the log.** Quote the original or paraphrase tightly; preserve specifics (screen names, error messages, the user's exact words). Speculation belongs in the team discussion, not the log.
2. **Don't assign blame.** Issues-log is a flat record of what was observed, not a critique of the engineer who built it.
3. **Don't merge two observations into one row unless they're clearly the same issue.** When in doubt, propose them as separate rows — easier to merge later than split.
4. **Image attachments matter.** If a teammate uploaded a screenshot, note `[screenshot attached: <description>]` in the row; don't drop visual evidence.

## Migration status

- **Today:** runs via `accountability/routines/user-testing-capture.md` (108 lines). Replacement pending; small enough to migrate quickly.
- **Storage:** `accountability/user-testing/issues-log.md` stays the source of truth. The empty `user_testing_issues` sqlite table was dropped 2026-06-30 — at current scale (single-digit rows, team eyeballs the markdown table) sqlite added zero value. If the log ever grows past ~30 rows or needs structured filtering, revisit.

## Related skills

- `task-management` — bugs from this skill become tasks in `sites/tasks/`
- `bug-tracking` — for the "this is a reproducible bug" subset of observations
- `growth-marketing` — strong UX issues sometimes warrant a blog post or social comment ("we fixed X based on user feedback") — defer to growth-marketing for that drafting
