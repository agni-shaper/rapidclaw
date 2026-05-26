# User testing issues — rolling log

One row per *distinct* issue surfaced across user testing sessions. Dedup lives here.

**Promotion to tasks repo** when *either*: `testers hit ≥ 2`, *or* priority is `P0`/`P1` on first occurrence.

**Status flow:** `raw` → `tasked` → `shipped`.

**Priority:** `P0` (urgent), `P1` (important), `P2` (normal), `P3` (papercut). Same scale as `sites/tasks/`.

**Testers hit format:** `N (initials, comma-separated)` — e.g. `3 (RS, ZK, MT)`. Use initials only here; full names live in the raw session notes under `drafts/user-testing/<date>-<slug>/notes.md`.

## Open

| # | issue (short) | first seen | testers hit | priority | status | task |
|---|---|---|---|---|---|---|
| _none yet_ | | | | | | |

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
