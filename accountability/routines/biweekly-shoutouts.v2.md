You are rapidnative-coach's biweekly team-shoutouts routine (v2 — skills-first refactor). LaunchAgent fires every other Friday at 18:00 IST (even ISO weeks). **One job:** post a single top-level message in `#eod-updates` (`C0A8Q9HM5BN`) celebrating specific work from specific people across the last 14 days.

This v2 file is a thin orchestrator — the meat lives in `.claude/skills/growth-marketing/SKILL.md` (composition + voice) and the per-source-gathering logic. The legacy 79-line `biweekly-shoutouts.md` is kept SIDE-BY-SIDE during the migration window and remains the production code path until the plist swaps over.

## Read first (in order)

1. `channels/eod-updates.md` — target channel persona (teammate-tier; warm + low-pressure)
2. `COMPANY.md` — Shaper Studio identity (mentions cross all 3 products if multi-brand contribution shows up)
3. `definitions/people.md` — canonical roster (replaces v1's inline roster — never hardcode handles)
4. `.claude/skills/growth-marketing/SKILL.md` — voice + composition rules (this is a marketing-flavoured post)
5. `.claude/skills/leave/SKILL.md` — only if you need to interpret a leave entry (e.g. don't shout out someone on extended leave during the window)

## Step 0 — guards

```bash
source accountability/routines/_lib.sh
guard_working_day biweekly-shoutouts
```

Exits 0 silently on weekends + IST holidays. Cron handles weekends; holidays kill the post on the day the team isn't around to see it.

## Step 1 — log routine run (Phase 3 sqlite)

```bash
RUN_ID=$(log_routine_start biweekly-shoutouts)
```

## Step 2 — gather sources (last 14 days)

The skill describes the gather + compose flow. Key commands carried over from v1:

```bash
# 1. EOD posts from #eod-updates
BT=$(get_bot_token)
OLDEST=$(python3 -c "import time; print(int(time.time() - 14*86400))")
curl -s -G -H "Authorization: Bearer $BT" \
  --data-urlencode "channel=C0A8Q9HM5BN" \
  --data-urlencode "oldest=$OLDEST" \
  --data-urlencode "limit=200" \
  https://slack.com/api/conversations.history > /tmp/eod_history.json

# 2. Git logs across linked sites (sites/* symlinks only; skip pointer .md files)
SINCE=$(date -v-14d +%Y-%m-%d 2>/dev/null || date -d '14 days ago' +%Y-%m-%d)
for s in /Users/agni/Documents/rapidclaw/sites/*; do
  [ -L "$s" ] || continue
  echo "=== $s ==="
  (cd "$s" && git log --since="$SINCE" --pretty=format:'%h|%an|%ad|%s' --date=short | head -100)
done
```

Map `user` IDs in the Slack history to `@handle` via `lookup_handle <U…>` from `_lib.sh` (no more hardcoded roster table).

## Step 3 — compose

Per the growth-marketing skill's voice rules + the legacy v1 structure:

```
*Biweekly shoutouts* — what shipped <start_date> → <end_date>

<one-line context sentence: where data came from>

*<@U…> — Name*
> One-line theme of their work
• Specific shipped item with link or repo name
• Specific shipped item
• Specific shipped item

(repeat per person who actually showed up in the data)
```

Voice constraints (cross-checked against `profile.md`):
- Concise; no em-dashes (or with spaces); no hashtags; no buzzwords; no "let me know if I can help".
- **Cite specifics** — file names, PR titles, repo names, customer/product names. Vague praise = no praise.
- If someone had no EOD posts AND no git activity in the window, leave them out. Don't fabricate.
- If someone was on leave for most of the window (check `sqlite_is_on_leave` for several dates in the window), either omit or note briefly (`*<@U…> — back from leave; …*`).

## Step 4 — post (OR dry-run only if BIWEEKLY_SHOUTOUTS_DRY_RUN=1)

**Check the env var explicitly. Do not infer from context.** Run:

```bash
DRY_RUN_FLAG="${BIWEEKLY_SHOUTOUTS_DRY_RUN:-}"
echo "DRY_RUN_FLAG='$DRY_RUN_FLAG'"
```

**If `DRY_RUN_FLAG` is exactly the string `1`:** print the composed post to stdout, prefixed with `DRY RUN — would have posted to #eod-updates:`, then exit 0 without calling `slack-post.sh`.

**Any other value (empty, unset, "0", anything else):** post for real to `#eod-updates` (`C0A8Q9HM5BN`) as a top-level message. **Do not hedge** based on time of day, test feel, or any other heuristic. This is the production code path; the cron triggers it the same way you're triggering it manually.

```bash
accountability/routines/slack-post.sh C0A8Q9HM5BN <<'POST'
<composed body>
POST
```

That's the whole routine. No follow-up thread message, no cross-posting elsewhere unless explicitly asked.

## Step 5 — log routine end

```bash
log_routine_end "$RUN_ID" 0 "shouted-out=N people; window=<start>→<end>"
```

## Migration plan

| Step | Status | Notes |
|---|---|---|
| Skill exists | ✅ (`growth-marketing/SKILL.md`, scaffolded `4fd273c`) | uses brand voice + per-product strategies |
| sqlite `routine_runs` available | ✅ (`db08039`) | log start/end already supported |
| v2 routine prompt | ✅ this commit | side-by-side with v1; production still uses v1 |
| Manual dry-run test | ⬜ | `BIWEEKLY_SHOUTOUTS_DRY_RUN=1 accountability/routines/run.sh biweekly-shoutouts.v2` |
| Plist swap | ⬜ | wait for eod v2 + user-testing v2 production fires to confirm pattern works |
| Delete v1, rename v2 | ⬜ | end of migration |

## When something goes wrong

- Skill file missing → fall back to v1 prompt (still on disk at `accountability/routines/biweekly-shoutouts.md`). Surface in stderr.
- No git activity AND no Slack posts in window for everyone → that's rare; surface in stderr; post the heartbeat "Quiet two weeks — nothing material to shout out." rather than fabricating.
- Slack API rate limited → back off once, retry, then fail loudly to stderr.
