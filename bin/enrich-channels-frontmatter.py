#!/usr/bin/env python3
"""Phase 5 — enrich channels/*.md frontmatter with product/owner/members/allowed_skills.

Reads the cross-channel index from definitions/channels.md and applies the per-channel
data to each persona file's YAML frontmatter. Idempotent: only adds missing fields,
never overwrites or reorders existing ones.

Run:
    python3 bin/enrich-channels-frontmatter.py
    python3 bin/enrich-channels-frontmatter.py --dry-run
"""

import argparse
import re
import sys
from pathlib import Path

PROJECT = Path("/Users/agni/Documents/rapidclaw")
CHANNELS_DIR = PROJECT / "channels"

# Hand-maintained per decision O5 (no Slack-API sync). Members are best-effort
# based on channel purpose + known team roster. Adjust by hand as needed.
TEAM = {
    "agni":    "<@U0B4FCJ8Z1Q>",   # bot owner
    "sanket":  "<@U09DC8L7PCZ>",   # CEO superadmin
    "suraj":   "<@U09DC8MB4KB>",   # CTO superadmin
    "riya":    "<@U09CXCYV7D1>",
    "rishav":  "<@U09CUJ9ATM1>",
    "russel":  "<@U09DFJJGS1X>",
    "famitha": "<@U09LL9JTDM5>",
    "gracey":  "<@U0B467S1VEG>",
}
ALL_TEAM = list(TEAM.values())
SUPERADMINS = [TEAM["sanket"], TEAM["suraj"]]

# Routine → skill mapping (Phase 2 scaffolds). Source: definitions/skills.md
ROUTINE_TO_SKILLS = {
    "daily":                  [],   # owner-accountability, no skill
    "noon":                   [],
    "friday":                 [],
    "sunday":                 [],
    "eod-streak-check":       ["eod-nudges", "leave"],
    "engagement":             [],   # social-engagement skill not yet scaffolded
    "user-testing-capture":   ["user-testing"],
    "tasks-cleanup":          ["task-management", "bug-tracking", "leave"],
    "blog-internal":          [],   # thin wrapper around generate-blog.sh
    "blog-external":          [],
    "marketing-recon":        ["growth-marketing"],
    "marketing-morning":      ["growth-marketing", "leave"],
    "marketing-evening":      ["growth-marketing"],
    "gtm-weekly-pick":        ["growth-marketing", "task-management"],
    "biweekly-shoutouts":     ["growth-marketing"],
    "collabs-tuesday-update": [],   # collabs skill not yet scaffolded
    "resurface-logo-update":  [],   # one-off, retire candidate
}

# Per-channel enrichment data. Channel name → fields to add.
ENRICH = {
    "rapidnative-coach": {
        "product": "rapidnative",
        "owner":   TEAM["agni"],
        "members": [TEAM["agni"], *SUPERADMINS],
    },
    "rn-coach-social": {
        "product": "rapidnative",
        "owner":   TEAM["agni"],
        "members": [TEAM["agni"]],
    },
    "marketing": {
        "product": "all",
        "owner":   TEAM["sanket"],
        "members": ALL_TEAM,
    },
    "ai-blogs": {
        "product": "rapidnative",
        "owner":   TEAM["sanket"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["suraj"], TEAM["rishav"]],
    },
    "bi-reports": {
        "product": "rapidnative",
        "owner":   TEAM["sanket"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["suraj"]],
    },
    "seo": {
        "product": "rapidnative",
        "owner":   TEAM["sanket"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["rishav"]],
    },
    "user-testing": {
        "product": "rapidnative",
        "owner":   TEAM["sanket"],
        "members": ALL_TEAM,
    },
    "tasks": {
        "product": "all",
        "owner":   TEAM["sanket"],
        "members": ALL_TEAM,
    },
    "eod-updates": {
        "product": "all",
        "owner":   TEAM["sanket"],
        "members": ALL_TEAM,
    },
    "collabs-and-partnerships": {
        "product": "all",
        "owner":   TEAM["sanket"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["suraj"]],
    },
    "design": {
        "product": "all",
        "owner":   TEAM["famitha"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["famitha"], TEAM["russel"]],
    },
    "community-building": {
        "product": "all",
        "owner":   TEAM["gracey"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["gracey"]],
    },
    "lead-magnets": {
        "product": "rapidnative",
        "owner":   TEAM["sanket"],
        "members": [TEAM["agni"], TEAM["sanket"], TEAM["famitha"]],
    },
    "affiliate-marketing": {
        "product": "applighter,rapidnative",
        "owner":   TEAM["sanket"],
        "members": [TEAM["agni"], TEAM["sanket"]],
    },
}


def enrich(path: Path, dry_run: bool) -> bool:
    """Returns True if the file was changed (or would be changed in dry-run)."""
    name = path.stem
    if name not in ENRICH:
        print(f"  [{name}] no enrichment data — SKIPPED")
        return False

    content = path.read_text()
    # Find the YAML frontmatter block
    m = re.match(r"^(---\s*\n)(.*?)(\n---\s*\n)", content, re.DOTALL)
    if not m:
        print(f"  [{name}] no frontmatter block — SKIPPED")
        return False

    fm_open, fm_body, fm_close = m.group(1), m.group(2), m.group(3)
    after_fm = content[m.end():]

    fields = ENRICH[name]
    additions = []

    # Add product
    if not re.search(r"^product:", fm_body, re.MULTILINE):
        additions.append(f"product: {fields['product']}")

    # Add owner
    if not re.search(r"^owner:", fm_body, re.MULTILINE):
        additions.append(f"owner: {fields['owner']}")

    # Add members (flow-style YAML for compactness)
    if not re.search(r"^members:", fm_body, re.MULTILINE):
        members_str = ", ".join(fields["members"])
        additions.append(f"members: [{members_str}]")

    # Add allowed_skills (computed from existing allowed_routines)
    if not re.search(r"^allowed_skills:", fm_body, re.MULTILINE):
        # Parse allowed_routines
        ar_match = re.search(r"^allowed_routines:\s*\[(.*?)\]\s*$", fm_body, re.MULTILINE)
        if ar_match:
            routines = [r.strip() for r in ar_match.group(1).split(",") if r.strip()]
            skills = []
            for r in routines:
                for s in ROUTINE_TO_SKILLS.get(r, []):
                    if s not in skills:
                        skills.append(s)
            skills_str = ", ".join(skills)
            additions.append(f"allowed_skills: [{skills_str}]")
        else:
            additions.append("allowed_skills: []")

    if not additions:
        print(f"  [{name}] already enriched — no changes")
        return False

    new_fm = fm_body.rstrip("\n") + "\n" + "\n".join(additions) + "\n"
    new_content = fm_open + new_fm + fm_close + after_fm

    if dry_run:
        print(f"  [{name}] would add: {len(additions)} fields")
        for a in additions:
            print(f"    + {a}")
    else:
        path.write_text(new_content)
        print(f"  [{name}] added: {len(additions)} fields")

    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    print(f"Channels dir: {CHANNELS_DIR}")
    print(f"Mode: {'dry-run' if args.dry_run else 'write'}\n")

    changed = 0
    for path in sorted(CHANNELS_DIR.glob("*.md")):
        if enrich(path, args.dry_run):
            changed += 1

    print(f"\n{'Would change' if args.dry_run else 'Changed'} {changed} files.")


if __name__ == "__main__":
    main()
