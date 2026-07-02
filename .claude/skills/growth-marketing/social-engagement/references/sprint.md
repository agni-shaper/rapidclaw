# 7-day sprint plan

One section per day this week (Mon → Sun, IST). The morning routine matches `## YYYY-MM-DD` against today and expands the listed template IDs via `task-templates.md` × `rotation.md` × `accounts.md`, fanned out across the products listed in the day's section.

**Per-product structure (since 2026-07-02).** Each day has three product sub-headings — `### RapidNative`, `### Applighter`, `### LetsDeployIt`. Templates listed under a product fire for crew members whose `accounts.md` `products:` line includes that product. Empty product sections silently produce no tasks (useful for RN-only days or ramp-up).

**Legacy flat format.** Dates before 2026-07-02 use a flat template list under the date heading — no product sub-headings. The morning helper treats those as RapidNative-only (matches pre-refactor behavior). Kept for history.

**Rolling cadence.** Edit this file each Friday (or Sunday) to set next week's dates. The routine refuses to run if today's date isn't found as a heading.

**Weekends.** Sat/Sun sections exist for documentation, but `guard_working_day` exits before reading sprint.md on weekends + holidays. No tasks fire.

---

## 2026-06-15 (Mon)

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL

## 2026-06-16 (Tue)

- TPL-MEDIUM-ARTICLE
- TPL-REDDIT-POST
- TPL-REDDIT-ENGAGE
- TPL-DISTRO-6
- TPL-TWITTER-PERSONAL

## 2026-06-17 (Wed)

- TPL-DEVTO-ARTICLE
- TPL-QUORA-POST
- TPL-QUORA-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL

## 2026-06-18 (Thu)

- TPL-HASHNODE-ARTICLE
- TPL-FB-POST
- TPL-COMMUNITY-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL

## 2026-06-19 (Fri)

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL

## 2026-06-20 (Sat)

- (off — guard_working_day skips)

## 2026-06-21 (Sun)

- (off — guard_working_day skips)

## 2026-06-22 (Mon) ← TODAY

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-06-23 (Tue)

- TPL-MEDIUM-ARTICLE
- TPL-REDDIT-POST
- TPL-REDDIT-ENGAGE
- TPL-DISTRO-6
- TPL-TWITTER-PERSONAL

## 2026-06-24 (Wed)

- TPL-DEVTO-ARTICLE
- TPL-QUORA-POST
- TPL-QUORA-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-06-25 (Thu)

- TPL-HASHNODE-ARTICLE
- TPL-FB-POST
- TPL-COMMUNITY-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-06-26 (Fri)

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-06-27 (Sat)

- (off — guard_working_day skips)

## 2026-06-28 (Sun)

- (off — guard_working_day skips)

## 2026-06-29 (Mon) ← TODAY

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-06-30 (Tue)

- TPL-MEDIUM-ARTICLE
- TPL-REDDIT-POST
- TPL-REDDIT-ENGAGE
- TPL-DISTRO-6
- TPL-TWITTER-PERSONAL

## 2026-07-01 (Wed)

- TPL-DEVTO-ARTICLE
- TPL-QUORA-POST
- TPL-QUORA-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-07-02 (Thu)

### RapidNative

- TPL-HASHNODE-ARTICLE
- TPL-FB-POST
- TPL-COMMUNITY-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL
- TPL-TWITTER-PERSONAL

### Applighter

- TPL-HASHNODE-ARTICLE
- TPL-FB-POST
- TPL-COMMUNITY-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL
- TPL-TWITTER-PERSONAL

### LetsDeployIt

- TPL-HASHNODE-ARTICLE
- TPL-FB-POST
- TPL-COMMUNITY-ENGAGE
- TPL-DISTRO-6
- TPL-QUORA-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-07-03 (Fri)

### RapidNative

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

### Applighter

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

### LetsDeployIt

- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
- TPL-TWITTER-PERSONAL

## 2026-07-04 (Sat)

- (off — guard_working_day skips)

## 2026-07-05 (Sun)

- (off — guard_working_day skips)

---

## Next week's slate (template — copy + edit dates each Friday)

```
## YYYY-MM-DD (Mon)

### RapidNative
- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL

### Applighter
- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL

### LetsDeployIt
- TPL-GFG-ARTICLE
- TPL-HN-POST
- TPL-HN-ENGAGE
- TPL-DISTRO-6
- TPL-LINKEDIN-PERSONAL
```

(…and so on for Tue–Fri. See `task-templates.md` for the full list of TPL- IDs. Each product block can carry a different template list — copy identical lists only if you want simultaneous per-product coverage.)
