---
name: weekly-wrap
description: Compose the team's weekly recap (what shipped + key metrics across all 3 products) and, on approval, post it to #marketing. Source content pulls from sites/rapidnative-website's content-studio-generate-weekly-wrap skill + git logs across linked sites + accountability/published/log.md.
when_to_load: |
  Load when ANY of the following:
  - User says "post the weekly wrap" / "send the weekly recap" / "weekly wrap please" / "draft this week's wrap"
  - User asks "what shipped this week across the company"
  - The cross-channel routine `weekly-wrap.md` fires (Fri 17:00 or on-demand)
voice_source: ../../profile.md
---

# weekly-wrap

Composes the marketing-team weekly recap. Lives at coach-level; *defers brand voice and structure to the RN site's existing skill*.

## Read these first

1. **`sites/rapidnative-website/.claude/skills/content-studio-generate-weekly-wrap/SKILL.md`** — the canonical brand-voice + structure spec for the wrap. Lives in a sub-repo so it's not auto-discovered; Read it explicitly. **Don't deviate from its format.** If you have to, note why in the draft.
2. `accountability/published/log.md` (if present) — what the team has logged as shipped over the last 7 days.
3. `accountability/routines/cross-channel/weekly-wrap.md` — the cross-channel routine that triggers this skill. It handles routing, approval gating, target channel selection.
4. `definitions/products.md` + `definitions/people.md` — for cross-product attribution.

## Source content (gather in order)

1. **`accountability/published/log.md`** for the last 7 days, if it exists.
2. **`sites/rapidnative-website` git log** for last 7 days — actual code/content shipped.
3. **`sites/branding`, `sites/applighter-website`, `sites/tasks` git logs** if those repos shipped meaningful work too. (LetsDeployIt added once symlinked.)
4. **Anything in `drafts/`** flagged as shipped this week.
5. **Metrics** if the user / channel has them — MRR snapshot, signup count, key launches.

Time window: last 7 calendar days ending at the moment the routine was invoked.

## Workflow

This skill is *invoked from* the cross-channel routine `accountability/routines/cross-channel/weekly-wrap.md` — that file owns approval-gate UX. This skill owns composition.

1. **Site prep** — before reading any site content, run `accountability/routines/sites-prepare.sh rapidnative-website` so the read happens in an isolated per-thread worktree. Same for any other site you'll read.
2. **Read the content-studio-generate-weekly-wrap skill** (step 1 above) — that's authoritative for format + voice. The structure usually has:
   - Headline (1 line, plain English what we did this week)
   - Bullets (what shipped, who shipped it — name + handle)
   - Numbers (where we have them)
   - One forward-looking line ("next week we…")
3. **Draft in the source thread, not the target channel.** Use `slack-post.sh <SOURCE_CHANNEL> <THREAD_TS>` with the rendered wrap.
4. **Ask for explicit approval.** Pattern from the cross-channel routine:
   ```
   <@U09DC8L7PCZ> or <@U09DC8MB4KB> or <@U0B4FCJ8Z1Q> — approve to post to #marketing?
   ```
5. **WAIT for approval.** Don't auto-post. Approval = `<@OWNER_OR_SUPERADMIN>` saying "go" / "approve" / "ship" / "post" / "yes ship it" in the source thread. Sender's own approval doesn't count (no self-approval).
6. **On approval:** post to `#marketing` (`C09F377FGFK`). Top-level post, no thread_ts. Voice rules from `channels/marketing.md` (em-dashes ARE allowed there, overriding profile.md).
7. **Confirm back in source thread** with permalink:
   ```
   ✅ posted to #marketing — https://shaper-studio.slack.com/archives/C09F377FGFK/p<ts_without_dot>
   ```

## What this skill does NOT do

- Doesn't generate visual assets (banner / social card for the wrap). If the user wants a graphic, delegate to `creator-studio` (Phase 4) or invoke `render-html.sh` / `gen-image.sh` directly as one-shot.
- Doesn't summarize *engineering* progress in technical depth — that's blog content territory. The wrap is marketing-team-flavoured.
- Doesn't replace the cross-channel routine `weekly-wrap.md` — that file owns the approval-gate workflow. This skill owns content.

## Anti-hallucination guards

1. **Never claim a feature shipped without git-log evidence.** If `published/log.md` says X shipped but git history doesn't show it, flag the discrepancy in the draft.
2. **Never attribute work to a teammate not in `definitions/people.md`.** No invented handles.
3. **If a metric is missing, say "metric not available this week" rather than fabricating.** Drafts that hallucinate numbers will be caught at approval.
4. **Cross-product clarity.** If a bullet is about Applighter, say so. Don't let RapidNative items absorb the entire wrap.

## Failure modes (from the cross-channel routine)

- Sender tier insufficient → do steps 1-4 anyway (draft + ask); make explicit they cannot self-approve.
- `#marketing` bot not invited → `slack-post.sh` returns `not_in_channel`; reply in source thread with "invite `@rapidnative-coach` to #marketing first".
- Site prep failed → surface exact error in source thread; don't fall back to shared `sites/rapidnative-website` (collision risk).

## Related skills

- `sites/rapidnative-website/.claude/skills/content-studio-generate-weekly-wrap` — the brand-voice canonical (REQUIRED read)
- `growth-marketing` — informs the marketing-team context the wrap drops into
- `creator-studio` (Phase 4) — when the wrap wants a graphic
