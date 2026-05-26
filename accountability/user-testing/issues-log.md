# User testing issues — rolling log

One row per *distinct* issue surfaced across user testing sessions. Dedup lives here.

**Promotion to tasks repo** when *either*: `testers hit ≥ 2`, *or* priority is `P0`/`P1` on first occurrence.

**Status flow:** `raw` → `tasked` → `shipped`.

**Priority:** `P0` (urgent), `P1` (important), `P2` (normal), `P3` (papercut). Same scale as `sites/tasks/`.

**Testers hit format:** `N (initials, comma-separated)` — e.g. `3 (RS, ZK, MT)`. Use initials only here; full names live in the raw session notes under `drafts/user-testing/<date>-<slug>/notes.md`.

## Open

| # | issue (short) | first seen | testers hit | priority | status | task |
|---|---|---|---|---|---|---|
| 1 | generated Pomodoro app: timer UI renders but state machine never wired | 2026-05-26 | 1 (Gracey) | P0 | tasked | [[pomodoro-timer-state-machine-missing\|timer state machine missing]] |
| 2 | generated apps: no back affordance on inner pages, no close on modal sheets | 2026-05-26 | 1 (Gracey) | P1 | tasked | [[generated-apps-nav-affordances-missing\|nav affordances missing]] |
| 3 | generator infers UI from prompt but doesn't reason about time-as-state (eval gap) | 2026-05-26 | 1 (Gracey) | P1 | tasked | [[generator-eval-gap-time-as-state\|eval gap: time-as-state]] |

## Shipped

| # | issue (short) | first seen | testers hit | priority | task |
|---|---|---|---|---|---|
| _none yet_ | | | | | |

---

## How to update

See `README.md` in this folder. Short version:

- New issue → add a row to **Open** with `status: raw`.
- Repeat observation → find the matching row, bump `testers hit`, append initials.
- Crossed promotion threshold → create task in `sites/tasks/`, paste `[[slug|desc]]` wikilink into `task`, set `status: tasked`.
- Task shipped → move row from **Open** to **Shipped**, drop the `status` column.
