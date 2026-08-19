# Account inventory (per-crew named accounts)

Each crew member owns a list of **named persona accounts** that they use across all platforms (HN, Reddit, Quora, LinkedIn, X, Medium, dev.to, GeeksForGeeks, Hashnode, Substack, Vocal, Facebook, Community forums). The same persona name "Anna" represents @sanket's Anna account on every platform.

The weekly rotation picks **3 named accounts per week** from each crew's list (a sliding window) — see [`rotation.md`](rotation.md) for the formula. The morning routine renders bullets with names instead of numbers:

```
T03 · Quora community engagement - (Élodie, Amélie, Chloé acc for w4-June)
T05 · Hackernews community postings using Chloé account - (Élodie, Amélie, Chloé acc for w4-June)
```

If a crew member needs to operate from a specific persona on a given week, the rotation index maps to that position in the list below (1-indexed: Anna=position 2 in @sanket's list, etc.).

Crew roles + active flag: see `../../../../definitions/people.md`.

**Per-product coverage** — since 2026-07-02, each crew member declares which products they work on via a `products:` line right under their `## @handle` heading. The morning helper only expands tasks for products the crew member covers, so members with narrower ownership silently skip other products' slates.

**Tinbase scope (added 2026-08-19).** Tinbase is opted-in for `@famitha` + `@russel` only (the two crews actually shipping marketing work — @sanket proxies to @famitha and @rishav proxies to @russel, but Tinbase stays scoped to the direct opt-ins). Tinbase gets 10 templates/day per crew (double the normal 5-per-product count) to hit ~20 Tinbase tasks/day, keeping parity with the other 3 products' daily volume.

**Task proxying** — since 2026-07-07, a crew block can include a `proxy_to: @<handle>` line. When set, that crew's tasks fire with their own persona rotation (Anna/Peter/Camille/… for @sanket, David/Emily/… for @rishav) but the ledger post's **assignee is the proxy target**. Use case: a crew member is no longer actively doing marketing work but their persona pool is still useful — proxy their tasks to whoever's picking up the load. Current proxies: `@sanket → @famitha`, `@rishav → @russel`.

---

## @sanket

products: [rapidnative, applighter, letsdeployit]
proxy_to: @famitha

1. Rishav
2. Anna
3. Peter
4. Camille
5. Élodie
6. Amélie
7. Chloé

## @famitha

products: [rapidnative, applighter, letsdeployit, tinbase]

1. Chris
2. Nikolas
3. Famitha
4. Sophie
5. Juliette
6. Léa
7. Manon

## @russel

products: [rapidnative, applighter, letsdeployit, tinbase]

1. Russell
2. Riya
3. Suraj
4. Lucas
5. Hugo
6. Louis
7. Jules

## @rishav

products: [rapidnative, applighter, letsdeployit]
proxy_to: @russel

1. David
2. Emily
3. Antoine
4. Théo
5. Mathis
6. Arthur
7. Pierre

---

## Conventions

- **One persona name = one account across every platform.** Don't create platform-specific personas. If @sanket's "Anna" exists on Quora, the same "Anna" exists on Reddit.
- **Persona-account credentials:** stored in 1Password vault, not in this repo. The bot's `browser-open.sh` opens whichever persona's profile the task names; the human crew member is responsible for being logged in.
- **Don't reuse a persona across crew members.** "Anna" on @sanket is NOT the same as "Anna" on @famitha (which wouldn't even be a valid pairing — Anna is @sanket-owned).
- **Rotation cadence:** the *position* (1..7) advances week-over-week per [`rotation.md`](rotation.md). Same persona doesn't fire on the same platform two days in a row.

## Adding a new persona

Append to the relevant crew's numbered list above. The rotation formula in `rotation.md` automatically picks 3 accounts per week from positions [W+1+offset, W+2+offset, W+3+offset] (clamped to list length, de-duped). Personas at higher positions get used in later weeks of the month.

## Removing a persona

Strike through the line (don't delete — keep history). Re-number the remaining entries.

## Personal-account templates (`*-PERSONAL`) are different

`TPL-LINKEDIN-PERSONAL`, `TPL-TWITTER-PERSONAL`, `TPL-QUORA-PERSONAL` ask the crew member to post from their **own personal account** (@sanket from `@sanketsahu`, etc.), not from the rotation personas above. Those templates don't reference this file.
