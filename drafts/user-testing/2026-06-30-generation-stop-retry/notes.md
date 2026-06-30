# 2026-06-30 — Generation stop & retry loop on prod project

**Source:** #user-testing thread on 2026-06-30 (IST), surfaced by @sanket, investigated by @suraj.

**Tester:** anonymous production user (not internal team).

**Project:** https://www.rapidnative.com/project/cCMBGBrbO-Apa5cB5mjLm

## Observation (verbatim from #user-testing)

- @sanket: *"this kept happening for the user"* (cc @suraj)
- @suraj: *"User intentionally stopped the generation. Possible issue: Generation is taking too much time, so user tried to retry"*

## Screenshot summary

Editor left-panel timeline showed (`screenshot.png`):

- 10:37:03 — `Generation stopped`
- 10:37:56 — prompt: *"Add all missing route screens. and also connect the backend as well."*
- 11:05:36 — `Generation stopped`
- 11:34:30 — prompt: *"Add all missing route screens. Also connect the backend."* (re-issued, slight wording change)

Pattern: at least **4 stop-events** over ~1 hour, user re-sending essentially the same prompt each time. Right-pane preview shows a generated medication-tracker app ("RapidNative App / Medications" with adherence + reminders) — so the project itself is non-trivial but the user is stuck trying to extend it.

## What we observed vs. what we infer

| | |
|---|---|
| **Observation** | User issued prompt, stopped generation mid-way, re-issued similar prompt, repeated several times on the same project. |
| **Suraj's hypothesis** | Generation is too slow → user loses patience and stops. |
| **Alternate hypothesis worth ruling out** | Generation completes but doesn't satisfy the prompt ("add missing route screens", "connect backend") → user stops and retries hoping for different output. The repeated identical prompt suggests dissatisfaction with output, not just impatience. |

We don't have client-side timing data here, so we can't yet distinguish "stopped because slow" from "stopped because wrong output". Worth instrumenting before deciding the fix.

## Action thread

- @sanket → @riya (pinged with project URL)
- @suraj investigated (read above)
- @sanket → "We need this captured so that we know what happened." → captured here + in `accountability/user-testing/issues-log.md` row #4.

## Followups to consider (not decided)

1. Add per-generation timing logs (start ts, stop ts, completion %) to back out the "slow vs. unsatisfying" question.
2. Check whether "Add missing route screens" + "Connect backend" prompts have a known weakness in the generator's eval (related to log row #3: time-as-state eval gap, but a different surface).
3. If confirmed slow: investigate whether `Slow (default)` mode visible bottom-left of the editor is the right default for first-time prod users.
