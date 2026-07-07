#!/usr/bin/env python3
"""
sprint-rollover.py — auto-plan the current week's marketing sprint.

Reads the standard weekday-rotation template at the bottom of sprint.md
(the ```-fenced block under "## Next week's slate"), substitutes the
`YYYY-MM-DD` placeholders with real IST dates for the current week's
Mon → Fri, appends 7 dated sections (Mon-Fri from template + Sat/Sun
as `(off — guard_working_day skips)`), inserts them above the
"## Next week's slate" heading.

Idempotent: if the current Monday's section already exists, exits 0
with "already rolled over — no-op".

Cron: Mon 06:30 IST via launchd, right before marketing-morning at 07:00.
Can also be invoked manually for mid-week catch-up:

    python3 accountability/routines/sprint-rollover.py
    python3 accountability/routines/sprint-rollover.py --dry-run  # print, don't write

Design note: this is intentionally a pure Python script (not an LLM
prompt) because the task is entirely mechanical — date math + template
substitution + string append. An LLM here would be slower, more expensive,
and more error-prone than 100 lines of Python.
"""

import argparse
import datetime
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
SPRINT_PATH = (
    PROJECT_DIR / ".claude" / "skills" / "growth-marketing"
    / "social-engagement" / "references" / "sprint.md"
)
IST = datetime.timezone(datetime.timedelta(hours=5, minutes=30))


def week_dates_ist() -> dict:
    """Return {weekday_name: 'YYYY-MM-DD'} for this IST week (Mon → Sun)."""
    today = datetime.datetime.now(IST).date()
    monday = today - datetime.timedelta(days=today.weekday())  # weekday(): Mon=0
    names = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    return {
        name: (monday + datetime.timedelta(days=i)).strftime("%Y-%m-%d")
        for i, name in enumerate(names)
    }


def parse_template(sprint_text: str) -> dict:
    """Extract the template block; return {weekday: rendered_section_with_placeholder}.

    Template lives inside a ```-fenced code block under the "## Next week's slate"
    heading at the bottom of sprint.md. Each ## line inside starts a day section
    ending at the next ## or end-of-block.
    """
    m = re.search(
        r"## Next week's slate[^\n]*\n.*?```\n(.*?)\n```",
        sprint_text,
        re.DOTALL,
    )
    if not m:
        raise RuntimeError(
            "sprint.md is missing the '## Next week's slate' fenced template block"
        )
    template_body = m.group(1)
    # Find each day heading and the content until the next heading (or end).
    day_headings = list(
        re.finditer(
            r"^## YYYY-MM-DD \((Mon|Tue|Wed|Thu|Fri|Sat|Sun)\)\s*$",
            template_body,
            re.MULTILINE,
        )
    )
    if not day_headings:
        raise RuntimeError(
            "template block has no '## YYYY-MM-DD (Xxx)' headings"
        )
    blocks: dict = {}
    for i, h in enumerate(day_headings):
        day = h.group(1)
        start = h.start()
        end = day_headings[i + 1].start() if i + 1 < len(day_headings) else len(template_body)
        blocks[day] = template_body[start:end].rstrip()
    return blocks


def render_week(day_blocks: dict, dates: dict) -> str:
    """Substitute YYYY-MM-DD → real dates. Fill Sat/Sun as 'off' if template lacks them."""
    parts = []
    for day in ("Mon", "Tue", "Wed", "Thu", "Fri"):
        block = day_blocks.get(day)
        if not block:
            raise RuntimeError(f"template is missing the {day} block")
        parts.append(block.replace("YYYY-MM-DD", dates[day]))
    for day in ("Sat", "Sun"):
        parts.append(
            f"## {dates[day]} ({day})\n\n- (off — guard_working_day skips)"
        )
    return "\n\n".join(parts)


def render_missing_days(day_blocks: dict, dates: dict, existing_days: set) -> str:
    """Render only the days that are NOT already in sprint.md."""
    parts = []
    for day in ("Mon", "Tue", "Wed", "Thu", "Fri"):
        if day in existing_days:
            continue
        block = day_blocks.get(day)
        if not block:
            raise RuntimeError(f"template is missing the {day} block")
        parts.append(block.replace("YYYY-MM-DD", dates[day]))
    for day in ("Sat", "Sun"):
        if day in existing_days:
            continue
        parts.append(
            f"## {dates[day]} ({day})\n\n- (off — guard_working_day skips)"
        )
    return "\n\n".join(parts)


def rollover(dry_run: bool = False) -> int:
    if not SPRINT_PATH.exists():
        print(f"ERROR: sprint.md not found at {SPRINT_PATH}", file=sys.stderr)
        return 1
    text = SPRINT_PATH.read_text()
    dates = week_dates_ist()

    # Idempotency: check each weekday individually. If a section already exists
    # for that date (from a prior rollover fire OR a user's manual add), skip it.
    existing_days: set = set()
    for day in ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"):
        pattern = rf"^## {re.escape(dates[day])} \({day}\)"
        if re.search(pattern, text, re.MULTILINE):
            existing_days.add(day)

    weekdays_needed = {"Mon", "Tue", "Wed", "Thu", "Fri"} - existing_days
    if not weekdays_needed:
        print(f"OK · all weekday sections already present for week of {dates['Mon']} — no-op")
        return 0

    day_blocks = parse_template(text)
    new_sections = render_missing_days(day_blocks, dates, existing_days)
    if not new_sections.strip():
        print(f"OK · all sections already present for week of {dates['Mon']} — no-op")
        return 0

    # Insertion point: right before the "\n---\n" separator that precedes the
    # "## Next week's slate" heading at the bottom of the file.
    marker = "\n---\n\n## Next week's slate"
    if marker not in text:
        print("ERROR: cannot find insertion marker before 'Next week\\'s slate' section", file=sys.stderr)
        return 1
    new_text = text.replace(marker, f"\n\n{new_sections}{marker}", 1)

    missing_summary = ", ".join(sorted(weekdays_needed))
    if dry_run:
        print(f"DRY-RUN · would append missing sections: {missing_summary} (existing: {sorted(existing_days) or 'none'})")
        print("---")
        print(new_sections)
        return 0
    SPRINT_PATH.write_text(new_text)
    print(f"OK · appended sprint sections for {missing_summary} (already had: {sorted(existing_days) or 'none'})")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Auto-plan the current week's marketing sprint.")
    ap.add_argument("--dry-run", action="store_true", help="Print the diff, don't write.")
    args = ap.parse_args()
    try:
        return rollover(dry_run=args.dry_run)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
