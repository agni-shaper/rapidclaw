// SERVER-ONLY. Imports node:fs — never import this from a client component.

import "server-only";
import fs from "node:fs/promises";
import type { RosterEntry } from "./roster";

const PEOPLE_MD = "/Users/agni/Documents/rapidclaw/definitions/people.md";

// Parses the People table in definitions/people.md.
// Row shape:  | `@handle` | Name | Role | Kind | `SLACK_ID` | Email | Tier |
// Rows whose Slack ID column is `—` are silently skipped.
export async function loadRoster(): Promise<RosterEntry[]> {
  const text = await fs.readFile(PEOPLE_MD, "utf-8");
  const entries: RosterEntry[] = [];
  const rowRe = /^\|\s*`(@\w+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*`([A-Z0-9]+)`\s*\|/gm;
  let m: RegExpExecArray | null;
  while ((m = rowRe.exec(text)) !== null) {
    entries.push({
      handle: m[1],
      name: m[2].trim(),
      role: m[3].trim(),
      slack_id: m[5],
    });
  }
  return entries;
}
