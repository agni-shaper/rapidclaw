# Weekly account rotation

The bot computes a **3-account pool per platform per week-of-month** so the same account isn't burned daily. Tasks pick one number from the pool (rotating through the week) or use the whole pool ("engagement on accounts 4,5,6").

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

So with the default `offset = 0` and `account_count = 7`:
- w1 → `2, 3, 4`
- w2 → `3, 4, 5`
- w3 → `4, 5, 6`    ← matches today (2026-06-19)
- w4 → `5, 6, 7`
- w5 → `6, 7, 7` (collapses to `6, 7`)

## Per-platform offsets

Each platform can shift the window. Higher offset = use later-numbered accounts.

| Platform | Offset | Reasoning |
|---|---|---|
| GeeksForGeeks | 0 | default |
| Hackernews | 0 | default |
| Quora | +1 | shifted — uses later accounts (matches user spec: w3 → 5,6,7) |
| Reddit | 0 | default |
| Medium | 0 | default |
| Hashnode | 0 | default |
| dev.to | 0 | default |
| Substack | 0 | default |
| Vocal | 0 | default |
| LinkedIn | 0 | default |
| Facebook | 0 | default |
| Twitter | 0 | default |
| Community forums | 0 | default |

Edit offsets here when a platform needs a different rhythm.

## Which specific account a single-action task uses

When a template references one specific account (e.g. `TPL-GFG-ARTICLE` → "Submit 1 article, 6th account"), the bot picks **the last number in the pool** by default. Rationale: the highest-numbered account is the most recently created and least likely to be flagged for spam. For w3-June on GFG (pool `4,5,6`), that's the **6th** account.

Per-platform override: if a platform needs day-of-week rotation through the pool instead, add a row here. (None today.)

## Manual overrides (rare)

If a specific (person, platform, week) needs a different pool — account got banned, cooldown reset, whatever — add an override:

Format: `<@person> · <platform> · <week-label> · use <comma-separated accounts>`

(none yet)

Overrides win over the formula. The bot reads this section AFTER computing the default pool.
