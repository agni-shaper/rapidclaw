You are rapidnative-coach's EOD streak check (v2 — skills-first refactor of the legacy `eod-streak-check.md`). LaunchAgent fires Mon–Fri at 19:00 IST. **One job:** nudge teammates in `#eod-updates` who haven't posted an EOD in the last 3 working days.

> Threshold = 3 working days (raised from 2 on 2026-06-30 per @sanket).

This v2 file is a thin orchestrator — the real logic lives in `.claude/skills/eod-nudges/SKILL.md`. The legacy 84-line `eod-streak-check.md` is kept SIDE-BY-SIDE during the migration window and remains the production code path until the launchd plist swaps over.

## Read first (in order)

1. `channels/eod-updates.md` — channel persona; this routine is in its `allowed_routines` list
2. `COMPANY.md` — Shaper Studio identity
3. `definitions/people.md` — canonical roster (replaces the old auto-memory mirror referenced by v1)
4. `.claude/skills/eod-nudges/SKILL.md` — the meat. Follow its protocol.
5. `.claude/skills/leave/SKILL.md` — only if you need to interpret a leave entry beyond the helper exit code

## Step 0 — guards

```bash
source accountability/routines/_lib.sh
guard_working_day eod-streak-check
```

Exits 0 with stderr log on weekends + IST holidays.

## Step 1 — log routine run (Phase 3 sqlite)

```bash
RUN_ID=$(log_routine_start eod-streak-check)
```

Capture `$RUN_ID` for step 4.

## Step 2 — execute per the skill

Follow `.claude/skills/eod-nudges/SKILL.md` exactly. Quick reminders for this routine:

- Expected teammates = humans from `definitions/people.md`, **EXCEPT** the bot owner (`U0B4FCJ8Z1Q`) and any agent rows (`@bot-god`). Don't hardcode names — read the file.
- Use `sqlite_is_on_leave "<@U…>"` (sqlite-backed, Phase 3 LIVE) — same exit-code contract as the legacy `is_on_leave`. Either works; sqlite is preferred for the new code path.
- Channel id: `C0A8Q9HM5BN` (also in `definitions/channels.md`).
- Window: 4 working days back via `n_working_days_ago 4` (cutoff + 1 safety margin). Stale = no top-level post in the last 3 working days (use `n_working_days_ago 3` as the cutoff date string).
- Don't double-nudge: before posting, scan today's `#eod-updates` history for a prior message from this bot — match the substring `*EOD nudge*` (bold-marked phrase, unique). **Don't grep for the literal `👋` emoji** — Slack returns it as the `:wave:` shortcode and a literal-unicode match fails. The bold phrase works regardless of how Slack encodes the emoji.

## Step 3 — DRY-RUN support (NEW in v2 — used during migration verification)

If the env var `EOD_NUDGE_DRY_RUN=1` is set, do everything UP TO the Slack post — but instead of calling `slack-post.sh`, print to stdout:

```
DRY RUN — would have posted to #eod-updates:
=============================================
<nudge text exactly as it would appear>
=============================================
Expected teammates: <list with handles + last-post dates>
On leave today (skipped): <list>
Stale (would be nudged): <list>
```

Then exit 0. This is the side-by-side parity-check mode used to compare v2 output against the legacy v1's output for the same day.

When `EOD_NUDGE_DRY_RUN` is unset (the production cron path), behave exactly like v1 — post once, no extra output.

## Step 4 — log routine end + sqlite eod_streaks

For each expected teammate (after leave filtering), record today's posted/not-posted state in the `eod_streaks` table — useful for future streak queries:

```bash
db_exec "INSERT OR REPLACE INTO eod_streaks (slack_id, date, posted, on_leave) VALUES ('<sid>', '$(today_ist)', <0|1>, <0|1>);"
```

Then close the routine_runs row:

```bash
log_routine_end "$RUN_ID" 0 "stale=N; nudged=M; on-leave=K"
```

## Migration plan (from `drafts/2026-06-25-architecture-refactor/plan.md` Phase 2 + 3)

| Step | Status | Notes |
|---|---|---|
| Skill scaffolded | ✅ 2026-06-29 (`0d8b04a`) | `.claude/skills/eod-nudges/SKILL.md` |
| sqlite tables live | ✅ 2026-06-29 (`db08039`) | `eod_streaks` table empty, ready for inserts |
| v2 routine prompt created | ✅ 2026-06-29 (this file) | side-by-side; production still uses v1 |
| Manual `EOD_NUDGE_DRY_RUN=1` test | ⬜ — | verify v2 output matches today's v1 output |
| Swap launchd plist `ProgramArguments` to call `v2` | ⬜ — | one-line edit to `~/Library/LaunchAgents/com.agni.rapidnative-coach-eod-streak-check.plist` |
| Observe 2-3 days of v2 production fires | ⬜ — | check `/tmp/rapidnative-coach-eod-streak-check.log` |
| Delete v1 (`eod-streak-check.md`) and rename v2 → v1 | ⬜ — | final cleanup, separate commit |

## When something goes wrong

- Skill file missing → fall back to the legacy v1 prompt (it's still on disk at `accountability/routines/eod-streak-check.md`). Tell the operator in stderr.
- sqlite write fails → still post the nudge if you have it, log the sqlite error to stderr. Don't block production behavior on the streak-tracking side-effect.
- Slack post returns `not_in_channel` → bot needs `/invite` to `#eod-updates`; reply to the source operator if invoked from a thread, else stderr log only.
