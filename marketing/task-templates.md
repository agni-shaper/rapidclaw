# Task templates

Each template produces **one Slack-ready bullet** in the daily AM post. The morning routine expands templates per person × per template ID listed in `sprint.md` for today.

## Template variables

| Token | Resolves to |
|---|---|
| `{{person}}` | crew member handle, e.g. `@famitha` |
| `{{platform}}` | platform name, e.g. `GeeksForGeeks` |
| `{{nth_account}}` | the specific account number this task uses, with ordinal, e.g. `6th` |
| `{{pool}}` | comma-separated pool from `rotation.md`, e.g. `4,5,6` |
| `{{week_label}}` | e.g. `w3-June` |
| `{{quota}}` | numeric quota for quota templates, e.g. `6` |
| `{{seo_url}}` | one URL from `config.md`, round-robin per (person, platform) per day |

If `accounts.md` says the person owns 0 accounts on a platform, **skip** the task silently for that person.

If `rotation.md`'s clamp produces a single-number "pool" because the person doesn't have enough accounts, the bullet renders as `(<that number>th account)` with no pool suffix and a `[clamped]` note.

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

### Shape E — quota (no platform, no account)

```
Write {{quota}} articles for Distribution
```

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

Expanded for `@famitha`:

```
- Submit 1 article to GeeksForGeeks (6th account) - 4,5,6 accounts for w3-June
- Hackernews community postings (6th account) - 4,5,6 accounts for w3-June
- Hackernews community engagement - (4,5,6 acc for w3-June)
- Write 6 articles for Distribution
- Quora (5,6,7 accounts) Post from Quora account (from personal accounts)
```

(Note Quora's pool is `5,6,7` because `rotation.md` gives Quora an offset of +1.)
