---
name: social-engagement-tinbase
description: Tinbase-specific social distribution — local Postgres / Supabase-without-Docker / edge functions / self-hosting threads on HN, Reddit (r/PostgreSQL, r/Supabase, r/selfhosted), dev.to, X, Hashnode, LinkedIn, Quora. One of four per-product sub-skills under `social-engagement` (siblings: `-rapidnative`, `-applighter`, `-letsdeployit`). Loaded by the orchestrator when today's sprint has a Tinbase block, OR ad-hoc when the user asks about Tinbase social copy.
when_to_load: |
  Load when ANY of the following:
  - marketing-morning orchestrator dispatches to the Tinbase product (sprint.md has a `### Tinbase` block today)
  - marketing-recon is scraping for Tinbase (`products_scraped` includes `tinbase`)
  - The user asks about Tinbase social copy, Tinbase engagement drafts, Postgres/Supabase-local positioning
  - The user names a platform + Tinbase context ("dev.to article on PGlite", "Reddit r/selfhosted post about single-binary Postgres")
voice_source: ../../../../profile.md
---

# social-engagement-tinbase

Tinbase's flavour of the daily social-engagement cycle. Everything Tinbase-specific — topics, brand terms, community URLs, per-brand voice — lives here (or is pointed at from here).

For orchestration + shared mechanics (persona rotation, sprint parsing, cross-product dedupe rules), read the parent [`../SKILL.md`](../SKILL.md).

## Read these before doing any work

1. **Always:** [`../../../../COMPANY.md`](../../../../COMPANY.md) + [`../../../../profile.md`](../../../../profile.md) (bootstrap already loaded them)
2. **Product config** — topics, search-query templates, community URLs, brand terms:
   [`../references/products/tinbase.md`](../references/products/tinbase.md)
3. **Brand voice + positioning:**
   [`../references/strategies/tinbase.md`](../references/strategies/tinbase.md)
4. **Shared refs (product-agnostic):**
   - [`../references/accounts.md`](../references/accounts.md) — Tinbase currently opted-in for `@famitha` + `@russel` only
   - [`../references/rotation.md`](../references/rotation.md)
   - [`../references/task-templates.md`](../references/task-templates.md)
   - [`../references/sprint.md`](../references/sprint.md) — today's `### Tinbase` block (Tinbase gets 10 templates/day — twice the volume of RN/AL/LDI, because only 2 crews cover it)

## Voice cheat-sheet (for LLM drafts)

- **Benchmark-driven, reproducible.** Post commands + numbers: `docker stats` output, activity monitor screenshots, boot-time measurements. Postgres / backend audiences filter marketing adjectives instantly.
- **"Supabase without Docker" is the wedge.** SDK-compatible, one file, ~100 MB RAM vs Docker Supabase's ~1.6 GB / 12 containers. Never trash Supabase-the-company — Tinbase is complementary (local + self-host use cases), and the SDK compatibility IS the story.
- **Open-source-native tone.** MIT, GitHub-first, contributors welcome. Link the repo, invite PRs, treat the audience as peers.
- **Postgres 17 features are fair game.** RLS, migrations, extensions, embedded vs client-server — these anchor real technical posts that happen to use Tinbase as the runtime.
- **No "leverage" / "robust" / "seamless" / "blazing fast"** — see profile.md.

## Platforms (priority order)

Tinbase's audience is backend / OSS-native — different from the RN-heavy pool of the other 3 products. HN weight is higher; LinkedIn weight is lower.

1. **HackerNews** — highest signal. Show HN for milestones, substantive comments on Postgres / Supabase / self-hosting / Docker-RAM threads.
2. **Reddit** — r/PostgreSQL (primary), r/Supabase (adjacent + interested), r/selfhosted, r/webdev, r/indiehackers.
3. **dev.to / Hashnode** — long-form technical posts, benchmark comparisons, migration guides.
4. **X (Twitter)** — Postgres / Supabase / self-hosting community; follower clusters around @supabase, @PostgreSQL, backend/database Twitter.
5. **Quora** — "supabase local", "postgres embedded", "docker alternatives" questions.
6. **LinkedIn** — CTO / staff-engineer stack-decision audience (lower priority than the above).
7. **Medium / Substack** — re-publish blog posts.

## When invoked by the orchestrator

`gen-marketing-morning.py` iterates `PRODUCT_SLUGS` (which now includes `tinbase`) and expands today's `### Tinbase` block for each opted-in crew (currently @famitha + @russel per `accounts.md`). Others silently skip.

## Anti-hallucination

Inherits the parent SKILL.md's guards. Product-specific additions:

- **Never invent benchmark numbers.** If citing RAM / boot time / binary size, use the tinbase.dev homepage claims (100 MB RAM, 58 MB binary, 12 containers / 2.3 GB Docker Supabase) or measure locally and cite the command. Never round or extrapolate.
- **Never claim Supabase-feature parity that isn't in the docs.** Auth, RLS, realtime, edge functions, webhooks, cron, `supabase-js` compat — all documented on the homepage. Anything beyond that, say "not sure, check the repo".
- **Never post the same benchmark in the same subreddit twice within 30 days.** r/PostgreSQL and r/Supabase moderators will flag reposts.
