# Marketing automation — cross-product standing config

**Product-specific config moved to [`products/`](products/) as of 2026-07-02.** Per-product topics, search-query templates, community URLs, mailboxes, and SEO URLs now live in `products/{rapidnative,applighter,letsdeployit}.md`. This file holds only the cross-product bits.

## Product roster (read in order)

- [`products/rapidnative.md`](products/rapidnative.md) — primary product, full config
- [`products/applighter.md`](products/applighter.md) — partial (topics only; community URLs + mailboxes TBD)
- [`products/letsdeployit.md`](products/letsdeployit.md) — partial (topics only; community URLs + mailboxes TBD)

The morning routine iterates today's sprint per-product (see [`sprint.md`](sprint.md)) and only touches products that appear in the day's slate.

## Medium subdomains / publications (cross-product)

- TBD — list any owned Medium publications here (e.g. `medium.com/@rapidnative`, `medium.com/@applighter`).

## Channel routing

- Daily task list → `#marketing-automation` (`C0BBQ7PV34N`)
- Escalations / blocked items → `#marketing` (`C09F377FGFK`)

## Anti-burnout & dedupe rules (cross-product)

Applied by `marketing-recon` when it fans out across products:

1. **URL-level thread dedupe.** If the same thread URL is found for two products in the same recon run, tag it to whichever product's scrape finished first. The other product's slate for that thread is skipped (avoids the same persona replying to the same thread twice via different product angles).
2. **Persona-account exclusivity** — enforced by [`rotation.md`](rotation.md), not overridden per product.
3. **Same account never fires on two products on the same day** — a natural consequence of rule 2, since rotation is per-crew, not per-product.
