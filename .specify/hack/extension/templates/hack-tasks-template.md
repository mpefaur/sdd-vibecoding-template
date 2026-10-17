# Hackathon Tasks: [PROJECT NAME]

<!--
  Work items are vertical slices, ordered by the demo script. Each is published as a GitHub
  issue assigned to its owner (scripts/hack.sh issues). Format, verbatim:

  - [ ] H012 [@member] [slice: <demo step>] [≤90m] <description> — paths: <glob>, <glob>

  Rules:
  - A work item crossing owners is split, never shared.
  - Done = that step is added to the demo check and passes, and the build passes
    (scripts/verify.sh --full).
-->

## H0 — Hello world deployed

- [ ] H001 [@[handle]] [slice: 0. app is reachable] [≤60m] Deploy a hello-world build to the deploy target — paths: [glob]

## Slices — in demo order

### Demo step 1: [title]

- [ ] H002 [@[handle]] [slice: 1. [title]] [≤90m] [description] — paths: [glob]

## FREEZE — [time, before the official end]

No new work after this point. Merge what is green, cut what is not, move cuts to the spec's
"Out of scope".

## REHEARSAL

- Run `/speckit-hack-demo`, then rehearse the demo script end to end at least twice.

## Log debt

Shortcuts and defects the demo check cannot reproduce go to `debt.md` in this directory,
one line each, verbatim format:

`- D007 | <shortcut or unreproduced defect> | where: <path> | why: <hackathon reason> | repay: <what full mode needs>`

Graduation (`/speckit-hack-graduate`) turns every entry into a task.
