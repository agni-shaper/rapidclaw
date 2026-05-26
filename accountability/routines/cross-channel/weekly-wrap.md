---
name: weekly-wrap
target_channel: marketing
required_tier: superadmin
trigger_phrases: ["post the weekly wrap", "send the weekly recap", "post the weekly recap", "weekly wrap please", "draft this week's wrap"]
description: Compose a marketing-team weekly recap of what shipped + key metrics; post to #marketing on approval.
---

# Weekly Wrap (cross-channel routine)

When triggered from any channel, this routine drafts a weekly recap in the **source thread** (the thread where the sender invoked it), waits for super-admin / owner approval, and on approval posts the final version to **#marketing**.

## Source content

Pull from these sources (in order):

1. **`sites/rapidnative-website/.claude/skills/content-studio-generate-weekly-wrap/SKILL.md`** — the canonical weekly-wrap skill. Read this first; it documents the exact data sources, format, and brand voice. It lives in a sub-repo so it's not auto-discovered; read the SKILL.md with the `Read` tool and follow its instructions.
2. **`accountability/published/log.md`** (if present) — what the team has logged as shipped over the last 7 days.
3. **`sites/rapidnative-website` git log** for the last 7 days — actual code/content shipped, in case `published/log.md` is incomplete.
4. **`sites/branding`, `sites/applighter-website`, `sites/tasks`** git logs if you find evidence those repos shipped meaningful work too.

Time window: last 7 calendar days, ending at the moment the routine was invoked.

## Workflow

1. **Site prep** — before reading the skill or any site content, call `accountability/routines/sites-prepare.sh rapidnative-website` so the read happens in an isolated per-thread worktree.

2. **Generate the draft** — follow `content-studio-generate-weekly-wrap/SKILL.md` to produce the wrap. The skill defines structure and brand voice. If you have to deviate, note why in the draft.

3. **Draft in the SOURCE thread**, not the target channel. Use `slack-post.sh {{CHANNEL}} {{THREAD_TS}}`. Make the message clearly previewable — include the headline, body, and a single explicit approval ask line at the bottom:

   ```
   {{SUPERADMIN_PINGS}} / <@{{OWNER_USER_ID}}> — approve to post to #marketing?
   ```

4. **Do NOT post to #marketing yet.** Wait for an explicit approval reply in this same thread from `<@{{OWNER_USER_ID}}>` or one of the super-admins. Approval signals: "go", "approve", "ship", "post", "merge", "yes ship it". The sender's own approval (`<@{{SENDER_USER_ID}}>`) does **not** count — no self-approval, even if they're a teammate or super-admin asking on behalf of someone else.

5. **On approval**, post to `#marketing` (channel id from `channels/marketing.md` frontmatter). Top-level post, no thread_ts. Use the brand voice rules from `channels/marketing.md` (em-dashes allowed there, overriding profile.md's rule).

6. **Confirm back in the source thread** with a one-line confirmation:

   ```
   ✅ posted to #marketing — <permalink>
   ```

   Get the permalink via `chat.getPermalink` (use the slackApi helper if calling from Node; for shell, you can construct it as `https://shaper-studio.slack.com/archives/<channel_id>/p<ts_without_dot>`).

## Failure modes

- **Sender tier insufficient** — if `{{SENDER_TIER}}` is `teammate` or `unknown`, do step 1–3 (draft and ask), but make extra clear in the message that they cannot self-approve and that owner/super-admin reply is required.
- **#marketing bot not invited** — the listener is in fallback mode right now, so it can't verify the bot is actually in #marketing at draft time. If you reach step 5 and `slack-post.sh` returns `not_in_channel`, reply in the source thread with a clear error: *"The bot isn't a member of #marketing — please invite `@rapidnative-coach` to that channel before retrying."*
- **Site prep failed** — if `sites-prepare.sh` errors (no symlink, repo isn't a git repo, etc.), surface the exact error in the source thread and stop. Don't try to read the skill from main `sites/rapidnative-website` as a fallback — that'd risk colliding with another thread.

## Notes

- This routine is **idempotent at the source-thread level**: re-invoking it in the same thread before approval just produces a new draft. After approval and post, re-invoking starts fresh.
- The per-thread site worktree created by `sites-prepare.sh` will be GC'd along with the parent bot worktree after 14 days idle (per Stage 3 GC).
