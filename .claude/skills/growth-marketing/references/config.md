# Marketing automation — standing config

Standing reference data the daily distribution cycle reads. Edit by hand.

## SEO domains (rotate target URLs in posts/comments)

- `rapidnative.com` — primary marketing site
- `rapidnative.com/blog/*` — long-form, indexable
- `letsdeploy.it` — second product
- `applighter.com` — third product
- TBD — add more as new properties go live

## Zoho mailboxes (per-platform signup, support, replies)

| Platform group | Mailbox | Used for |
|---|---|---|
| GFG / Hashnode / dev.to | `outreach@rapidnative.com` | signups + reply notifications |
| Quora / Reddit | `community@rapidnative.com` | signups + DM notifications |
| Medium / Substack / Vocal | `publish@rapidnative.com` | publication signups |
| LinkedIn / Facebook / Twitter | `social@rapidnative.com` | social account signups |
| Hackernews | `hn@rapidnative.com` | signups only |

(Update once real mailboxes are confirmed.)

## Medium subdomains / publications

- TBD — list any owned Medium publications here (e.g. `medium.com/@rapidnative`).

## Standing community URLs (always-on watch list)

- `news.ycombinator.com` — front page + `/newest` for relevant threads
- `reddit.com/r/reactnative` — primary subreddit
- `reddit.com/r/programming`
- `reddit.com/r/webdev`
- `reddit.com/r/devops`
- `dev.to/t/reactnative`
- `quora.com/topic/React-Native`
- `quora.com/topic/Mobile-App-Development`

## Search strategy (cross-platform query templates)

Use these as the seed queries when finding posts to comment on / answer:

- `"react native" {topic}`
- `expo {topic}` (where `topic ∈ {file-based-routing, EAS, OTA updates, push notifications}`)
- `"rapidnative" OR "rapid native"` (brand monitoring)
- `"letsdeploy" OR "lets deploy"` (brand monitoring)
- `mobile dev {pain-point}` (where `pain-point ∈ {boilerplate, auth, payments, push}`)

Rotate the `{topic}` slot week-over-week so the same accounts don't keep hitting the same threads.

## Channel routing

- Daily task list → `#marketing-automation` (`C0BBQ7PV34N`)
- Escalations / blocked items → `#marketing` (`C09F377FGFK`)
