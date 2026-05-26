You are running the daily user-testing capture for rapidnative-coach. Fires once daily. **Read `profile.md` and `accountability/user-testing/README.md` first** — they define voice and the workflow this routine automates.

## Job (one fire)

Diff recent activity in **#user-testing** (channel `C09EU7C87BM`) against `accountability/user-testing/issues-log.md`, then post a *proposal* (not a commit) to **#rapidnative-coach** (channel `C0B4HG16QP3`) for the owner to confirm.

You never write to the log or the tasks repo unattended. The owner replies "apply" / "go" and the listener spawns a fresh claude that applies the changes.

## Step 1 — read the log

```bash
cat accountability/user-testing/issues-log.md
```

Understand the current open rows: short summaries, testers hit counts, priorities, statuses.

## Step 2 — read recent #user-testing activity

Pull the last ~36 hours of messages from the channel:

```bash
SINCE=$(date -v -36H +%s)
curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  "https://slack.com/api/conversations.history?channel=C09EU7C87BM&oldest=$SINCE&limit=50" \
  | tee /tmp/ut-history.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('messages',[])), 'msgs')"
```

For any message that has `thread_ts` and `reply_count > 0`, also pull the thread via `accountability/routines/slack-read-thread.sh C09EU7C87BM <thread_ts>` so you see the full context, not just the top-level post.

Ignore: pure scheduling chatter ("rescheduling Tuesday's session"), recruitment outreach drafts, links-only messages with no observation content. Focus on: observations from actual sessions, verbatim quotes, posted notes.

## Step 3 — extract candidate issues

For each session/thread that surfaces issues, list them as discrete items. Each candidate has:

- short summary (one line, ≤80 chars)
- tester initials (from the thread context; use `??` if unknown — flag it)
- a guessed priority based on severity language ("blocker", "crash", "couldn't recover" → P0; "confused but figured it out" → P2; etc.)
- a one-sentence rationale (so the owner can sanity-check)

## Step 4 — dedup against the log

For each candidate, decide:

- **Match an existing open row** → propose `INCREMENT row #N: testers hit X+1, append <initials>, re-evaluate priority`.
- **No match** → propose `NEW row: <summary> | <date> | 1 (<initials>) | <priority> | raw | —`.

Use semantic match, not literal — *"signup CTA invisible on dark mode"* and *"can't see the sign-up button at night"* are the same row. When in doubt, present both and let the owner decide.

## Step 5 — flag promotion-eligible rows

After applying the proposed changes (hypothetically), any row that crosses the promotion threshold should be flagged:

- `testers hit ≥ 2` after this batch, **or**
- new row created at `P0` or `P1`.

For each flagged row, suggest the destination in `sites/tasks/`:

- bug-shaped (crash, broken behavior) → `/add-bug` → `intake/bugs.md`
- qualitative quote / sentiment → `/add-feedback` → `intake/feedback.md`
- direct task → `/new-task` then `planning/backlog.md` with `#user-testing #bug`

## Step 6 — post the proposal

One top-level message to #rapidnative-coach. Format:

```bash
accountability/routines/slack-post.sh C0B4HG16QP3 <<'EOF'
*User testing capture* — $(date '+%Y-%m-%d')

Scanned <N> messages / <M> threads in <#C09EU7C87BM> since yesterday.

*Proposed log updates*
1. INCREMENT row #3 (onboarding CTA invisible on dark): testers hit 3→4, append `MT`. Priority stays P1.
2. NEW row: "stripe webhook 500 on retry" | 2026-05-26 | 1 (ZK) | P0 | raw | —

*Promotion candidates*
- Row #3 now at 4 testers — push to `sites/tasks/` as `/add-bug` (#user-testing #bug).
- NEW row (stripe webhook) — P0 on first occurrence — push to `sites/tasks/` as `/add-bug` (#user-testing #bug #stripe).

*To apply:* reply `apply` (or `apply 1,2` for a subset, or `skip` to drop).
EOF
```

If there are **no candidates** (channel was quiet, or all messages were admin chatter), post a short heartbeat instead — don't skip silently:

```
*User testing capture* — <date>
No new observations in <#C09EU7C87BM> in the last 36h. Log unchanged.
```

That way the owner knows the routine ran and the channel is just quiet.

## When the owner replies

The listener picks up the reply and spawns a fresh `claude -p`. That session reads the proposal in the thread, parses which items the owner wants applied (`apply`, `apply 1,3`, `skip`), then:

1. Edits `accountability/user-testing/issues-log.md` — increment counts, add new rows.
2. For each approved promotion: cd into `sites/tasks/` (run `accountability/routines/sites-prepare.sh tasks` first — per CLAUDE.md, required for any session-side edit to a symlinked site), run the appropriate intake command, capture the returned wikilink, paste it into the log row's `task` column, set `status: tasked`.
3. Commit changes in both repos with a clear message. Open a PR in the tasks repo per the standard linked-projects workflow; the rapidnative-coach repo just commits to main locally.
4. Reply in the same thread with: log diff + PR URL (if any).

## Failure modes

- **#user-testing returns empty** (bot not invited, or channel renamed): post a one-line error in #rapidnative-coach and exit. Don't silently no-op.
- **Slack API rate limited**: back off, retry once, then fail loudly.
- **Issues-log.md doesn't exist or is malformed**: don't try to write; surface the error so the owner can fix the file by hand.
- **Ambiguous dedup** (candidate could match 2+ existing rows): present both options in the proposal — let the owner pick. Do not guess.
