# User testing workflow

How raw user-testing observations flow into tasker (tasks.rapidnative.com, the team's tracker).

## Three layers

1. **Raw session captures** → `drafts/user-testing/<YYYY-MM-DD>-<tester-or-session-slug>/`
   - `notes.md` — observations + verbatim quotes (channel persona requires this; keeps PII out of Slack long-term)
   - `recording.<ext>`, `screenshots/` — optional, sensitive
2. **Rolling priority issues log** → `accountability/user-testing/issues-log.md` (this folder)
   - One row per *distinct* issue. Dedup happens here.
   - Tracks: first seen date, testers hit (count + initials), priority, status, linked task slug.
3. **Tasker** — when an issue crosses the promotion threshold, it becomes a tasker item (bugs in the RapidNative Inbox, UX issues in track "User testing"). The log row keeps the item link.

## Promotion threshold

Promote a row to tasker when **either**:

- **2+ testers hit it** (recurring = higher signal), or
- **P0 or P1 priority on first occurrence** (severe enough to act on a single observation).

Whichever fires first.

## How to log a new observation manually

After a session, in `drafts/user-testing/<date>-<slug>/notes.md`:

1. Write the session notes (observations, verbatim quotes, who tested, what was tested).
2. Pull out distinct issues. For each:
   - Open `accountability/user-testing/issues-log.md`.
   - Search for an existing matching row (similar wording, same surface area, same root cause).
   - **Match** → increment `testers hit` count, append the tester's initials, re-evaluate priority.
   - **No match** → add a new row with `status: raw`, `task: —`.
3. For any row that just crossed the promotion threshold:
   - Search tasker for it first; if it exists, comment the new sighting on it.
   - Otherwise create the item per the coach's `task-management` / `bug-tracking` skills (or by hand in tasker).
   - Paste the item link (`https://tasks.rapidnative.com/items/<id>`) into the log row's `task` column.
   - Update log row `status: tasked`.
4. When the task ships, update log row `status: shipped`.

## Automated capture

The `user-testing-capture` routine (see `accountability/routines/user-testing-capture.md`) is the automated version of step 2 above. It:

- Reads recent activity in #user-testing.
- Diffs against this log.
- Posts a proposal (new rows / count bumps / threshold-crossings) to #rapidnative-coach for one-line confirmation before writing.

Never writes to the log or to tasker unattended — owner confirms each batch.

## Privacy

- Tester initials only in the log. Full names + role go in the raw session notes folder (which never leaves the local repo).
- Don't paste raw notes into Slack channels other than #user-testing thread context.
- Sharing findings externally (clients, posts) is owner/super-admin only — see `channels/user-testing.md`.
