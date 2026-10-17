# Implementation Plan: Hackathon Mode

**Branch**: `001-hackathon-mode` | **Date**: 2026-10-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-hackathon-mode/spec.md`

## Summary

A project adopted with `/hack-kickoff` runs a reduced SDD flow for 24–48 hour team
hackathons. That flow has one demo-centered spec, work items assigned by path ownership,
and "done" defined as the demo check plus the build. A project's mode is fixed once at
adoption and is left only by graduating.

The approach (research R1–R15):

- **The mode record.** A committed `.specify/mode.json` is the single source of truth.
- **One script.** `scripts/hack.sh` holds all mode logic, so any agent or person can run it.
- **One Spec Kit extension, `hack`.** It is installed only on activation and removed on
  graduation, so full-mode projects carry nothing. It contributes:
  - commands;
  - mandatory `before_*` lifecycle hooks, which reach Claude, Cursor and Cline;
  - native `session_start` and `user_prompt_submit` events, which reach Claude and Cursor;
  - namespaced templates, so the core templates are never shadowed.
- **A state-based check.** It accepts only allow-listed spec artifacts, no bug-lane output
  and an untouched hackathon constitution. It runs in pre-commit and, through the
  mode-aware `scripts/verify.sh`, in CI. That check is the only enforcement no agent can
  skip.
- **The coordinating variant.** It covers organizer-provided repositories with per-machine
  local hooks that commit nothing to the event repository.

## Technical Context

**Language/Version**: Bash 3.2+ (macOS default; no associative arrays) and Python 3.9+
stdlib (`python3 -I`, JSON only). Markdown and YAML for Spec Kit command, template and
manifest files.

**Primary Dependencies**:

- `git`.
- Spec Kit `specify-cli` 1.1.1: needed only on the team lead's machine, for activation and
  graduation.
- `pre-commit` 4.x: local checks. Optional per teammate, because CI covers anyone without it.
  The template's CI pins `pre-commit==4.6.2`.
- `gh`: issues and branch protection. Needed only by the spec owner and the team lead.
- Betterleaks: unchanged.

**Storage**: Files in the repository. `.specify/mode.json` is committed. The gitignored
machine-local state is `.specify/feature.json` and `.specify/hack/local/`.

**Testing**: Bash scenario tests in `tests/hack/run.sh` against throwaway git repos in
`$TMPDIR`. They run in a CI step gated on the repo being the unadopted template (R13). The
agent and GitHub scenarios are manual, in [quickstart.md](quickstart.md) M1–M11.

**Target Platform**: macOS and Linux developer machines, and GitHub Actions `ubuntu-latest`.
Windows works via Git Bash or WSL; there is no PowerShell parity (R14).

**Project Type**: Template tooling: a CLI script, Spec Kit extension assets and repository
configuration.

**Performance Goals**: `hack.sh check` takes under 2 s on a repository of 10k files. A
change's verdict, excluding the project's own build and demo check, arrives in under 3 min
(SC-006).

**Constraints**:

- Zero change for full-mode projects (FR-006, SC-007).
- Never edit Spec Kit generated files.
- Never commit into event repositories without confirmation.
- Secret protections stay identical (FR-028).
- `hack-kickoff` writes configuration and documentation only (FR-005).

**Scale/Scope**: Teams of 2–5, one spec per project, and in the coordinating variant up to
about 3 event repositories.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against `.specify/memory/constitution.md` v1.1.0. The template itself stays in full
mode; this feature changes the template.

| Principle / Gate | Pre-research | Post-design | Notes |
|---|---|---|---|
| I. Spec Before Code | ✅ | ✅ | `spec.md` (clarified) → this plan → `tasks.md` next. No code was written. |
| II. Simplicity First | ✅ | ✅ | One script, one extension. Preset, workflow, bundle, branch and `pre_tool_use` were all rejected (R1, R3, R4). No config flags with a single value. |
| III. Verified, Not Assumed | ⚠️ | ✅ (justified) | The template's `verify.sh` is unconfigured by design, so "done" for this feature is `tests/hack/run.sh` (A1–A15), which also runs in CI. Agent-instruction behavior (skills and command bodies) is verified by the manual scenarios M1–M11, recorded in `validation.md`. See Complexity Tracking. |
| IV. Surgical Change | ✅ | ✅ | Existing files change only where an FR requires it (list below). Generated `speckit-*` files are untouched. |
| V. Secure and Reproducible | ✅ | ✅ | Betterleaks, denies, sandbox and blocker are unchanged in both modes. Coordinating-variant hooks run the same scanners at the same revs. Actions stay pinned by SHA; CI tools are pinned by version (`specify-cli` from `scripts/setup.sh`, `pre-commit==4.6.2`). `scripts/setup.sh` installs `pre-commit` unpinned; that predates this feature and is only reported. |
| Gate 1: traces to `tasks.md` | ✅ | ✅ | Next step. |
| Gate 2: `verify.sh --full` passes | ⚠️ | ✅ (justified) | It is a no-op in the template; same justification as III. |
| Gate 3: tests cover new behavior | ✅ | ✅ | A1–A15. |
| Gate 4: no secrets | ✅ | ✅ | Test secrets are generated at run time inside throwaway clones; no secret-shaped string is committed and `.betterleaksignore` is unchanged (research "Spike results"). |
| Gate 5: Conventional Commits | ✅ | ✅ | |
| Governance: alternate mode | ⚠️ | ✅ | The hackathon constitution needs a MINOR constitution amendment to 1.2.0 (R7). It is part of this feature's tasks. |

## Project Structure

### Documentation (this feature)

```text
specs/001-hackathon-mode/
├── spec.md
├── plan.md                         # this file
├── research.md                     # R1–R15 + Qodo lessons
├── data-model.md                   # lifecycle, mode record, allow-list, work item, debt log
├── quickstart.md                   # A1–A15 automated, M1–M11 manual
├── contracts/
│   ├── hack-cli.md                 # scripts/hack.sh subcommands, exit codes, effects
│   ├── extension-manifest.md       # the `hack` extension: commands, hooks, events, templates
│   └── mode-record.schema.json     # .specify/mode.json
├── checklists/requirements.md
└── tasks.md                        # /speckit-tasks — not created here
```

### Source Code (repository root)

```text
scripts/
├── hack.sh                         # NEW — on | status | guard | check | issues | hooks | graduate
└── verify.sh                       # CHANGED — mode-aware branch (R8); full-mode path untouched

.specify/hack/extension/            # NEW — template-owned source of the `hack` extension (R2)
├── extension.yml
├── README.md
├── scripts/hack.sh                # shim → repo-root scripts/hack.sh (Spec Kit rewrites scripts/ paths)
├── commands/
│   ├── speckit.hack.sprint.md
│   ├── speckit.hack.demo.md
│   ├── speckit.hack.status.md
│   ├── speckit.hack.guard.md
│   └── speckit.hack.graduate.md
└── templates/
    ├── hack-spec-template.md
    ├── hack-plan-template.md
    ├── hack-tasks-template.md
    └── hack-constitution.md

.claude/skills/
├── hack-kickoff/SKILL.md           # NEW — thin wrapper: one stack question, confirm, `hack.sh on`
└── kickoff/SKILL.md                # CHANGED — Step 0 refuses when mode.json exists; deletes template specs/ (R9) and the R16 template-only items

.specify/memory/constitution.md     # CHANGED — v1.2.0 amendment: hackathon-mode projects (R7)
.github/workflows/ci.yml            # CHANGED — `template-selftest` job between `# template-only:begin/end` (R13, R16); PR ownership-warning step between `# hackathon-mode:begin/end`
.gitignore                          # CHANGED — .specify/hack/local/
AGENTS.md                           # CHANGED — §2 one line pointing to hackathon mode; §9 repo map
docs/TEMPLATE_USAGE.md              # CHANGED — new "Hackathon mode" section (when to use it, activation, team setup, coordinating variant, graduation, known limits)

tests/hack/
├── run.sh                          # NEW — runs A1–A15
├── lib.sh                          # NEW — temp-repo fixture helpers, assertions
└── fixtures/                       # NEW — synthetic secret, sample mode records, fake event repos
```

Written only on activation, not present in the template:

- `.specify/mode.json`
- `.specify/extensions/hack/` (installed copy) and the generated `speckit-hack-*` commands
  for claude, cursor-agent and cline
- native hook entries in `.claude/settings.json` and `.cursor/hooks.json`
- the sentinel blocks in the 4 instruction files and in `.pre-commit-config.yaml`

**Structure Decision**: Template tooling layered on the existing layout.

- New logic lives in one script (`scripts/hack.sh`, the same pattern as `verify.sh`).
- New Spec Kit assets live in a template-owned directory outside `.specify/extensions/`, so
  an install or remove never deletes the source.
- Existing files change only for FR-003 (kickoff), FR-015 (verify.sh), the R7 governance
  amendment, R13 (CI) and the documentation.

## Delivery order (input for `/speckit-tasks`)

1. **Spike (blocking).** Confirm against Spec Kit 1.1.1:
   - multi-integration registration (R2);
   - the `hooks` YAML shape that `register_hooks` accepts;
   - that `add` and `remove` refresh native events;
   - Cursor `beforeSubmitPrompt` blocking (R3).
   Update research.md with the results.
2. **Foundational.** The `hack.sh` skeleton with mode-record read and validation; the
   `tests/hack` harness; the CI self-test step.
3. **US1** activate → **US3** guard and check → **US2** sprint, templates and issues →
   **US4** verify.sh, notices and status → **US5** graduate → **US6** coordinating variant
   → **US7** expiry warning.
   - Stories share `scripts/hack.sh`, so they run **sequentially** (CLAUDE.md:
     "any file path shared across stories → sequential").
4. **Polish.** Constitution amendment, documentation, A13 (zero change in full mode), and
   M1–M11 recorded with timings in `validation.md`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Verification for this feature is `tests/hack/run.sh` plus a template-only CI step, not `scripts/verify.sh --full` (Principle III, Gate 2) | The template's `verify.sh` must stay unconfigured: every adopted project inherits it and sets its own stack commands | Setting `TEST_CMD` in the template would make every adopted project run the template's self-tests until someone noticed and removed them |
| The extension source lives outside `.specify/extensions/` (`.specify/hack/extension/`) | Spec Kit scans every directory under `.specify/extensions/`, registered or not, when it refreshes native events (`collect_extension_events` treats unregistered directories as partially-staged installs). Keeping the source there would leak the hack events into full-mode projects on any integration refresh | Keeping it installed-but-disabled puts `/speckit-hack-*` skills into every full-mode session (AGENTS.md §8 context tax, SC-007) |
