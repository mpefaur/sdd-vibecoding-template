# Validation: Hackathon Mode

Status of [quickstart.md](quickstart.md) on branch `001-hackathon-mode`, 2026-10-17.

## Automated — `tests/hack/run.sh` (A1–A15)

```text
PASS test_check            A5, A7 (+ check under 2 s with 10,000 files)
PASS test_coordinating     A14
PASS test_expiry           A10
PASS test_full_mode_unchanged  A13
PASS test_graduate         A12
PASS test_guard            A3, A4 (TTY sub-case skipped: no pseudo-terminal in this environment)
PASS test_issues           T033 (missing-gh sub-case runs only where gh is not in /usr/bin:/bin)
PASS test_mode_record      T009
PASS test_on               A1, A2, rollback
PASS test_precommit        A6
PASS test_secrets          A15
PASS test_status_notices   A11, notices part of A1
PASS test_verify           A8, A9
13 passed, 0 failed   (macOS, bash 3.2 tests run via bash, Spec Kit 1.1.1, pre-commit 4.6.2; 77 s)
```

Other checks:
- `shellcheck -S warning` on `scripts/hack.sh`, `scripts/verify.sh`, `tests/hack/*.sh` and the
  extension shim: clean.
- `betterleaks dir .`: no leaks.
- `./scripts/verify.sh --full` in the template prints "no commands configured", which is
  **not a pass**. That is expected for the unconfigured template (plan, Complexity Tracking);
  `tests/hack/run.sh` is the proof.

## Manual — M1–M11

Evidence gathered **without** a live agent UI: in an activated scratch clone, Spec Kit's own
dispatcher (`.specify/events.py`) was run exactly as the installed native hooks call it.

| # | Status | Evidence / what is still needed |
|---|---|---|
| M1 Claude Code | **Partial** | `UserPromptSubmit` → `python3 .specify/events.py speckit.hack.guard user_prompt_submit 10` with `{"prompt":"/speckit-clarify auth?"}` exits **2** with the redirect; with a plain prompt it exits 0. `SessionStart` prints the status banner. Claude Code blocks on exit 2 by its hook contract. **Needed**: one real session to see the banner and the refusal in the UI. |
| M2 Cursor | **Partial — open item** | `beforeSubmitPrompt` (`suppress` envelope) exits **2** with the redirect; `sessionStart` emits `{"additional_context": …}`. The generated Cursor `speckit-specify` skill reads `hooks.before_specify`, which contains the mandatory `speckit.hack.guard`. **Needed**: confirm Cursor blocks a prompt on exit 2 (research "Spike results", T003b). |
| M3 Cline | **Partial** | `.clinerules/workflows/speckit-hack-guard.md` is generated with the shim path, and Cline's `speckit-plan` workflow reads the same `before_plan` hook. **Needed**: one real Cline run to see it stop. |
| M4 Sprint + issues | Pending | Needs a scratch GitHub repository (creating one is outward-facing: ask first). `issues` is covered against a `gh` stub in `test_issues`. |
| M5 Required checks | Pending | Needs a scratch GitHub repository with admin rights. |
| M6 3-person dry run | Pending | Needs people. Include one Cline teammate; time the CI verdict (SC-006). |
| M7 Coordinating vs real fork | Pending | Covered with local bare repositories in `test_coordinating`; needs a real fork whose default branch is not `main`, timed (SC-011). |
| M8 `/hack-kickoff` | Pending | Needs a fresh clone and a Claude Code session, timed (SC-001). |
| M9 `/kickoff` refusal and cleanup | Pending | Needs a Claude Code session. The skill text now refuses in hackathon mode and removes the R16 items. |
| M10 `/speckit-hack-graduate` | Pending | The script path is covered by `test_graduate`; needs the agent flow (question, confirmation). |
| M11 `/speckit-hack-demo` | Pending | Needs a sprint's spec to turn into `demo.md`. |

## Known side effects (documented, not failures)

- Spec Kit rewrites `.claude/settings.json` when it installs native hooks, reformatting the
  one-line `allowWrite` array. The JSON is equivalent, and graduation leaves it reformatted.
- Activation registers the `bug` and `github` extensions for Cursor and Cline as well
  (Spec Kit's per-agent registration). Those commands are blocked by the check in hackathon
  mode, and stay available after graduation.
- pre-commit stores the event-repository config path relative to the event clone. Moving the
  coordinating project or the clones means re-running `scripts/hack.sh hooks`.
