# Strategy: Tinbase

Distribution + growth angle for **Tinbase** (tinbase.dev) — Shaper Studio's local-Postgres / Supabase-without-Docker product.

## Product positioning

- **What it is:** A single-file executable (~58 MB, ~100 MB RAM) that runs real Postgres 17 + auth + realtime + edge functions + webhooks + cron. Works with the official `supabase-js` SDK unchanged. Node, browser, or mobile. Open source (MIT).
- **Who it's for:** Backend / full-stack devs who want Supabase's ergonomics without Docker's overhead (12 containers / 2.3 GB / 1626 MB RAM); indie hackers prototyping; self-hosters; folks running local dev on laptops that can't spare the Docker footprint.
- **Wedge:** "Supabase-compatible backend, one file, no Docker. ~100 MB RAM instead of ~1.6 GB."

## Topic pillars

1. **Local dev ergonomics** — how much RAM/CPU Docker Supabase eats, boot time, watch loops, why devs give up and use hosted-only.
2. **Postgres itself** — Postgres 17 features, RLS patterns, migrations, extensions, embedded vs client-server.
3. **Portability & single-binary distribution** — why bundling the whole backend as one exec matters for demos, workshops, embedded/edge deployments, CI/CD.
4. **Edge functions + realtime** — how Tinbase handles the pieces beyond raw DB (functions, subscriptions, webhooks, cron) without needing a whole platform.
5. **Supabase-compatibility** — swapping `supabase-js` connection strings; migrating a local dev flow off Docker Supabase.

## Voice for Tinbase drafts

- Technical, benchmark-driven. Show numbers: "100 MB vs 1626 MB", "2.5s boot vs 45s", "one binary vs 12 containers".
- Reproducible > rhetorical. Post commands, docker stats output, screenshots of activity monitor.
- Respectful of Supabase — Tinbase is compatible with the SDK; the wedge is Docker, not Supabase itself. Never trash Supabase-the-hosted-platform.
- No "leverage" / "robust" / "seamless" / "best-in-class" — see `profile.md` voice rules.
- Open-source-native tone. MIT license, GitHub-first, contributors welcome.

## Platforms to engage on (priority order)

1. **HackerNews** — highest signal for Postgres / open-source dev tools / "I built X" launches. Show HN posts for milestones. Substantive comments on any "Supabase local dev sucks", "Postgres embedded", "PGlite", "Docker RAM" threads.
2. **Reddit** — r/PostgreSQL (high-signal), r/Supabase (adjacent + directly interested), r/selfhosted, r/webdev, r/indiehackers.
3. **dev.to / Hashnode** — long-form technical posts. "How I dropped my dev-stack RAM from 2 GB to 100 MB" style. Postgres tutorials that happen to use Tinbase as the runtime.
4. **X (Twitter)** — Postgres / Supabase / self-hosting community (follower clusters around @supabase, @PostgreSQL, @nikitabase, @kentcdodds when he talks DB).
5. **Hashnode** — dev-heavy audience overlaps HN readers; benchmark posts do well.
6. **LinkedIn** — selectively, for CTO / staff-engineer audiences making stack decisions.
7. **Quora** — answer questions on "how do I set up Supabase locally", "alternatives to Docker for Postgres", "embedded Postgres for Node".
8. **Medium / Substack** — re-publish blog posts.

## SEO / content priorities

- Long-tail keywords: "supabase local without docker", "postgres embedded node", "supabase alternatives self-hosted", "pglite production", "single-binary postgres".
- Comparison content: "Tinbase vs Docker Supabase (RAM/boot benchmarks)", "PGlite vs Tinbase vs embedded Postgres", "Tinbase vs Neon local dev".
- Migration guides: "Moving a local Supabase project to Tinbase in 10 minutes".

## Off-platform amplification

- **GitHub:** Tinbase repo public + MIT — get stars via HN launches, awesome-lists, dev.to link-backs.
- **Awesome lists:** PRs to `awesome-postgres`, `awesome-supabase`, `awesome-selfhosted`, `awesome-node`.
- **Product Hunt:** scheduled launches for major releases (see `accountability/gtm/` for past picks).
- **Podcast pitches:** Postgres FM, Changelog, JavaScript-adjacent podcasts.

## Standing community URLs to watch

(see `../products/tinbase.md` for the full list)

## What NOT to do for Tinbase

- Don't trash Supabase-the-company or Supabase-hosted — Tinbase is complementary (local dev + self-host use cases), and the SDK compatibility is the whole story. Punching down on Supabase looks bad and misreads the audience.
- Don't post benchmarks without reproducible commands. Postgres/backend folks will call it out immediately.
- Don't lean on marketing adjectives ("blazing fast", "seamless") — technical readers filter those out as noise.
- Don't post the same "we replaced Docker!" pitch twice in the same subreddit within 30 days.

## Related skills

- (No dedicated per-site skills yet — Tinbase content production lives in the coach's shared drafting; no `sites/tinbase-website/` linked project as of 2026-08-19.)
