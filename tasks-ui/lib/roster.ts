// Client-safe roster types + display helpers.
// The server-only fs-backed loader lives in lib/roster-server.ts.

export interface RosterEntry {
  slack_id: string;
  handle: string; // "@agni"
  name: string;   // "Agni" or "Sanket Sahu"
  role?: string;
}

export interface AssigneeDisplay {
  handle: string;   // @agni or a shortened fallback
  name: string;     // Agni or the raw ID
  initials: string; // AG, S, etc.
  known: boolean;   // true if the roster had this ID
}

export function toRosterMap(entries: RosterEntry[]): Map<string, RosterEntry> {
  return new Map(entries.map((e) => [e.slack_id, e]));
}

export function assigneeDisplay(
  slackId: string | null | undefined,
  rosterMap: Map<string, RosterEntry>
): AssigneeDisplay {
  if (!slackId) return { handle: "—", name: "Unassigned", initials: "?", known: false };
  const entry = rosterMap.get(slackId);
  if (!entry) {
    return {
      handle: `<${slackId.slice(0, 5)}…>`,
      name: slackId,
      initials: slackId.slice(0, 2).toUpperCase(),
      known: false,
    };
  }
  const initials =
    entry.name
      .split(/\s+/)
      .map((w) => w[0])
      .filter(Boolean)
      .slice(0, 2)
      .join("")
      .toUpperCase() || entry.handle.slice(1, 3).toUpperCase();
  return { handle: entry.handle, name: entry.name, initials, known: true };
}
