#!/usr/bin/env python3
"""Phase 3 of the architecture refactor — create + backfill the sqlite DB.

One-shot migration. Idempotent: if the DB already exists, schema is left
alone (no destructive re-creation). Backfill INSERTs use INSERT OR IGNORE
so re-running won't duplicate rows.

DB location: ~/.config/claude/rapidnative-coach.sqlite (per decision O3 in
drafts/2026-06-25-architecture-refactor/decisions.md).

Sources backfilled this run:
- accountability/leave.md          → leave_entries
- accountability/holidays.md       → holidays
- accountability/reminders/*.md    → reminders (one row per per-day file)
- accountability/state/tasks-cleanup-proposal-*.json → tasks_cleanup_proposals

Tables created but not backfilled (start empty):
- eod_streaks · routine_runs · user_testing_issues · bug_reports · marketing_recon

Run:
    python3 bin/migrate-to-sqlite.py
    python3 bin/migrate-to-sqlite.py --dry-run    # parse + report, no writes
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from pathlib import Path

# ─── Locations ───────────────────────────────────────────────────────────────

HOME = Path.home()
PROJECT = Path("/Users/agni/Documents/rapidclaw")
DB_PATH = HOME / ".config" / "claude" / "rapidnative-coach.sqlite"

LEAVE_MD = PROJECT / "accountability" / "leave.md"
HOLIDAYS_MD = PROJECT / "accountability" / "holidays.md"
REMINDERS_DIR = PROJECT / "accountability" / "reminders"
STATE_DIR = PROJECT / "accountability" / "state"

# ─── Schema (version 1) ──────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS schema_version (
  version    INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (datetime('now')),
  notes      TEXT
);

CREATE TABLE IF NOT EXISTS leave_entries (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  slack_id   TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date   TEXT NOT NULL,
  note       TEXT,
  status     TEXT NOT NULL DEFAULT 'active',   -- 'active' | 'past'
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (slack_id, start_date, end_date)
);
CREATE INDEX IF NOT EXISTS idx_leave_window ON leave_entries(status, start_date, end_date);

CREATE TABLE IF NOT EXISTS holidays (
  date       TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  region     TEXT,
  status     TEXT NOT NULL DEFAULT 'upcoming', -- 'upcoming' | 'past'
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS eod_streaks (
  slack_id  TEXT NOT NULL,
  date      TEXT NOT NULL,                    -- YYYY-MM-DD IST
  posted    INTEGER NOT NULL,                 -- 0 | 1
  on_leave  INTEGER NOT NULL DEFAULT 0,       -- 0 | 1
  PRIMARY KEY (slack_id, date)
);
CREATE INDEX IF NOT EXISTS idx_eod_recent ON eod_streaks(date DESC);

CREATE TABLE IF NOT EXISTS reminders (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  fire_date   TEXT NOT NULL,                  -- YYYY-MM-DD IST
  fire_time   TEXT,                           -- HH:MM IST, optional
  channel_id  TEXT,
  thread_ts   TEXT,
  body        TEXT NOT NULL,
  created_by  TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  fired_at    TEXT,
  status      TEXT NOT NULL DEFAULT 'pending' -- 'pending' | 'fired' | 'cancelled'
);
CREATE INDEX IF NOT EXISTS idx_reminders_pending ON reminders(fire_date, status);

CREATE TABLE IF NOT EXISTS routine_runs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  routine     TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  ended_at    TEXT,
  exit_code   INTEGER,
  log_path    TEXT,
  notes       TEXT
);
CREATE INDEX IF NOT EXISTS idx_routine_runs_recent ON routine_runs(routine, started_at DESC);

CREATE TABLE IF NOT EXISTS user_testing_issues (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  summary     TEXT NOT NULL,
  testers_hit INTEGER NOT NULL DEFAULT 1,
  priority    TEXT,                           -- P0/P1/P2/P3
  status      TEXT NOT NULL DEFAULT 'open',   -- 'open' | 'resolved' | 'wontfix'
  source_url  TEXT,
  first_seen  TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen   TEXT NOT NULL DEFAULT (datetime('now')),
  created_by  TEXT
);

CREATE TABLE IF NOT EXISTS bug_reports (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  slug        TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  priority    TEXT,
  assignee    TEXT,
  status      TEXT NOT NULL DEFAULT 'open',   -- 'open' | 'in-progress' | 'resolved' | 'wontfix'
  product     TEXT,                           -- 'rapidnative' | 'applighter' | 'letsdeployit'
  source_url  TEXT,
  reported_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tasks_cleanup_proposals (
  reply_ts      TEXT PRIMARY KEY,             -- Slack reply ts (matches the JSON filename)
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  approved_at   TEXT,
  approved_by   TEXT,
  proposal_json TEXT NOT NULL,                -- full JSON blob
  status        TEXT NOT NULL DEFAULT 'pending' -- 'pending' | 'approved' | 'applied' | 'rejected'
);

CREATE TABLE IF NOT EXISTS marketing_recon (
  recon_date  TEXT PRIMARY KEY,               -- YYYY-MM-DD
  platforms   TEXT NOT NULL,                  -- JSON array
  findings    TEXT NOT NULL,                  -- JSON blob
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
"""

# ─── Parsing helpers ─────────────────────────────────────────────────────────

LEAVE_LINE_RE = re.compile(
    r"^-\s*`?<@(?P<sid>U[A-Z0-9]+)>`?"
    r"[^0-9]*"
    r"(?P<start>\d{4}-\d{2}-\d{2})"
    r"\s*to\s*"
    r"(?P<end>\d{4}-\d{2}-\d{2})"
    r"\s*(?:·|-)\s*"
    r"(?P<note>.*)$"
)

HOLIDAY_LINE_RE = re.compile(
    r"^-\s*(?P<date>\d{4}-\d{2}-\d{2})\s*(?:·|-)\s*(?P<name>.*)$"
)


def parse_leave_md(path: Path):
    """Yield (slack_id, start, end, note, status) tuples."""
    if not path.exists():
        return
    section = None
    for raw in path.read_text().splitlines():
        stripped = raw.strip()
        m = re.match(r"^##\s+(\w+)", stripped)
        if m:
            section = m.group(1).lower()  # 'active' | 'past' | other
            continue
        if section not in ("active", "past"):
            continue
        m = LEAVE_LINE_RE.match(stripped)
        if not m:
            continue
        yield (
            m.group("sid"),
            m.group("start"),
            m.group("end"),
            m.group("note").strip(),
            section,
        )


def parse_holidays_md(path: Path):
    """Yield (date, name, region, status) tuples."""
    if not path.exists():
        return
    section = None
    for raw in path.read_text().splitlines():
        stripped = raw.strip()
        m = re.match(r"^##\s+(\w+)", stripped)
        if m:
            label = m.group(1).lower()
            section = "upcoming" if label in ("upcoming", "active") else "past"
            continue
        if section not in ("upcoming", "past"):
            continue
        m = HOLIDAY_LINE_RE.match(stripped)
        if not m:
            continue
        name = m.group("name").strip()
        # Heuristic: "(India)" in parens at end → region
        region = None
        rm = re.search(r"\(([^)]+)\)\s*$", name)
        if rm:
            region = rm.group(1).strip()
            name = re.sub(r"\([^)]+\)\s*$", "", name).strip()
        yield (m.group("date"), name, region, section)


def parse_reminders_dir(reminders_dir: Path):
    """Yield (fire_date, body, status) tuples — one per YYYY-MM-DD.md file."""
    if not reminders_dir.exists():
        return
    import datetime
    today = datetime.date.today().isoformat()
    for p in sorted(reminders_dir.glob("*.md")):
        m = re.match(r"^(\d{4}-\d{2}-\d{2})\.md$", p.name)
        if not m:
            continue
        fire_date = m.group(1)
        body = p.read_text().strip()
        if not body:
            continue
        status = "pending" if fire_date >= today else "fired"
        yield (fire_date, body, status)


def parse_proposal_files(state_dir: Path):
    """Yield (reply_ts, proposal_json, created_at) tuples."""
    if not state_dir.exists():
        return
    import datetime
    for p in sorted(state_dir.glob("tasks-cleanup-proposal-*.json")):
        m = re.match(r"^tasks-cleanup-proposal-(\d+\.\d+)\.json$", p.name)
        if not m:
            continue
        reply_ts = m.group(1)
        try:
            content = p.read_text()
            json.loads(content)  # validate
        except (OSError, json.JSONDecodeError) as e:
            print(f"  WARN: skipping {p.name} — {e}", file=sys.stderr)
            continue
        created_at = datetime.datetime.fromtimestamp(p.stat().st_mtime).isoformat(sep=" ", timespec="seconds")
        yield (reply_ts, content, created_at)


# ─── Migrate ─────────────────────────────────────────────────────────────────


def migrate(dry_run: bool = False):
    print(f"DB → {DB_PATH}")
    if dry_run:
        print("(dry-run — no writes)")
    else:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    con = sqlite3.connect(":memory:" if dry_run else str(DB_PATH))
    con.executescript(SCHEMA)
    con.execute(
        "INSERT OR IGNORE INTO schema_version (version, notes) VALUES (1, 'Phase 3 initial schema')"
    )
    con.commit()

    # ── leave_entries ──
    rows = list(parse_leave_md(LEAVE_MD))
    print(f"[leave_entries] parsed {len(rows)} rows from {LEAVE_MD.name}")
    cur = con.executemany(
        "INSERT OR IGNORE INTO leave_entries (slack_id, start_date, end_date, note, status) "
        "VALUES (?, ?, ?, ?, ?)",
        rows,
    )
    print(f"  inserted: {cur.rowcount} (skipped {len(rows) - cur.rowcount} dupes)")

    # ── holidays ──
    rows = list(parse_holidays_md(HOLIDAYS_MD))
    print(f"[holidays] parsed {len(rows)} rows from {HOLIDAYS_MD.name}")
    cur = con.executemany(
        "INSERT OR IGNORE INTO holidays (date, name, region, status) VALUES (?, ?, ?, ?)",
        rows,
    )
    print(f"  inserted: {cur.rowcount} (skipped {len(rows) - cur.rowcount} dupes)")

    # ── reminders ──
    rows = list(parse_reminders_dir(REMINDERS_DIR))
    print(f"[reminders] parsed {len(rows)} per-day files from {REMINDERS_DIR}")
    cur = con.executemany(
        "INSERT INTO reminders (fire_date, body, status) VALUES (?, ?, ?)",
        rows,
    )
    print(f"  inserted: {cur.rowcount}")

    # ── tasks_cleanup_proposals ──
    rows = list(parse_proposal_files(STATE_DIR))
    print(f"[tasks_cleanup_proposals] parsed {len(rows)} JSON files from {STATE_DIR}")
    cur = con.executemany(
        "INSERT OR IGNORE INTO tasks_cleanup_proposals (reply_ts, proposal_json, created_at, status) "
        "VALUES (?, ?, ?, 'pending')",
        rows,
    )
    print(f"  inserted: {cur.rowcount}")

    con.commit()

    # ── verify ──
    print()
    print("Final row counts:")
    for table in (
        "schema_version", "leave_entries", "holidays", "reminders",
        "tasks_cleanup_proposals", "eod_streaks", "routine_runs",
        "user_testing_issues", "bug_reports", "marketing_recon",
    ):
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table:30s} {n:>5}")

    con.close()
    print(f"\nDone. DB at {DB_PATH if not dry_run else '(dry-run — discarded)'}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="parse + report, no writes")
    args = ap.parse_args()
    migrate(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
