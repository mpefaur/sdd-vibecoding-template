# Validation: Hackathon Mode

Status of [quickstart.md](quickstart.md) on branch `001-hackathon-mode`, 2026-10-17.

## Automated — `tests/hack/run.sh` (A1–A15)

13 tests, all passing (macOS, Spec Kit 1.1.1, pre-commit 4.6.2): `test_check`,
`test_coordinating`, `test_expiry`, `test_full_mode_unchanged`, `test_graduate`,
`test_guard`, `test_issues`, `test_mode_record`, `test_on`, `test_precommit`, `test_secrets`,
`test_status_notices`, `test_verify`.

- Two sub-cases depend on the environment and say so when skipped: the TTY guard case (needs
  a pseudo-terminal) and "issues without gh" (only where `gh` is not in `/usr/bin:/bin`).
- `shellcheck -S warning`: clean. `betterleaks dir .`: no leaks.
- `./scripts/verify.sh --full` in the template prints "no commands configured". That is **not
  a pass**; it is expected for the unconfigured template (plan, Complexity Tracking).

## Manual — M1–M11

Run against real tools on 2026-10-17:
- **Claude Code sessions**: `claude -p` 2.1.293, in throwaway clones with the sandbox off
  through a git-ignored `settings.local.json`.
- **GitHub repositories**: public scratch repositories `mpefaur/hack-mode-scratch` and
  `mpefaur/hack-mode-event-scratch`.

| # | Result | Observed |
|---|---|---|
| M1 Claude Code | **PASS** | Typing `/speckit-clarify …` was refused by the native `UserPromptSubmit` hook with the redirect. The session-start context reported the mode and the active spec. When the agent invoked `speckit-specify` **on its own**, the skill ran the mandatory `before_specify` guard, which exited 2. The agent stopped without creating anything and pointed to `/speckit-hack-sprint` and `/speckit-hack-graduate`. |
| M2 Cursor | **Not run** | The `cursor-agent` CLI is not installed here. Evidence up to the agent boundary: Cursor's `beforeSubmitPrompt` dispatch exits 2 with the redirect, `sessionStart` emits `{"additional_context": …}`, and the generated Cursor skills read the mandatory hooks. **Open**: confirm that Cursor blocks a prompt on exit 2. |
| M3 Cline | **Not run** | No Cline CLI here. Evidence: the generated `.clinerules/workflows/speckit-hack-*.md` and the shared `before_*` hooks. |
| M4 Sprint + issues | **PASS — 159 s** from activation | One pass wrote `spec.md`, `plan.md` and `tasks.md`, and published 4 issues assigned to the owner. SC-002 (under 60 min): met. |
| M5 Required checks | **PASS** | `on --require-check` created branch protection with `secrets` and `verify`. A teammate without local hooks opened PR #5 with `specs/002-dark-mode/`: the `verify` job failed in 5 s ("only one spec per hackathon project…") and GitHub reported `mergeStateStatus: BLOCKED`. SC-004 and SC-006: met. |
| M6 3-person dry run | **Not run** | Needs people. Partial coverage: M5 plays a teammate without hooks, and M1 a teammate's agent. |
| M7 Coordinating vs a real repo whose default branch is `trunk` | **PASS — 27 s** (script path) | The commit in the event clone ran the secret scan and `hackathon mode check (ev, local-only)`. The push printed `target branch: trunk` and the local-only warning. Nothing was committed to the event repository. SC-011: met. |
| M8 `/hack-kickoff` | **PASS — 132 s** | One proposal block, waited for confirmation, activated, pinned `actions/setup-python` by SHA looked up with `gh api`, no scaffolding. SC-001: met. **Found 2 gaps, both fixed** (below). |
| M9 `/kickoff` | **PASS** | In an activated clone, `/kickoff` was refused at prompt time with the redirect. On a fresh clone, a full adoption removed `specs/`, `scripts/hack.sh`, `tests/hack/`, `.specify/hack/`, `.claude/skills/hack-kickoff/` and every marked block in `AGENTS.md`, `verify.sh` and CI. Inert leftovers: one `.gitignore` line, the constitution's "Hackathon Mode" section, and the template docs. |
| M10 `/speckit-hack-graduate` | **PASS** | The mode record and tooling were removed, and the debt became task `T9001` under `## Inherited debt`. `verify.sh` ran lint and tests in full mode. **Found 1 gap, fixed** (below). |
| M11 `/speckit-hack-demo` | **PASS** | `demo.md` with run-sheet, seed data, fallback recording, freeze, runtime check and rehearsal checklist; `check` still passes. |

## Gaps found by the manual runs, and their fixes

1. **M8 — no demo-check stub.** Right after activation, `verify` fails, because the smoke
   command points at a file nobody has created yet; the Stop hook would block every turn.
   *Fix*: `/hack-kickoff` Step 3 creates a minimal passing stub (verification configuration,
   not application code), and the `H0` work item replaces it with the first real step.
2. **M8 — no commit hooks.** `/hack-kickoff` did not run `pre-commit install`, unlike
   `/kickoff` Step 4. *Fix*: added to Step 3.
3. **M4 — broken paths in command bodies.** Spec Kit rewrites every `scripts/…` mention in a
   command body into the extension directory, so the sprint told the team to run a
   non-existent `.specify/extensions/hack/scripts/verify.sh`. *Fix*: a `verify.sh` shim beside
   the `hack.sh` shim, and `test_on` now asserts that every rewritten path exists.
4. **M4 — issue titles too long.** A long work-item description exceeded GitHub's
   256-character title limit. *Fix*: `issues` truncates titles to 80 characters and puts
   the full description in the issue body (covered in `test_issues`).
5. **M10 — the agent installed a tool.** To make the new lint command pass, the session
   installed `pyflakes` into the user's Python (reverted the same day). *Fix*: the graduate
   command now forbids installing tools; it reports missing ones instead.
6. **M9 — redundant refusal text** for `/kickoff`. *Fix*: reworded.
7. **Post-merge CI on `main` — a test compared against the `main` branch.**
   `test_full_mode_unchanged` (and part of `test_verify`) diffed against the local `main`
   branch. In PR CI that branch is absent, so the comparison was silently skipped; on `main`
   it compared the feature against itself, and failed. *Fix*: both now check properties and
   explicit expected outputs, with no branch dependency.

## Known side effects (documented, not failures)

- Spec Kit rewrites `.claude/settings.json` when it installs native hooks, reformatting the
  one-line `allowWrite` array. The JSON is equivalent.
- Activation registers the `bug` and `github` extensions for Cursor and Cline too
  (Spec Kit's per-agent registration).
- pre-commit stores the event-repository config path relative to the event clone, so moving
  either side means re-running `scripts/hack.sh hooks`.

## Still open before calling T062 complete

- M2 (Cursor) and M3 (Cline) in real sessions. Above all, confirm that Cursor honors exit 2
  on `beforeSubmitPrompt`.
- M6 with real people.
