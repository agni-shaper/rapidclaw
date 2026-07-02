---
name: blogs
description: Blog authoring + amplification across product blogs (rapidnative.com/blogs, applighter, letsdeployit). Sub-skill of growth-marketing. Currently a placeholder — the actual blog-internal / blog-external cron routines still run their own ad-hoc prompts against generate-blog.sh; migration to this skill is Phase 6+.
when_to_load: |
  Load when ANY of the following:
  - A cron routine is firing: blog-internal, blog-external
  - The user asks about: blog draft, blog amplification, blog SEO, blog cross-post, dev.to / GFG / Medium / Hashnode / Substack / Vocal article authoring (long-form)
voice_source: ../../../profile.md
---

# blogs

**Scaffolded placeholder.** The blog authoring + amplification pipeline currently runs through `accountability/routines/blog-internal.md` and `accountability/routines/blog-external.md`, which wrap `sites/rapidnative-website/generate-blog.sh` and post the result to `#marketing-automation` / `#ai-blog` respectively. Amplification (dev.to / GFG / Medium / Hashnode etc.) is triggered from `marketing-recon` via the `blog-amplification-YYYY-MM-DD.md` cache under `marketing/.state/`.

This skill exists to give the routine authors a clear home for blog-specific voice / templates / cross-posting rules once they're extracted from the ad-hoc prompts. Until then:

- **Blog authoring conventions** — see the routines above and `sites/rapidnative-website/.claude/skills/content-studio*` skills.
- **Blog voice** — [`../../../profile.md`](../../../profile.md) applies. Long-form has looser tone than social; teaching-first, code snippets over marketing copy.
- **Cross-post amplification** — driven by `marketing-recon`'s `article_drafts` block, consumed by `marketing-morning`'s TPL-DEVTO-ARTICLE / TPL-GFG-ARTICLE / TPL-MEDIUM-ARTICLE / TPL-HASHNODE-ARTICLE templates in [`../social-engagement/references/task-templates.md`](../social-engagement/references/task-templates.md).

## When to promote this skill from placeholder → real

- When blog voice diverges enough from `profile.md` to warrant its own reference file.
- When a `blogs/references/` dir starts filling up with per-platform (dev.to, Medium, GFG) authoring conventions.
- When more than 2 routines need to Read blog-specific rules — the current 2 (blog-internal, blog-external) don't yet.
