# Account inventory (per-crew named accounts)

Each crew member owns a list of **named persona accounts** that they use across all platforms (HN, Reddit, Quora, LinkedIn, X, Medium, dev.to, GeeksForGeeks, Hashnode, Substack, Vocal, Facebook, Community forums). The same persona name "Anna" represents Sanket's Anna account on every platform.

The weekly rotation picks **3 named accounts per week** from each crew's list (a sliding window) — see `rotation.md` for the formula. The morning routine renders bullets with names instead of numbers:

```
T03 · Quora community engagement - (Élodie, Amélie, Chloé acc for w4-June)
T05 · Hackernews community postings using Chloé account - (Élodie, Amélie, Chloé acc for w4-June)
```

If a crew member needs to operate from a specific persona on a given week, the rotation index maps to that position in the list below (1-indexed: Anna=position 2 in Sanket's list, etc.).

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
3. Allie
4. Antoine
5. Théo
6. Mathis
7. Arthur
8. Pierre

---

## Adding a new persona

Append to the relevant crew's numbered list above. The rotation formula in `rotation.md` automatically picks 3 accounts per week from positions [W+1+offset, W+2+offset, W+3+offset] (clamped to list length, de-duped). Personas at higher positions get used in later weeks of the month.

## Removing a persona

Strike through the line (don't delete — keep history). Re-number the remaining entries.

## Personal-account templates (`*-PERSONAL`) are different

`TPL-LINKEDIN-PERSONAL`, `TPL-TWITTER-PERSONAL`, `TPL-QUORA-PERSONAL` ask the crew member to post from their **own personal account** (Sanket from `@sanketsahu`, etc.), not from the rotation personas above. Those templates don't reference this file.
