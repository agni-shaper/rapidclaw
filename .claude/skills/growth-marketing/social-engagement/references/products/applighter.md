# Product: Applighter

Per-product config consumed by `marketing-recon` and `gen-marketing-morning.py`. Brand voice + positioning: [`../strategies/applighter.md`](../strategies/applighter.md) (stub — brand audit pending).

**Note on RN overlap:** Applighter's topics deliberately share vocabulary with RapidNative (both are React-Native / Expo adjacent). Recon dedupes at thread-URL level — a thread found for both products gets tagged to whichever product's scrape finished first; the other product's slate for that thread is skipped. Applighter's reply-drafting angle should lean on **templates / AI-generated code quality / SaaS starter positioning** even when the source thread was RN-general.

## Meta

- Slug: `applighter`
- Domain: `applighter.com`
- Brand terms: `applighter`

## Topics (rotates weekly)

- react native boilerplate
- expo supabase auth
- claude code react native
- ai generated code quality
- react native template starter
- rls security supabase
- expo app

> `expo app` is intentionally broad — edit to a more specific phrase (e.g. `expo app router`, `expo app publish`) once positioning is decided.

## Search query templates

Applighter's topics are already specific phrases, so no `"{product}" {topic}` prefix is needed — searching the topic verbatim is enough.

- `"{topic}"`

## Community URLs (standing watch list)

_TODO — brand audit pending. Recon will skip the standing-URL sweep for this product until entries are added._

## Mailboxes (Zoho, per-platform signups)

_TODO — mailboxes `@applighter.com` not yet provisioned. Recon degrades gracefully (posts still work; only signup-notification routing is affected)._

## SEO URLs (rotate as `{seo_url}` in tasks)

- https://applighter.com
