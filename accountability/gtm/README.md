# GTM weekly-pick system

Lightweight tracker for the team's growth/SEO/distribution plays. Lives in markdown so it diffs cleanly and the team can grep it.

## Files

- `backlog.md` — master list of every play. One row per play. Status-tracked.
- `picks/YYYY-WW.md` — the 2-3 plays picked for that ISO week, plus outcomes (filled Friday).
- `README.md` — this file. Scoring rules + selection rules.

## Row schema (in `backlog.md`)

Each row is `| id | title | effort | impact | cadence | status | owner | depends-on | notes |`.

- **id** — short stable identifier (e.g. `GH-02`). Category prefix + number. Never renumber once assigned; reuse ids on revival.
- **effort** — `S` (under 1h) · `M` (≈1 workday) · `L` (multi-day).
- **impact** — `H` (passes link juice OR drives signups) · `M` (brand recall, surface area) · `L` (vanity).
- **cadence** — `one-shot` · `weekly` · `monthly` · `quarterly`.
- **status** — `todo` · `doing` · `shipped` · `dropped` · `blocked`.
- **owner** — Slack handle of who picks it up. Empty until assigned.
- **depends-on** — comma-separated ids or short asset names (e.g. `press-kit`, `author-bio`). Empty if none.
- **notes** — one short line. Links to evidence go here.

## Categories (id prefixes)

- `GH` Open Source & GitHub
- `PKG` Package registries
- `DIR` Directories
- `CR` Content marketing — republishing
- `CO` Original content (own properties)
- `COM` Community & forums
- `VID` YouTube & video
- `POD` Podcasts
- `PART` Partnerships & integrations
- `EDU` Education
- `PR` PR & press
- `SEO` Technical SEO foundations
- `BIO` Founder / team bios
- `BIZ` Business directories / company pages
- `LOC` Localization
- `BRAND` Brand reclamation / badge programs
- `NL` Newsletters / hiring

## Picking rules (the bot enforces these every Monday)

1. **Slate of 3** — 1 quick win (S) + 1 substantive compounding asset (M or L) + 1 maintenance/recurring play.
2. **No category-repeat two weeks running** — if last week was directory-heavy, don't run another directory pick this week.
3. **Compounding before recurring** — until the easy one-shots are drained (PH launches, top 5 awesome-list PRs, top 5 directories), prefer them over weekly recurring work.
4. **Block on dependencies** — if a pick has an unmet `depends-on`, surface the prereq as a pick instead.
5. **Owner-friendly** — never queue more than 1 pick with the same owner in a single week unless the owner explicitly asks for it.
6. **Quick-win must actually be quick** — if the S item is going to take more than an hour, downgrade it and replace.

## Scoring (tiebreak when multiple candidates fit a slot)

`score = impact_weight / effort_weight × recency_bonus`

- impact_weight: H=3, M=2, L=1
- effort_weight: S=1, M=2, L=4
- recency_bonus: 1.0 default; ×0.5 if same category was picked in the last 2 weeks; ×1.3 if the play has an external deadline this month (e.g. conference CFP).

Score is a tiebreak guide, not a hard rule — the bot can override with a one-line reason.

## Weekly cadence

- **Monday 09:00** — `gtm-weekly-pick.md` routine fires. Bot reads `backlog.md` + last 4 `picks/*.md`, scores, and posts 3 candidates + 1 alternate in `#marketing`. Superadmin approves or swaps in thread.
- **Friday 17:00** — existing `friday.md` routine has an appended GTM section: reads this week's picks file, asks "what shipped / what slipped / why", updates statuses in `backlog.md`, and prepares next week's seed.

## Adding plays to the backlog

If you spot a new play that isn't there:
1. Pick the right category prefix and the next free id.
2. Add the row with `status=todo` and any known fields. Empty cells are fine.
3. If it's product-specific learning that emerged from running a play, log it in `~/.claude/projects/-Users-agni-Documents-rapidclaw/memory/project_gtm_<product>.md` per the memory convention — not here.
