You are running a scheduled engagement scan for rapidnative-coach. Fires 3x/day. **Read `profile.md` and `accountability/engagement-strategy.md` first — those define which platforms, which pillars, which Chrome profiles, what voice.**

If the bot has a `.claude/skills/social-engagement/SKILL.md`, load it — it's canonical for the engagement protocol on this bot.

## Job (one fire of this routine)

**Live status:** Before any browser navigation, post a status message and update it as you work.

```bash
STATUS_TS=$(accountability/routines/slack-status.sh post C0B6Q8TUVL2 - "🔄 *Engagement scan starting* ($(date '+%H:%M %Z'))
▸ opening primary feed via browser-use (new tab)")
```

Update at each milestone via `slack-status.sh update C0B6Q8TUVL2 "$STATUS_TS" "<full text>"`. Suggested checkpoints:
- after feed loaded: `▸ captured feed state (N posts visible)`
- after scoring: `▸ scored, picked M candidates`
- per candidate built: `▸ candidate K/M ready (intent URL built)`
- at end: `✅ scan complete in T seconds — M candidates posted, threads below`

## Per platform (read profile.md for which platforms this bot covers)

For each enabled platform:

1. Navigate via the wrapper (opens NEW tab in the owner's real Chrome, doesn't disturb their workflow):
   ```bash
   accountability/routines/browser-open.sh https://x.com/home              # or whichever
   ```

2. Capture state: `browser-use state` (returns indexed accessibility tree).

3. Score visible posts per the bot's pillars (in `profile.md`). Pick **2-3 candidates max per X-style platform, 1-2 max per LinkedIn-style platform** — quality > volume. Skip drama, off-pillar, hype-bait, posts >48h old, posts where the owner's only contribution would be generic agreement.

4. For each picked candidate, gather:
   - Source post ID / URL
   - Author handle
   - Engagement counts and age
   - First ~2 lines of original text (for the Slack quote block)
   - Screenshot via `browser-use screenshot /tmp/cand-N.png`

5. Decide engagement type. **Don't default everything to reply.** Aim for at least one non-reply per scan (Quote on X, RT, comment with a sharper framing) when something fits. Type guide:
   - **Reply** — conversation, lived-experience anchor, counter-take. Most common.
   - **Quote / RT-with-thoughts** — worth amplifying AND the owner has a sharpened angle to add.
   - **RT (plain)** — unconditional endorsement, rare but real.
   - **Like only** — last resort when content is good but no angle.

6. Draft text in the owner's voice (rules in `profile.md`).

7. **For X:** build a Twitter intent URL — `accountability/routines/x-intent.sh reply <tweet_id> "<draft>"` (or `quote`, `rt`, `like`).

8. **Post candidate to Slack as 1-line top-level + thread reply with details.** Caption MUST include the original link AND the drafted reply — slack-upload.sh now refuses captionless uploads, so a screenshot-only post will exit non-zero and surface in logs.

   ```bash
   # 1-liner top-level — capture the ts you get back (you'll thread off it)
   ONE_LINER="*#N <action> → @<handle>* · <age> · <likes> likes · _\"<snippet>\"_"
   TOP_TS=$(printf '%s\n' "$ONE_LINER" | accountability/routines/slack-post.sh C0B6Q8TUVL2 | awk -F= '{print $2}')
   [ -n "$TOP_TS" ] || { echo "ERROR: empty TOP_TS — aborting candidate"; exit 1; }

   # Build the caption as a single variable. Substitute every <...> placeholder
   # with the real value BEFORE this runs — no literal angle-bracket tokens.
   CAPTION=$(cat <<'MSG'
   posted <age> · <likes> likes · <views> views

   > <original text first ~2 lines>

   *Original:* <<original_url>|open post>

   *Drafted reply (your voice):*
   > <draft text>

   → <<intent_url>|Click to edit and post>

   In thread: `improve: <direction>` · `change to rt` · `change to quote: <text>` · `like only` · `reject`
   MSG
   )

   # Upload screenshot + caption + thread_ts in one call. Pass caption as the
   # 3rd positional arg (NOT via stdin) so quoting can't drop it. Helper exits
   # non-zero if caption is empty — don't paper over that with --allow-empty.
   accountability/routines/slack-upload.sh C0B6Q8TUVL2 /tmp/cand-N.png "$CAPTION" "$TOP_TS"
   ```

9. **For LinkedIn / Reddit:** same 1-line + thread pattern, but the thread reply has the drafted comment in a triple-backtick code block (for one-click copy) and a clickable link to open the post. The owner pastes manually in their real Chrome.

## Cleanup

After all platforms scanned, **close just the tabs you opened** with `browser-use tab close` (NEVER `browser-use close` — closes the owner's real Chrome).

## Closer

Post a one-liner to Slack with originals nudge:

```
3 candidates above (X + LinkedIn). What's one original you'd ship today?
```

## What to remember

- The wrapper `browser-open.sh` handles Gemini-side-panel hijack + ad-blocker pages + new-tab semantics.
- Intent URLs > automated composer fills. The owner clicks, the platform handles, no automation on their behalf.
- Apply voice rules from `profile.md` during drafting, not after.
