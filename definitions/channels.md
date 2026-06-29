# Channels

Registry of every Slack channel the bot operates in. Per-channel persona files (purpose + voice + allowed routines) live at `../channels/<name>.md` — this file is the cross-channel index.

> All channels are in the `shaper-studio.slack.com` workspace.

## Registry

| Channel | ID | Product | Owner | Tier needed to publish | Persona file | Notes |
|---|---|---|---|---|---|---|
| `#rapidnative-coach` | `C0B4HG16QP3` | rapidnative | `@agni` | superadmin | [rapidnative-coach.md](../channels/rapidnative-coach.md) | Bot home. Owner's personal accountability + drafting + catch-all. |
| `#marketing` | `C09F377FGFK` | all | `@sanket` | superadmin | [marketing.md](../channels/marketing.md) | General coordination, weekly wraps, cross-product launches. |
| `#marketing-automation` | `C0BBQ7PV34N` | all | `@sanket` | superadmin | (no persona file yet — TODO) | Distribution crew daily-task drops (Growth Squad v2). Reached by `marketing-morning/evening/recon` routines. |
| `#ai-blogs` | `C0AMG7SE1FF` | rapidnative | `@sanket` | superadmin | [ai-blogs.md](../channels/ai-blogs.md) | Internal blog drafts → publish via `blog-internal` / `blog-external`. |
| `#bi-reports` | `C0AU48KFVGU` | rapidnative | `@sanket` | superadmin | [bi-reports.md](../channels/bi-reports.md) | BI/analytics reports powered by `sites/rapidnative-website/.claude/skills/bi-*`. |
| `#seo` | `C0AFSAXMQUR` | rapidnative | `@sanket` | superadmin | [seo.md](../channels/seo.md) | SEO topics, on-page audits, Outrank queue. |
| `#user-testing` | `C09EU7C87BM` | rapidnative | `@sanket` | superadmin | [user-testing.md](../channels/user-testing.md) | User-testing sessions; daily diff captured by `user-testing-capture`. |
| `#tasks` | `C0ASK9520JG` | all | `@sanket` | teammate | [tasks.md](../channels/tasks.md) | Sprint/task ops. Companion to `sites/tasks/` repo. Tasks-cleanup approval flow lands here. |
| `#eod-updates` | `C0A8Q9HM5BN` | all | `@sanket` | teammate | [eod-updates.md](../channels/eod-updates.md) | Team EOD posts. `eod-streak-check` nudges no-EOD teammates. |
| `#collabs-and-partnerships` | `C09EY4E1X9Q` | all | `@sanket` | superadmin | [collabs-and-partnerships.md](../channels/collabs-and-partnerships.md) | Outreach drafts; `collabs-tuesday-update` posts pipeline status. |
| `#design` | `C09URB6ACCQ` | all | `@famitha` | superadmin | [design.md](../channels/design.md) | Design coordination, brand asset reviews. |
| `#community-building` | `C0B4ZA0N2G2` | all | `@gracey` | superadmin | [community-building.md](../channels/community-building.md) | Community ops, member spotlights. |
| `#lead-magnets` | `C0ABVGMQ46S` | rapidnative | `@sanket` | superadmin | [lead-magnets.md](../channels/lead-magnets.md) | Lead-gen assets, CTA copy. |
| `#affiliate-marketing` | `C09M5JX9212` | applighter, rapidnative | `@sanket` | superadmin | [affiliate-marketing.md](../channels/affiliate-marketing.md) | Affiliate program ops. |
| `#rn-coach-social` | `C0B6Q8TUVL2` | rapidnative | `@agni` | superadmin | [rn-coach-social.md](../channels/rn-coach-social.md) | Engagement scan workspace; `engagement` routine posts here. Owner ships originals. |

## Conventions

- **Bot membership prerequisite:** the bot must be `/invite`d before it can post. Listener auto-discovers which channels it's in vs which have persona files; the intersection is the "live" set.
- **Tier guard:** the `publish_tier` field in each persona file gates *who can authorise* a public post in that channel. A teammate posting in a teammate-tier channel can self-approve; a teammate asking for a superadmin-tier post needs explicit approval from `<@U09DC8L7PCZ>` / `<@U09DC8MB4KB>` / `<@U0B4FCJ8Z1Q>`.
- **Cross-channel posting:** only allowed via a declared `accountability/routines/cross-channel/<name>.md` routine + explicit approval. Today: `weekly-wrap` (source thread → posts to `#marketing` on approval).
- **Channel members list:** *hand-maintained, sourced from [`people.md`](people.md)*. No Slack API sync (per decision O5 in `drafts/2026-06-25-architecture-refactor/decisions.md`). If a channel adds/loses a member relevant to who the bot can ping, update the channel persona file.

## Allowed routines (where each cron-fired routine posts)

| Routine | Target channel |
|---|---|
| `daily`, `noon`, `friday`, `sunday`, `tasks-cleanup` | `#rapidnative-coach` |
| `blog-internal`, `blog-external` | `#rapidnative-coach` + `#ai-blogs` (split) |
| `user-testing-capture` | `#user-testing` + `#rapidnative-coach` |
| `engagement` | `#rn-coach-social` |
| `marketing-morning`, `marketing-evening`, `marketing-recon` | `#marketing-automation` |
| `gtm-weekly-pick` | `#marketing` |
| `biweekly-shoutouts` | `#marketing` |
| `collabs-tuesday-update` | `#collabs-and-partnerships` |
| `eod-streak-check` | `#eod-updates` |
| `resurface-logo-update` | `#design` (one-off) |

Full routine catalog: [`routines.md`](routines.md).
