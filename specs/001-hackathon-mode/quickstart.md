# Quickstart: validating Hackathon Mode

Runnable scenarios that prove the feature end to end. The automated ones live in
`tests/hack/` (`tests/hack/run.sh`, research R13). The manual ones need real agents or a
real GitHub repository. Contracts: [hack-cli.md](contracts/hack-cli.md),
[extension-manifest.md](contracts/extension-manifest.md),
[mode-record.schema.json](contracts/mode-record.schema.json).

## Prerequisites

- `git`, `python3`, `specify` 1.1.1 (`./scripts/setup.sh`), `pre-commit`; `gh` for the
  issue and branch-protection scenarios.
- A scratch directory under `$TMPDIR`. Never run these in the template checkout itself.

## Automated (`tests/hack/run.sh`)

Each scenario clones the template into a fresh temp repo and asserts exit codes and output.

| # | Scenario | Expected | Proves |
|---|---|---|---|
| A1 | `hack.sh on …` on a fresh clone | exit 0; `mode.json` valid against the schema; §0 gone; notices present in all 4 files; `hack-check` block in `.pre-commit-config.yaml`; template `specs/` gone | US1, FR-001..006 |
| A2 | `hack.sh on` again; `hack.sh on` after a full `/kickoff`-style §1 fill | exit 1, "mode is chosen once" | US1 #2, FR-003, FR-027 |
| A3 | `hack.sh guard speckit.clarify` (and every blocked id, `/kickoff`, `speckit.bug.fix`); `guard` with no argument and stdin at `/dev/null` or a TTY; `guard` with a piped prompt payload | exit 2 with a redirect; the no-input case blocks without waiting; a payload starting with a blocked command exits 2 | US3 #1–2, FR-016 |
| A4 | `hack.sh guard speckit.implement`, `speckit.converge`, `speckit.hack.sprint` | exit 0 | FR-016 |
| A5 | Add `specs/002-x/spec.md`, then `research.md` in the active dir, then `.specify/bugs/y/assessment.md`, then edit the hack constitution; `hack.sh check` after each. Also time `check` on a clone with 10,000 extra files | exit 1, one actionable `ERROR` per violation; `check` takes under 2 s | US3 #3–4, FR-018, plan Performance Goals |
| A6 | `git commit` with each A5 violation, with the pre-commit hooks installed | commit rejected | FR-018 (commit-time layer) |
| A7 | `hack.sh check --changed api/a.py web/b.tsx` with two owners | exit 0, two `WARN` lines naming the owners | US3 #4, FR-019 |
| A8 | `verify.sh` / `verify.sh --full` in hackathon mode with `smoke=true`, `build=true` | runs check → smoke (→ build), `verify: OK` | FR-013, FR-015 |
| A9 | `verify.sh --full` with `demo_check=manual` | prints `MANUAL`, never "smoke passed" | US4 #4, FR-014 |
| A10 | `ends_at` in the past; `status`, `check`, `verify.sh` | `WARN` shown, exit codes unchanged | US7, FR-025 |
| A11 | Delete `.specify/feature.json`, run a hack command's spec resolution | finds `feature_directory` from `mode.json` | US4 #2, FR-012 |
| A12 | `hack.sh graduate --lint true --test true` | `mode.json`, notices, pre-commit block and extension gone; `verify.sh --full` runs the full commands; debt entries in `tasks.md`; the hackathon tooling (R16) is gone, so re-entry is impossible | US5, FR-024, FR-026, FR-027, SC-009 |
| A13 | Full-mode clone (never activated): look for hackathon hooks in `.claude/settings.json`, `.cursor/hooks.json` and `.specify/extensions.yml`, `speckit-hack-*` commands, the `hack-check` pre-commit hook, and any hackathon mention in CI, `verify.sh` and `AGENTS.md` outside the marked blocks; then run full-mode `verify.sh` | none found, except the template-only `/hack-kickoff` and the marked blocks (R16), which `/kickoff` removes (M9); full-mode `verify.sh` behaves as before. Checked as properties, so it holds on any branch | FR-006, SC-007 |
| A14 | Coordinating variant with two local bare "event" repos: `on --variant coordinating …`, then `hooks` | pre-commit installed in both clones, no tracked file changed there; a commit with a test secret and a commit adding `specs/x/spec.md` are both rejected, each printing the local-only notice; `git push` prints the target branch and the local-only warning | US6, FR-030..035, SC-012 |
| A15 | Same secret fixture committed in full mode and in hackathon mode | rejected identically | FR-028, SC-008 |

## Manual (needs real agents or GitHub)

| # | Scenario | Expected | Proves |
|---|---|---|---|
| M1 | Claude Code session in an activated clone | session-start banner; typing `/speckit-clarify` is refused with the redirect | FR-021, SC-005 |
| M2 | Cursor session, same clone | session-start context; `speckit-specify` stops at the `before_specify` guard; a typed prompt is blocked if `beforeSubmitPrompt` supports it (R3 "to verify") | FR-016, SC-005 |
| M3 | Cline, same clone | `/speckit-plan.md` stops at the `before_plan` guard | FR-016, SC-005 |
| M4 | `/speckit-hack-sprint` from a 3-sentence idea on a GitHub repo, timed | spec, plan and tasks in one pass; one issue per work item, each assigned to its owner; under 60 min including activation | US2, FR-007..010, SC-002 |
| M5 | A PR adding `specs/002-x/` with `--require-check` applied | the PR cannot merge | SC-004 |
| M6 | Dry run: 3 people on at least 2 agents (one of them Cline), about 2 hours, a toy idea; time the CI verdict on each PR | passing demo check on `main`, no full-flow artifacts, each teammate found their work alone in under 5 min, the Cline teammate's `/speckit-implement` finds the spec, and the CI verdict minus build and smoke time is under 3 min | SC-003, SC-006, SC-010, FR-012 |
| M7 | Coordinating variant against a real fork whose default branch is not `main`, timed from a fresh template clone | the target branch is surfaced on push and in `status`; setup takes under 15 min | US6 #4, SC-011 |
| M8 | `/hack-kickoff` in Claude Code on a fresh template clone, timed | one stack question plus the confirmation block; `scripts/hack.sh on` runs; sandbox domains and CI toolchain added; no scaffolding; under 10 min | US1, FR-001, FR-004, FR-005, SC-001 |
| M9 | `/kickoff` in an activated clone, then `/kickoff` on a fresh clone | the first is refused, naming `/speckit-hack-graduate`; the second removes `specs/` and every R16 template-only item | FR-003, FR-006, SC-007 |
| M10 | `/speckit-hack-graduate` in an activated clone with debt | asks for the lint and test commands, confirms, runs the script, and points to `/speckit-converge`; refused off the default branch | US5, FR-026 |
| M11 | `/speckit-hack-demo` after a sprint | `demo.md` with seed data, timings, fallback recording, a freeze earlier than `ends_at`, runtime versions and target branches | FR-037 |

## Done

All of A1–A15 pass in `tests/hack/run.sh` (locally and in the template-only CI step), and
M1–M11 are recorded with their observed output and timings in
`specs/001-hackathon-mode/validation.md`.
