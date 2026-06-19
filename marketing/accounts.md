# Account inventory

Per (person, platform): **how many numbered accounts they own.** The bot only references accounts by number (e.g. "use your 6th account"); the actual handle/login mapping lives with the crew member, not in this repo.

If a cell shows `7`, that crew member has accounts numbered 1 through 7 on that platform. If a cell shows `0`, they don't operate on that platform — the rotation skips them.

If `rotation.md` asks for account N but this table says they only have N-1 accounts, the bot clamps to the highest available and notes it in the task ("…use 5th account [clamped: you only have 5]"). No silent skipping.

**Default seed: 7 per cell** — gives ~3-account weekly windows good cooldown over a month. Edit down where the real count is lower.

## @sanket

| Platform | Accounts owned |
|---|---|
| GeeksForGeeks | 7 |
| Hackernews | 7 |
| Quora | 7 |
| Reddit | 7 |
| Medium | 7 |
| Hashnode | 7 |
| dev.to | 7 |
| Substack | 7 |
| Vocal | 7 |
| LinkedIn | 7 |
| Facebook | 7 |
| Twitter | 7 |
| Community forums | 7 |

## @rishav

| Platform | Accounts owned |
|---|---|
| GeeksForGeeks | 7 |
| Hackernews | 7 |
| Quora | 7 |
| Reddit | 7 |
| Medium | 7 |
| Hashnode | 7 |
| dev.to | 7 |
| Substack | 7 |
| Vocal | 7 |
| LinkedIn | 7 |
| Facebook | 7 |
| Twitter | 7 |
| Community forums | 7 |

## @russel

| Platform | Accounts owned |
|---|---|
| GeeksForGeeks | 7 |
| Hackernews | 7 |
| Quora | 7 |
| Reddit | 7 |
| Medium | 7 |
| Hashnode | 7 |
| dev.to | 7 |
| Substack | 7 |
| Vocal | 7 |
| LinkedIn | 7 |
| Facebook | 7 |
| Twitter | 7 |
| Community forums | 7 |

## @famitha

| Platform | Accounts owned |
|---|---|
| GeeksForGeeks | 7 |
| Hackernews | 7 |
| Quora | 7 |
| Reddit | 7 |
| Medium | 7 |
| Hashnode | 7 |
| dev.to | 7 |
| Substack | 7 |
| Vocal | 7 |
| LinkedIn | 7 |
| Facebook | 7 |
| Twitter | 7 |
| Community forums | 7 |

## Personal-accounts inventory (separate from numbered marketing accounts)

Some tasks specify "from personal accounts" (e.g. Quora). These come from a different pool — the crew member's personal handles, not the numbered marketing-rotation accounts. The bot just tags the task with `(from personal accounts)`; the crew member knows which one to use.

| Person | Has personal accounts on |
|---|---|
| @sanket | Quora, LinkedIn, Twitter |
| @rishav | Quora, LinkedIn, Twitter |
| @russel | Quora, LinkedIn, Twitter |
| @famitha | Quora, LinkedIn, Twitter |
