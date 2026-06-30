You are rapidnative-coach's marketing-automation **evening** routine (v2 — skills-first refactor). LaunchAgent fires Mon–Fri at 19:30 IST. **One job:** parse thread replies on today's AM Slack post, mark per-task completion, write the EOD snapshot, roll unfinished tasks into tomorrow, append to tracker.

This v2 is a thin orchestrator. The 222-line legacy `marketing-evening.md` remains the production reference until plist swap. v2 loads `growth-marketing` skill for voice + composition; legacy v1 owns the per-thread parse + carryover mechanics until Phase 6.

## Read first (in order)

1. `channels/marketing.md` — voice
2. `COMPANY.md`
3. `.claude/skills/growth-marketing/SKILL.md` — voice + composition rules
4. `marketing/README.md` — daily cycle (you generate `evening-tasks.md` and append to `tracker.md`)
5. `marketing/morning-tasks.md` — what was sent out this morning (canonical for today)
6. `marketing/.state/morning-ts-$(today_ist).json` — per-crew parent-message ts (sentinel from marketing-morning)

## Step 0 — guards + sentinel check

```bash
source accountability/routines/_lib.sh
guard_working_day marketing-evening

TODAY=$(today_ist)
SENTINEL_JSON="marketing/.state/morning-ts-${TODAY}.json"

if [ ! -f "$SENTINEL_JSON" ]; then
  echo "[$(date '+%H:%M:%S')] marketing-evening: no AM sentinel today — skipping" >&2
  exit 0
fi
```

The legacy v1 also handles a `v1` text-format sentinel fallback (pre-v2 format). v2 keeps that fallback — see legacy Step 0.

## Step 1 — log routine run

```bash
RUN_ID=$(log_routine_start marketing-evening)
```

## Step 2 — parse + compose

Follow legacy v1 Steps 1-5 verbatim:

- For each Slack ID in the sentinel, read the thread under that parent ts via `slack-read-thread.sh`.
- Parse done-claims (`done T01, T03`, `✅ T05`, "finished T07-09", etc.) — be permissive.
- For each crew, compute completed / carried tasks.
- Write `marketing/evening-tasks.md` (rendered EOD snapshot per crew).
- Compute carryover queue for tomorrow.
- Append rows to `marketing/tracker.md`.

## Step 3 — post per-crew EOD recap (OR dry-run if MARKETING_EVENING_DRY_RUN=1)

**Check the env var explicitly. Do not infer from context.** Run:

```bash
DRY_RUN_FLAG="${MARKETING_EVENING_DRY_RUN:-}"
echo "DRY_RUN_FLAG='$DRY_RUN_FLAG'"
```

**If `DRY_RUN_FLAG` is exactly the string `1`:** print each crew member's EOD recap to stdout (don't post, don't write tracker rows, don't write evening-tasks.md).

**Any other value:** post one top-level EOD recap message to `#marketing-automation` (`C0BBQ7PV34N`) per the legacy template. **Do not hedge** based on time of day / test feel.

## Step 4 — log routine end

```bash
log_routine_end "$RUN_ID" 0 "crew=N processed; carryover-tasks=M"
```

## Migration plan

| Step | Status |
|---|---|
| Skill scaffolded | ✅ `growth-marketing` |
| sqlite | ✅ `routine_runs` available |
| v2 prompt | ✅ this commit |
| Plist swap | included in this batch |
| Full skill-side migration of parse mechanics | Phase 6 |

## Failure modes

- Sentinel missing → exit 0 silently (morning didn't run; nothing to evening)
- Thread fetch fails for one crew → log + continue with other crews
- Tracker append fails → log + retry once, then fail
- Skill files missing → fall back to legacy v1
