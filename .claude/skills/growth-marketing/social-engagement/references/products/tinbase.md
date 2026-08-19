# Product: Tinbase

Per-product config consumed by `marketing-recon` (topics + queries + community URLs + brand-monitor terms) and `gen-marketing-morning.py` (mailboxes + SEO URLs). Brand voice + positioning: [`../strategies/tinbase.md`](../strategies/tinbase.md).

**Note on Supabase overlap:** Tinbase is positioned as "Supabase without Docker" — real Postgres + auth + realtime + edge functions in a single ~100 MB executable, no 12-container docker-compose stack. Recon should treat Supabase-adjacent threads as in-scope (r/Supabase, r/PostgreSQL discussions about local dev pain, "supabase local" HN threads) — the wedge is the ergonomic/memory improvement over Docker Supabase, not a from-scratch backend.

## Meta

- Slug: `tinbase`
- Domain: `tinbase.dev`
- Brand terms: `tinbase`

## Topics (rotates weekly)

The weekly topic pool drives every platform's search query. `topic = topics[ISO_WEEK % len(topics)]`.

- supabase local
- postgres local dev
- edge functions
- self-hosted supabase
- pglite
- docker alternatives
- rls
- single binary deploy

## Search query templates

Tinbase's topics are already specific phrases, so no `"{product}" {topic}` prefix is needed — searching the topic verbatim is enough.

- `"{topic}"`
- `supabase {topic}`

## Community URLs (standing watch list)

- https://news.ycombinator.com — front page + `/newest` for backend / Postgres / Supabase threads
- https://reddit.com/r/PostgreSQL — primary subreddit
- https://reddit.com/r/Supabase
- https://reddit.com/r/selfhosted
- https://reddit.com/r/webdev
- https://reddit.com/r/indiehackers
- https://dev.to/t/postgres
- https://dev.to/t/supabase
- https://quora.com/topic/PostgreSQL
- https://quora.com/topic/Supabase

## Mailboxes (Zoho, per-platform signups)

_TBD — mailboxes `@tinbase.dev` not yet provisioned. Recon degrades gracefully (posts still work; only signup-notification routing is affected)._

## SEO URLs (rotate as `{seo_url}` in tasks)

- https://tinbase.dev
