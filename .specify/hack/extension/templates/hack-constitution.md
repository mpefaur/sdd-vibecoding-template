# Hackathon Constitution

<!--
  Governs a project only while `.specify/mode.json` exists (hackathon mode).
  Installed by `scripts/hack.sh on`; its hash is recorded in the mode record and
  `scripts/hack.sh check` rejects any change to it. Leave the mode with
  /speckit-hack-graduate, which hands the project back to `.specify/memory/constitution.md`.
-->

## Core Principles

### I. The Demo Script Is the Contract

The spec's demo script — the exact steps shown on stage — defines the product. Work that no
demo step needs is out of scope. A work item is done when its demo step is added to the
demo check (`commands.smoke` in the mode record) and passes, together with the build.

*Rationale: in 24–48 hours, only what the audience sees is worth building.*

### II. Happy Path Only

Build the path the demo walks, with seed data that makes it reliable. Edge cases, error
handling, broad test suites and abstractions for later are intentionally skipped. A defect
is fixed only when the demo check reproduces it.

*Rationale: polish nobody sees on stage costs the time the demo needs.*

### III. Secrets Never in the Repository

Unchanged from the full constitution, Principle V: secrets never live in the repository —
not in code, config, fixtures, logs, or history. Real values come from the environment.
Secret scanning runs at commit time and in CI exactly as in full mode.

*Rationale: a hackathon repository is often public, and a leaked key outlives the event.*

### IV. Debt Is Written Down, Not Paid

Every shortcut that full mode would not accept, and every defect the demo check cannot
reproduce, gets one line in the spec directory's `debt.md`:
`- D<NNN> | <shortcut> | where: <path> | why: <reason> | repay: <what full mode needs>`.
Graduation turns every line into a task.

*Rationale: a proof of concept that wins must be able to become a product without
archaeology.*

## Workflow

One spec, written by the spec owner with `/speckit-hack-sprint`. Work items are issues
assigned by path ownership. Full-flow commands (constitution, specify, clarify, plan, tasks,
analyze, checklist) and the bug lane are disabled. Implement and converge stay available.

## Governance

This constitution replaces `.specify/memory/constitution.md` while `.specify/mode.json`
exists, as that constitution's "Hackathon Mode" section provides. It is fixed for the
project's time in hackathon mode. The only exit is graduation (`/speckit-hack-graduate`),
after which the full constitution governs again.

**Version**: 1.0.0
