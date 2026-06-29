# LetsDeployIt — pointer (not yet symlinked)

Product home: https://letsdeploy.it

## Status

**Repo not located.** The GitHub URL given by @sanket on 2026-06-25 was `https://github.com/RapidNative/letsdeployit-website` but that doesn't resolve — no repo by that name exists in the RapidNative org as of 2026-06-29:

```
$ gh repo list RapidNative
RapidNative/rapidnative-website   private
RapidNative/tasks                 private
RapidNative/reactnative-run       public
RapidNative/applighter-website    private
RapidNative/branding              private
RapidNative/service-worker-rpc    public
```

**Action needed from @sanket or @suraj:** confirm the actual GitHub location (different org name? different repo name? not yet pushed to GitHub?). Once confirmed, this file gets replaced with a symlink matching the pattern of the other sites.

## When the symlink is created

Once the repo location is confirmed, swap this pointer for a symlink:

```bash
cd ~/Documents && gh repo clone <Org>/<RepoName> letsdeployit-website
cd /Users/agni/Documents/rapidclaw/sites && \
  rm letsdeployit-website.md && \
  ln -s ~/Documents/letsdeployit-website .
```

## Until then

Treat as a "pointer .md" per CLAUDE.md "Linked projects" rules:

- **Domain:** https://letsdeploy.it
- **Workflow when work needs to happen here:** ask @sanket / @suraj for the repo URL; do not invent.
- **Brand canonical (future):** `sites/letsdeployit-website/DESIGN.md` once symlinked.
- **Strategy file (future):** `.claude/skills/growth-marketing/references/strategies/letsdeployit.md` (already referenced by `definitions/products.md`).

## Related

- `definitions/products.md` row for LetsDeployIt — updated to flag this not-yet-wired state
- `drafts/2026-06-25-architecture-refactor/decisions.md` O1 — the original decision was "symlink, matching existing pattern"; this is a temporary fallback until the repo is locatable
