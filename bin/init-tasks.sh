#!/bin/zsh
# init-tasks.sh — create the `tasks` table + indexes in the coach sqlite DB.
# Idempotent (CREATE TABLE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS).
# Safe to re-run. Called once at setup or after a schema change.
#
# Usage:
#   ./bin/init-tasks.sh

set -e
source "${0:A:h}/../accountability/routines/_lib.sh"

[ -f "$DB_PATH" ] || { echo "ERROR: sqlite DB not found at $DB_PATH — run bin/migrate-to-sqlite.py first" >&2; exit 1; }

sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  assignee TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'done', 'carried', 'cancelled')),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'blocker')),
  category TEXT,
  product TEXT,
  source TEXT,
  due_date TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  metadata TEXT
);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee);
CREATE INDEX IF NOT EXISTS idx_tasks_status   ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category);
CREATE INDEX IF NOT EXISTS idx_tasks_product  ON tasks(product);
SQL

echo "OK · tasks table + indexes ready in $DB_PATH"
sqlite3 "$DB_PATH" ".schema tasks" | head -20
