You are running the morning routine for rapidnative-coach. The LaunchAgent fires at 11:30 local. **This is the primary daily push for original posts** — surface what shipped, what stalled, what to ship next.

## Read first

- `profile.md` (identity, voice, pillars, goal)
- `CLAUDE.md`
- `accountability/goals.md`
- `accountability/engagement-strategy.md`
- `published/log.md` if present (last ~5 entries — what shipped recently)
- `inbox.md` if present (raw thoughts ready to triage)

## Step 1 — live status

Post a top-level status to #rapidnative-coach and capture its ts so you can update in place.

```bash
STATUS_TS=$(accountability/routines/slack-status.sh post C0B4HG16QP3 - <<'EOF'
🔄 *Morning routine* (run.sh daily)
▸ scanning git since last fetch
EOF
)
```

## Step 2 — git scan (if relevant to this bot's pillars)

If the bot's goal involves shipping code, scan recent commits across the owner's `~/projects/`:

```bash
for d in ~/projects/*/; do
  echo "=== $d ==="
  git -C "$d" log --since='24 hours ago' --pretty=format:'%h %ad %s' --date=short 2>/dev/null | head -20
done
```

Pay special attention to anything that overlaps with the bot's pillars (see `profile.md`).

## Step 3 — surface 1-3 notable items

For each notable item worth posting about (user-visible features, releases, demos, milestones — skip refactors/deps/dotfiles), draft a candidate per the pillar that fits. Post each as its own top-level message in #rapidnative-coach with the drafted text + the action mechanism (Twitter intent URL for X, copy-paste block for LinkedIn / Reddit).

Apply the voice rules from `profile.md` during drafting, not after.

## Step 4 — surface inbox + stalled drafts

If `inbox.md` has items: pick top 1-3 that pair with shipped work or current pillars.
If `drafts/` exists: list folders whose `meta.yml status:` is `drafting` and whose newest file mtime is >3 days old.

Single closer message in Slack covering both.

## Step 5 — finalize

Update the status message to `✅ Morning routine complete` with a one-line summary (N candidates posted, M inbox items surfaced, K stalled drafts flagged).

## Voice & don'ts

- Apply rules from `profile.md` Voice section. No em dashes, no hashtags the owner didn't ask for, no corporate filler.
- Don't post on the owner's social platforms — drafts only. They ship.
- Don't ask clarifying questions unless genuinely ambiguous.

## Failure modes

- **No notable commits and inbox empty**: post a single one-liner status saying so + "anything else worth posting today?"
- **Slack post fails**: log to stderr, exit non-zero. No fallback channel.
- **browser-use hangs**: abort visual capture, post text-only.
