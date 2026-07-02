# Product: RapidNative

Per-product config consumed by `marketing-recon` (topics + queries + community URLs + brand-monitor terms) and `gen-marketing-morning.py` (mailboxes + SEO URLs). See sibling [`../../SKILL.md`](../../SKILL.md) for how this feeds the daily cycle. Brand voice + positioning: [`../strategies/rapidnative.md`](../strategies/rapidnative.md).

## Meta

- Slug: `rapidnative`
- Domain: `rapidnative.com`
- Brand terms: `rapidnative`, `"rapid native"`

## Topics (rotates weekly)

The weekly topic pool drives every platform's search query. `topic = topics[ISO_WEEK % len(topics)]`.

- EAS
- file-based routing
- OTA updates
- push notifications
- boilerplate
- auth
- payments

## Search query templates

Each template is a seed query; recon substitutes `{topic}` with this week's pick.

- `"react native" {topic}`
- `expo {topic}`

## Community URLs (standing watch list)

- https://news.ycombinator.com — front page + `/newest` for relevant threads
- https://reddit.com/r/reactnative — primary subreddit
- https://reddit.com/r/programming
- https://reddit.com/r/webdev
- https://reddit.com/r/devops
- https://dev.to/t/reactnative
- https://quora.com/topic/React-Native
- https://quora.com/topic/Mobile-App-Development

## Mailboxes (Zoho, per-platform signups)

| Platform group | Mailbox | Used for |
|---|---|---|
| GFG / Hashnode / dev.to | outreach@rapidnative.com | signups + reply notifications |
| Quora / Reddit | community@rapidnative.com | signups + DM notifications |
| Medium / Substack / Vocal | publish@rapidnative.com | publication signups |
| LinkedIn / Facebook / Twitter | social@rapidnative.com | social account signups |
| Hackernews | hn@rapidnative.com | signups only |

## SEO URLs (rotate as `{seo_url}` in tasks)

- https://rapidnative.com
- https://rapidnative.com/blog/*
