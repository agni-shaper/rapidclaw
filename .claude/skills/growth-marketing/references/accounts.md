# Accounts — per-crew named persona inventory

Each member of the marketing crew owns a list of **named persona accounts** that they operate across all platforms (HN, Reddit, Quora, LinkedIn, X, Medium, dev.to, GeeksForGeeks, Hashnode, Substack, Vocal, Facebook, Community forums). The same persona name "Anna" represents @sanket's Anna account on every platform.

The weekly rotation picks **3 named accounts per week** from each crew's list (a sliding window) — see [`rotation.md`](rotation.md) for the formula. The morning routine renders bullets with names instead of numbers:

```
T03 · Quora community engagement - (Élodie, Amélie, Chloé acc for w4-June)
T05 · Hackernews community postings using Chloé account - (Élodie, Amélie, Chloé acc for w4-June)
```

If a crew member needs to operate from a specific persona on a given week, the rotation index maps to that position in the list below (1-indexed: Anna=position 2 in @sanket's list, etc.).

> **Source mirror:** this file mirrors `marketing/accounts.md`. Both files MUST stay in sync until the legacy `marketing/` directory is deleted in Phase 6. When the morning routine migrates to this skill (still pending), the legacy mirror can be removed.

---

## @sanket

1. Rishav
2. Anna
3. Peter
4. Camille
5. Élodie
6. Amélie
7. Chloé

## @famitha

1. Chris
2. Nikolas
3. Famitha
4. Sophie
5. Juliette
6. Léa
7. Manon

## @russel

1. Russell
2. Riya
3. Suraj
4. Lucas
5. Hugo
6. Louis
7. Jules

## @rishav

1. David
2. Emily
3. Antoine
4. (more pending — see `marketing/accounts.md` for the canonical legacy list until full migration)

---

## Conventions

- **One persona name = one account across every platform.** Don't create platform-specific personas. If @sanket's "Anna" exists on Quora, the same "Anna" exists on Reddit.
- **Persona-account credentials:** stored in 1Password vault, not in this repo. The bot's `browser-open.sh` opens whichever persona's profile the task names; the human crew member is responsible for being logged in.
- **Don't reuse a persona across crew members.** "Anna" on @sanket is NOT the same as "Anna" on @famitha (which wouldn't even be a valid pairing — Anna is @sanket-owned).
- **Rotation cadence:** the *position* (1..7) advances week-over-week per [`rotation.md`](rotation.md). Same persona doesn't fire on the same platform two days in a row.

## Roles per crew member

(For drafting + voice — pulled from `definitions/people.md` and the legacy `marketing/team.md`.)

- `@sanket` (`U09DC8L7PCZ`) — strategic posts + approvals
- `@rishav` (`U09CUJ9ATM1`) — technical posts (engineering depth)
- `@russel` (`U09DFJJGS1X`) — video-cut adjacent posts + community replies
- `@famitha` (`U09LL9JTDM5`) — design/asset-driven posts + visual platforms

Anyone on leave today is skipped by `is_on_leave <@SLACK_ID>` (from `_lib.sh`) — silent skip, no task drop in `#marketing-automation`.
