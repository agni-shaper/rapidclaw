# Task templates

Each template produces **one Slack-ready bullet** in the daily AM post. The morning routine expands templates per person × per template ID listed in `sprint.md` for today.

## Template variables

| Token | Resolves to | Source |
|---|---|---|
| `{{person}}` | crew member handle, e.g. `@famitha` | `team.md` |
| `{{platform}}` | platform name, e.g. `GeeksForGeeks` | template definition |
| `{{nth_account}}` | the specific account number this task uses, with ordinal, e.g. `6th` | `accounts.md` + `rotation.md` |
| `{{pool}}` | comma-separated pool from `rotation.md`, e.g. `4,5,6` | `rotation.md` |
| `{{week_label}}` | e.g. `w3-June` | computed from today's date |
| `{{quota}}` | numeric quota for quota templates, e.g. `6` | template definition |
| `{{seo_url}}` | one URL from `config.md`, round-robin per (person, platform) per day | `config.md` |
| `{{thread_link}}` | URL to a specific platform thread for engagement | `recon-YYYY-MM-DD.json` cache |
| `{{thread_context}}` | one-line context for the thread (title + meta) | `recon-YYYY-MM-DD.json` cache |
| `{{suggested_draft}}` | 2-3 sentence comment draft in profile.md voice | `recon-YYYY-MM-DD.json` cache |
| `{{blog_url}}` | URL of today's blog to amplify | `blog-amplification-YYYY-MM-DD.md` |
| `{{blog_title}}` | title of today's blog | `blog-amplification-YYYY-MM-DD.md` |
| `{{blog_caption}}` | bot-drafted social caption for the blog | `blog-amplification-YYYY-MM-DD.md` |
| `{{blog_source_thread_url}}` | Slack permalink of the source blog message whose thread carries the variant files (canonical / Medium / Dev.to / Hashnode / SEO brief) | `blog-amplification-<product>-<type>-YYYY-MM-DD.md` |
| `{{personal_draft}}` | bot-drafted original post for `*-PERSONAL` templates | `recon-YYYY-MM-DD.json` → `original_posts` |
| `{{personal_topic_angle}}` | one-line topic angle the draft is built around | `recon-YYYY-MM-DD.json` → `original_posts` |

If `accounts.md` says the person owns 0 accounts on a platform, **skip** the task silently for that person.

If `rotation.md`'s clamp produces a single-number "pool" because the person doesn't have enough accounts, the bullet renders as `(<that number>th account)` with no pool suffix and a `[clamped]` note.

**Recon-attached tokens (`thread_link`, `thread_context`, `suggested_draft`) are optional.** The morning routine renders them as indented sub-lines under the bullet ONLY if the recon cache had a finding for that platform. When recon was empty/failed for a platform, the bullet renders plain — no sub-lines, no placeholders.

---

## Template categories

There are **five output shapes**. Every concrete `TPL-*` ID below picks one of these shapes plus a platform + behaviour.

### Shape A — singular action

```
Submit 1 <action> to {{platform}} ({{nth_account}} account) - {{pool}} accounts for {{week_label}}
```

### Shape B — community postings (use pool)

```
{{platform}} community postings ({{nth_account}} account) - {{pool}} accounts for {{week_label}}
```

### Shape C — community engagement (use full pool, no specific N)

```
{{platform}} community engagement - ({{pool}} acc for {{week_label}})
```

### Shape D — personal-accounts post

```
{{platform}} ({{pool}} accounts) Post from {{platform}} account (from personal accounts)
```

If recon attached a `{{personal_draft}}`, the morning routine posts the task as a **clean top-level message** in `#marketing-automation` and posts the enrichment (compose link + draft) as a **threaded reply** under that task post. So the channel feed shows just the bullet; clicking the thread reveals the assets:

```
[channel top-level]
T0N · *{{platform}} ({{pool}} accounts) Post from {{platform}} account (from personal accounts)*
_new today · w4-June_

_Reply 'done' in this thread when complete, or react :white_check_mark:._

  [threaded reply by bot]
  🔗 Compose: <{{compose_url}}>
  📝 Suggested post (adapt before publishing) — angle: {{personal_topic_angle}}
  "<{{personal_draft}}>"
```

**Compose URL per platform** (rendered by morning routine, not by recon):

| Platform | URL pattern | Notes |
|---|---|---|
| Twitter (X) | `https://twitter.com/intent/tweet?text=<urlencoded draft>` | Pre-filled — one click to ship |
| LinkedIn | `https://www.linkedin.com/feed/?shareActive=true&mini=true` | Empty composer (LinkedIn killed text-prefill in 2017); crew copies the draft from the `📝` line |
| Quora | Specific question URL (from recon's findings) when available, else `https://www.quora.com/` | Personal Quora = answering a specific question; recon needs to scrape unanswered questions even on personal-only days for the best UX |

If no draft was attached (recon failed for that platform, or no draft for that specific crew member), render plain — no fake `🔗` / `📝` lines.

**Blog amplification override:** if `blog-amplification-YYYY-MM-DD.md` exists, ONE crew member's `TPL-LINKEDIN-PERSONAL` (preferred) or first available `*-PERSONAL` task gets the blog amplification `📝` block instead of the original-post draft.

### Shape E — quota (no platform, no account)

```
Write {{quota}} articles for Distribution
```

### Shape F — distro of a published blog (no platform, no account)

```
Distribute today's blog: {{blog_title}}
```

Unlike Shape A (which asks the crew to draft a NEW article for a specific platform), Shape F asks the crew to **syndicate an already-published blog** to platform(s) of their choice. The canonical + platform-specific variant files (Medium / Dev.to / Hashnode / SEO brief) are attached in the source blog thread — the crew grabs the file matching their target platform and posts from their personal account.

Task-assist thread reply for Shape F emits:

```
📰 *Today's distribution: {{blog_title}}*
Canonical: {{blog_url}} (or "in review — no public URL yet")
Ready-to-post variants (canonical / Medium / Dev.to / Hashnode / SEO brief) in the source thread:
  {{blog_source_thread_url}}
Pick a platform, grab that variant, post from your personal account.
```

`{{blog_source_thread_url}}` is the Slack permalink of the message in `#ai-blogs` (RN) or `#applighter-ai-blogs` (AL) whose thread carries the variant files. Sourced from `blog-amplification-<product>-<type>-<date>.md` (external-first, internal-fallback for RN; external-only for AL).

---

## Concrete template IDs

### Singular-action templates (Shape A)

- **TPL-GFG-ARTICLE** — `{{platform}}=GeeksForGeeks`, `{{action}}=article`
- **TPL-MEDIUM-ARTICLE** — `{{platform}}=Medium`, `{{action}}=article`
- **TPL-SUBSTACK-POST** — `{{platform}}=Substack`, `{{action}}=post`
- **TPL-HASHNODE-ARTICLE** — `{{platform}}=Hashnode`, `{{action}}=article`
- **TPL-DEVTO-ARTICLE** — `{{platform}}=dev.to`, `{{action}}=article`
- **TPL-VOCAL-STORY** — `{{platform}}=Vocal`, `{{action}}=story`
- **TPL-LINKEDIN-POST** — `{{platform}}=LinkedIn`, `{{action}}=post`

### Community-postings templates (Shape B)

- **TPL-HN-POST** — `{{platform}}=Hackernews`
- **TPL-REDDIT-POST** — `{{platform}}=Reddit`
- **TPL-QUORA-POST** — `{{platform}}=Quora`
- **TPL-FB-POST** — `{{platform}}=Facebook`
- **TPL-TWITTER-POST** — `{{platform}}=Twitter`

### Community-engagement templates (Shape C)

- **TPL-HN-ENGAGE** — `{{platform}}=Hackernews`
- **TPL-REDDIT-ENGAGE** — `{{platform}}=Reddit`
- **TPL-QUORA-ENGAGE** — `{{platform}}=Quora`
- **TPL-LINKEDIN-ENGAGE** — `{{platform}}=LinkedIn`
- **TPL-TWITTER-ENGAGE** — `{{platform}}=Twitter`
- **TPL-COMMUNITY-ENGAGE** — `{{platform}}=Community forums`

### Personal-account templates (Shape D)

- **TPL-QUORA-PERSONAL** — `{{platform}}=Quora`
- **TPL-LINKEDIN-PERSONAL** — `{{platform}}=LinkedIn`
- **TPL-TWITTER-PERSONAL** — `{{platform}}=Twitter`

### Quota templates (Shape E)

- **TPL-DISTRO-6** — `{{quota}}=6`, action=`Write articles for Distribution`
- **TPL-DISTRO-3** — `{{quota}}=3`, lighter day
- **TPL-DISTRO-10** — `{{quota}}=10`, heavy day

### Distro-of-published-blog templates (Shape F)

- **TPL-DISTRO-ARTICLE** — no `{{platform}}` (multi-target), no rotation persona (crew posts from own personal account). Sources today's blog for the task's product from `marketing/.state/blog-amplification-<product>-<type>-<date>.md` (external-first, internal-fallback for RN; external-only for AL). If no cache file exists for that product, the task renders a bare bullet ("Distribute today's blog: (no blog cached for <product>)") and the task-assist thread reply politely says so.

### Crew-filtered creative templates (Shape G)

- **TPL-FREE-TOOL** — bullet: `Create a Free Tool`. No platform, no persona rotation, no recon lookup. Silent enrichment (task-assist posts nothing — crew ideates the tool themselves). **Crew filter**: `["@famitha"]` — only fires for @famitha's crew block, skipped for everyone else (checked against `member["handle"]`, so proxies don't accidentally route it to a proxy target). Currently scheduled Mon + Thu under RapidNative to yield ~2 tasks/week.

---

## Example expansion (today, 2026-06-19, w3-June, @famitha)

Sprint section for today lists:

```
- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL
```

Expanded for `@famitha` (with recon-cache findings attached):

```
- [ ] T01 · Submit 1 article to GeeksForGeeks (6th account) - 4,5,6 accounts for w3-June
- [ ] T02 · Hackernews community postings (6th account) - 4,5,6 accounts for w3-June
       🔗 https://news.ycombinator.com/item?id=12345 — "Show HN: Expo SDK 53"
       💬 Suggested: "EAS Build's new flag for ABI-stable native modules sidesteps the issue you're hitting — only landed in SDK 53, but it cuts cold-start by ~40%."
- [ ] T03 · Hackernews community engagement - (4,5,6 acc for w3-June)
       🔗 Top 3 picks (see marketing/morning-tasks.md for full list)
       💬 (engage substantively; pick 1-2 to comment on, others to upvote)
- [ ] T04 · Write 6 articles for Distribution
- [ ] T05 · Quora (5,6,7 accounts) Post from Quora account (from personal accounts)
       🔗 Amplify today's blog: https://rapidnative.com/blogs/eas-build-2026 — "EAS Build in 2026: What Changed"
       💬 Suggested caption: "Just published — the EAS build pipeline got 3 new flags in SDK 53 that materially improve cold-start. Quick breakdown:"
```

Notes:
- Quora's pool is `5,6,7` because `rotation.md` gives Quora an offset of +1.
- The `🔗 / 💬` sub-lines on T02 came from the recon cache for HN.
- T03 (community engagement, multi-account) shows a compact summary; the morning-tasks.md file has the full list.
- T05 (Quora-personal) was replaced/augmented with the blog-amplification injection (Step 6.7 in `marketing-morning.md`).
- T01 (article submission) and T04 (quota) have no thread link because they're not engagement tasks.
