# Marketing automation — standing config

Standing reference data the daily distribution cycle reads. **Until full migration in Phase 6**, this is a pointer to the legacy `marketing/config.md`. Update both files in lockstep.

> **Source mirror:** `../../../../marketing/config.md` (legacy canonical). When migrating a routine to load from this skill, copy the relevant section here verbatim and delete the legacy file in Phase 6.

## What's in the legacy file

- **SEO domains** — rotate target URLs in posts/comments (rapidnative.com, blog/*, letsdeploy.it, applighter.com).
- **Zoho mailboxes** — per-platform signup/support/reply mailboxes (outreach@, community@, publish@, social@, hn@).
- **Medium subdomains / publications** — owned publications list.
- **Standing community URLs** — always-on watch list for marketing-recon to check daily.

## Why this file is a pointer (not the canonical) yet

The legacy `marketing/config.md` is consumed directly by `accountability/routines/marketing-recon.md` today (it's referenced in the routine's "Read first" section). Replacing the routine to read from this skill location is the migration step. Until that migration lands, the legacy file is canonical to avoid breaking the daily cycle.

Per the Phase 2 migration order in `drafts/2026-06-25-architecture-refactor/plan.md`, the swap is:

1. Skill scaffold created (this commit).
2. Verify skill files mirror legacy verbatim.
3. Replace the routine prompt to Read from this skill location.
4. Run side-by-side for one cron cycle (07:00 IST tomorrow).
5. Verify output parity in `#marketing-automation`.
6. Delete `marketing/config.md` + `marketing/rotation.md` + `marketing/accounts.md` (legacy mirrors).

## Action: when this file becomes canonical

When you migrate `marketing-recon.md` (or any other routine) to load from this skill instead of from `marketing/`:

1. Copy the relevant section of `marketing/config.md` verbatim into this file.
2. Update the legacy file to add a "MIGRATED — read `~/Documents/rapidclaw/.claude/skills/growth-marketing/references/config.md`" pointer at the top.
3. Run the routine once manually to confirm the new path works.
4. Wait one cron cycle; verify output.
5. Delete the legacy section. Leave the pointer in place until Phase 6.
