# `hack` — Hackathon Mode extension

A reduced Spec-Driven flow for 24–48 hour team hackathons: one demo-centered spec, work
items assigned by path ownership, and "done" = the demo check plus the build. Design and
rationale: `specs/001-hackathon-mode/` in the template repository.

## Lifecycle

- **Not installed** in the template or in full-mode projects. `scripts/hack.sh on` (run by
  `/hack-kickoff`) installs it for every installed agent integration.
  `scripts/hack.sh graduate` (`/speckit-hack-graduate`) removes it.
- Its source lives here, in `.specify/hack/extension/`, **outside** `.specify/extensions/`,
  for two reasons. Spec Kit scans every directory under `.specify/extensions/`, registered
  or not, when it refreshes native events, so keeping the source there would leak the hack
  events into full-mode projects. And `specify extension remove` deletes the installed
  directory.
- Spec Kit rewrites `scripts/…` paths in command files into the extension directory, so
  `scripts/hack.sh` here is a shim that execs the repository-root `scripts/hack.sh`, where all
  logic lives.

## What it provides

| Kind | Name | Purpose |
|---|---|---|
| Command | `speckit.hack.sprint` | Spec owner: spec, plan and tasks in one pass, then assigned issues |
| Command | `speckit.hack.demo` | Stage run-sheet (`demo.md`) |
| Command | `speckit.hack.status` | Mode, active spec, definition of done; syncs `.specify/feature.json` |
| Command | `speckit.hack.guard` | Refuses full-flow and bug-lane commands with a redirect |
| Command | `speckit.hack.graduate` | Leaves the mode for the full flow |
| Hooks | `before_constitution/specify/clarify/plan/tasks/analyze/checklist` | Mandatory guard |
| Hooks | `before_implement`, `before_converge` | Mandatory status (active-spec pointer) |
| Events | `session_start` | Status banner (Claude Code, Cursor) |
| Events | `user_prompt_submit` | Guard on typed commands (Claude Code, Cursor) |
| Templates | `hack-spec-template`, `hack-plan-template`, `hack-tasks-template`, `hack-constitution` | Namespaced, so they never shadow the core templates |

## Known limits

- Cline has no native events: it gets the lifecycle hooks and the notices only.
- The bug-lane commands have no hook points. When an agent invokes them on its own, nothing
  stops them at command time; `scripts/hack.sh check` rejects their output (`.specify/bugs/`).
- Agents whose integration is not installed (Codex, Copilot, Gemini) rely on the notices and
  on CI.
- The enforcing layer is `scripts/hack.sh check`, which runs in pre-commit and in CI
  (`scripts/verify.sh`). Everything else is guidance.
