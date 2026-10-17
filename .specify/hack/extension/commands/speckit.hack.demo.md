---
description: "Hackathon mode: turn the demo script into a stage run-sheet (demo.md)"
---

## User Input

```text
$ARGUMENTS
```

Build the stage run-sheet for the demo (spec FR-037). This project is in **hackathon mode**.
Read `.specify/mode.json` and the spec's `## Demo script` in `<feature_directory>/spec.md`.

Write `<feature_directory>/demo.md` (the only new file allowed in the spec directory) with:

1. **Run-sheet**: every demo-script step, in order, with what the presenter does, what the
   audience must see, and a target time per step. The total must fit the event's demo slot;
   if it does not, say which steps to cut.
2. **Seed data**: exactly what must exist before going on stage, and the command that loads
   it. If any service keeps data in memory, add **"Do not restart <service> before the
   demo"**: a restart wipes the seeded data.
3. **Fallback**: where the backup recording of the full demo lives, and when to switch to it
   (for example, any step failing twice).
4. **Freeze**: the submission freeze time, earlier than `ends_at`. Submissions after it do
   not count, and an early merge beats a late heroic feature.
5. **Runtime versions** from `runtime` in the mode record, and the command that checks
   them on the demo machine.
6. **Event repositories** (coordinating variant): each repository's target branch, and a
   reminder to check that every pull request targets it, not the upstream default.
7. **Rehearsal checklist**: run `scripts/verify.sh --full`, rehearse the run-sheet end to end
   at least twice, confirm the fallback recording plays, and confirm the submission form
   fields (names, repository URLs) are ready before the freeze.

If the demo check is `manual` (`demo_check` in the mode record), the run-sheet **is** the
manual checklist: say so at the top of the file.

Then run `scripts/hack.sh check` and report the path of `demo.md`. Do not commit unless asked.
