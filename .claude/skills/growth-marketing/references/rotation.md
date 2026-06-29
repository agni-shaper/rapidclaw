# Weekly account rotation

The bot computes a **3-account pool per platform per week-of-month** so the same account isn't burned daily. Tasks pick one number from the pool (rotating through the week) or use the whole pool ("engagement on accounts 4,5,6").

> Mirror of `marketing/rotation.md`. Synced 2026-06-29. Both files stay in sync until Phase 6 cleanup.

## Week label

The bot derives the label from today's date:

```
week_of_month = ((day_of_month - 1) / 7) + 1     # 1..5
week_label    = "w<N>-<MonthName>"               # e.g. "w3-June"
```

Examples:
- 2026-06-01 → day 1 → `w1-June`
- 2026-06-15 → day 15 → `w3-June`
- 2026-06-19 → day 19 → `w3-June`
- 2026-06-22 → day 22 → `w4-June`
- 2026-07-03 → day 3 → `w1-July`

## Default formula

For a given platform in week W of the month:

```
pool(W, offset, account_count) = [W + 1 + offset, W + 2 + offset, W + 3 + offset]
# Then clamp each number to ≤ account_count (from accounts.md).
# If clamping forces duplicates, the bot keeps the unique numbers and notes the squeeze.
```

The `offset` is a per-platform constant that staggers rotations so the same account isn't simultaneously firing on HN + Reddit + Quora in the same week. See `marketing/rotation.md` (legacy mirror) for the offset table per platform until that content fully migrates here.

## Anti-burnout invariants

1. **No same account two days in a row on the same platform.** The rotation produces a pool; the morning routine cycles through the pool day-by-day within the week.
2. **No same account across two platforms in the same day.** If account 3 fired on HN today, it shouldn't also fire on Reddit today.
3. **Inactive accounts skipped silently.** If `accounts.md` doesn't list position 4 for `@rishav`, the rotation pool for `@rishav` falls back to wrapping (position 4 → position 1).

## When the rotation algorithm changes

Edit both this file AND `marketing/rotation.md` together until Phase 6 cleanup. Document the change in the commit message.
