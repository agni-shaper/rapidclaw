You are rapidnative-coach's marketing-automation **morning** routine (v2 — skills-first refactor). LaunchAgent fires Mon–Fri at 07:00 IST. **One job:** for each active crew member, post a per-crew task slate as a top-level message in `#marketing-automation` (`C0BBQ7PV34N`), enriched with recon findings from the 06:00 cache.

This v2 is a thin orchestrator. The 63-line legacy `marketing-morning.md` remains the production reference until plist swap. v2 loads `growth-marketing` skill (which carries voice + per-crew accounts inventory + rotation formula) and defers per-template expansion + per-crew distribution mechanics to the legacy file's structure.

## Read first (in order)

1. `channels/marketing.md` (and `marketing-automation` if a persona file is added later) — voice
2. `COMPANY.md` — Shaper Studio identity
3. `.claude/skills/growth-marketing/SKILL.md` — voice + composition rules
4. `.claude/skills/growth-marketing/references/{accounts,rotation,strategies/*}.md` — per-crew accounts + this week's rotation pool
5. `marketing/sprint.md` — today's section drives task selection
6. `marketing/task-templates.md` — TPL-* → rendered bullet
7. `marketing/.state/recon-$(today_ist).json` — recon cache (Step 2 enrichment)
8. `marketing/.state/blog-amplification-YYYY-MM-DD.md` — latest blog to amplify

## Step 0 — guards + sentinel

```bash
source accountability/routines/_lib.sh
guard_working_day marketing-morning

TODAY=$(today_ist)
SENTINEL="marketing/.state/morning-ts-${TODAY}.json"

if [ -f "$SENTINEL" ]; then
  echo "[$(date '+%H:%M:%S')] marketing-morning: sentinel exists for $TODAY — exiting" >&2
  exit 0
fi
```

Sentinel records the parent-message ts per crew member (evening routine reads it). Existence = already ran today.

## Step 1 — log routine run

```bash
RUN_ID=$(log_routine_start marketing-morning)
```

## Step 2 — skip on-leave crew

For each crew member in `growth-marketing/references/accounts.md` "## Roles per crew member" section:

```bash
sqlite_is_on_leave "<@$SID>" && continue   # silent skip
```

(Or `is_on_leave` — same contract. Sqlite preferred for new skill-based code.)

## Step 3 — compose per-crew slates

Follow legacy v1 + `growth-marketing/SKILL.md`. Per remaining crew member:

- Read their assigned tasks from `marketing/sprint.md` for today
- Expand `TPL-*` IDs via `task-templates.md`
- Compute this week's account rotation pool per `growth-marketing/references/rotation.md`
- Inject recon findings from `marketing/.state/recon-$(today_ist).json` (filter to the crew member's platforms)
- Inject blog-amplification link if `marketing/.state/blog-amplification-${TODAY}.md` exists
- Format per the legacy template (bullets with task IDs, account names, links)

## Step 4 — post per-crew (OR dry-run if MARKETING_MORNING_DRY_RUN=1)

**Check the env var explicitly. Do not infer from context.** Run:

```bash
DRY_RUN_FLAG="${MARKETING_MORNING_DRY_RUN:-}"
echo "DRY_RUN_FLAG='$DRY_RUN_FLAG'"
```

**If `DRY_RUN_FLAG` is exactly the string `1`:** print each crew member's slate to stdout (don't post, don't write sentinel).

**Any other value:** post one top-level message per crew member to `#marketing-automation` (`C0BBQ7PV34N`), capture the ts of each, write to `$SENTINEL` as JSON keyed by Slack ID:

```json
{
  "U09DC8L7PCZ": "1782799999.123456",
  "U09CUJ9ATM1": "...",
  ...
}
```

**Do not hedge** based on time of day / test feel. Cron triggers this exactly like you'd trigger it manually.

## Step 5 — log routine end

```bash
log_routine_end "$RUN_ID" 0 "crew=N posted; on-leave=K skipped; recon-findings=M"
```

## Migration plan

| Step | Status |
|---|---|
| Skill scaffolded | ✅ `growth-marketing` |
| sqlite | ✅ `routine_runs` available |
| v2 prompt | ✅ this commit |
| Plist swap | included in this batch |
| Full skill-side migration | Phase 6 (move per-template expansion + sentinel logic into `growth-marketing`) |

## Failure modes

- Recon cache missing for today → degrade gracefully (post tasks without enriched links per legacy v1)
- Some crew on leave → skip silently
- Slack API rate-limited → fail loudly mid-loop; the routine isn't fully idempotent across partial-failures (Phase 6 fix)
- Sentinel write fails → don't post (or evening routine will double-process); fail loudly
- Skill files missing → fall back to legacy v1
