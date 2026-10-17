---

description: "Task list for Hackathon Mode"
---

# Tasks: Hackathon Mode

**Input**: Design documents from `specs/001-hackathon-mode/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Required by Constitution Principle III and the plan. Each story's tests come
from quickstart.md scenarios A1–A15. They are written first and must fail before
implementation. The test runner is `tests/hack/run.sh` (research R13).

**Organization**: Tasks are grouped by user story. **All stories edit `scripts/hack.sh`, so
stories run sequentially, never in parallel worktrees** (CLAUDE.md "Implementation
execution"). `[P]` marks tasks inside a phase that touch different files with no pending
dependency.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story from spec.md (US1–US7)
- Paths are relative to the repository root

## Conventions for every `scripts/hack.sh` task

- Bash 3.2 compatible: no associative arrays, no `${var,,}`, no `mapfile`.
- JSON goes through `python3 -I -c` (stdlib only).
- Messages: `hack:` (info), `hack: WARN` (warning), `hack: ERROR` (failure). With
  `GITHUB_ACTIONS=true`, warnings and errors are also emitted as `::warning::` and
  `::error::`.
- Exit codes are exactly as in [contracts/hack-cli.md](contracts/hack-cli.md): `0`
  ok/nothing to do, `1` failed/refused, `2` blocked (guard), `3` usage/environment.
- Every refusal names the allowed alternative.
- Never print secret values.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Directories, ignore rules, and the blocking Spec Kit spike (plan "Delivery order" step 1).

- [X] T001 Create the directories `.specify/hack/extension/commands/`, `.specify/hack/extension/templates/`, `tests/hack/fixtures/`, and add `.specify/hack/local/` to `.gitignore` under a `# Hackathon mode — machine-local state (scripts/hack.sh hooks)` comment.
- [X] T002 Spike R2 in a throwaway clone under `$TMPDIR`. Build a minimal extension with one command (`scripts: sh:` frontmatter), one `before_specify` hook (`optional: false`, no `condition`) and one `session_start` event. Install it with `specify extension add --dev <dir>`, then determine and record:
  - (a) how to register its commands for all three installed integrations (`claude`, `cursor-agent`, `cline` in `.specify/integration.json`), checked through `registered_commands` in `.specify/extensions/.registry`;
  - (b) the exact `hooks:` YAML shape `register_hooks` accepts;
  - (c) that `add` and `remove` write and strip the native entries in `.claude/settings.json` and `.cursor/hooks.json`;
  - (d) whether `remove` leaves any residue in `.specify/extensions.yml`.
  Write the results under a new `## Spike results (2026-10-…)` heading in `specs/001-hackathon-mode/research.md`, and correct R2 and R3 and `contracts/extension-manifest.md` if anything differs.
- [X] T003 Spike R3 and R12 in the same throwaway clone, and append the results to `specs/001-hackathon-mode/research.md` "Spike results":
  - (a) the stdin payload field that carries the prompt for Claude `UserPromptSubmit` and Cursor `beforeSubmitPrompt` through `.specify/events.py`;
  - (b) whether a handler exit code 2 blocks the prompt in each;
  - (c) that `pre-commit install -c <abs path> -t pre-commit -t pre-push` embeds the config path in `.git/hooks/pre-commit` and `.git/hooks/pre-push`;
  - (d) how `.betterleaksignore` can exclude `tests/hack/fixtures/` (path vs fingerprint).

**Checkpoint**: research.md has "Spike results"; any contract drift is fixed before Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The script skeleton, mode-record validation, extension shell, constitution and test harness that every story builds on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 [P] Create `tests/hack/lib.sh` with these helpers:
  - `make_clone`: copies the current working tree, including uncommitted and untracked non-ignored files from `git ls-files -co --exclude-standard`, into a fresh `git init` repo under `$TMPDIR/hack-tests/<name>` and commits it.
  - `assert_exit <code> <cmd…>`.
  - `assert_contains <file|-> <text>`.
  - `assert_file <path>` and `assert_absent <path>`.
  - `stub_bin <name> <script>`: prepends a fake binary to `PATH`, for `gh` and `specify` when not under test.
  - `synthetic_secret <file>`: writes a secret-shaped line assembled at run time from concatenated fragments (for example an AWS-style access key id built from `"AKIA"` plus generated characters), so no secret-shaped string ever exists in the repository (research "Spike results", T003d).
- [X] T005 [P] Create `tests/hack/run.sh`. It sources `lib.sh`, runs every `tests/hack/test_*.sh` in its own subshell, prints `PASS`/`FAIL <name>` per test and a final `N passed, M failed`, and exits 1 if any test failed. Make it executable.
- [X] T006 Create `scripts/hack.sh` (executable) with:
  - a header comment pointing at `specs/001-hackathon-mode/contracts/hack-cli.md` (the same style as `scripts/verify.sh`);
  - repo-root resolution via `git rev-parse --show-toplevel`;
  - the output helpers and exit-code constants from the conventions above;
  - dispatch for `on | status | guard | check | issues | hooks | graduate`, where unimplemented subcommands exit 3 with `not implemented`;
  - `usage` on no or unknown subcommand (exit 3);
  - `mode_active` (true when `.specify/mode.json` exists);
  - `mode_get <dotted.path>`, which reads one value through `python3 -I`.
- [X] T007 Add `mode_validate` to `scripts/hack.sh`, an embedded stdlib-Python validator implementing [contracts/mode-record.schema.json](contracts/mode-record.schema.json). It enforces, verbatim:
  - the required fields `mode, variant, event, ends_at, stack, commands, demo_check, feature_directory, spec_owner, owners, constitution_sha256, activated_at`;
  - `mode` is `"hackathon"`; `variant` is one of `"standard" | "coordinating"`; `demo_check` is one of `"automated" | "manual"`;
  - `commands.run` is a non-empty string; `commands.build` and `commands.smoke` are a string or `null`;
  - `feature_directory` matches `^specs/[0-9]{3}-[a-z0-9-]+$`;
  - `owners` has at least 1 item, each with `member` and at least one `paths`;
  - "a path pattern must not appear under two owners";
  - `event_repos[].name` matches `^[a-z0-9-]+$`, and each entry requires `name, path, url, target_branch`;
  - `variant = coordinating` requires `event_repos` with at least 1 item;
  - `demo_check = manual` requires `commands.smoke = null`, and `automated` requires a string;
  - `constitution_sha256` matches `^[0-9a-f]{64}$`;
  - no unknown top-level keys.
  On failure it exits 3 and names the field.
- [X] T008 [P] Create the fixtures in `tests/hack/fixtures/`:
  - `mode-valid-standard.json` and `mode-valid-coordinating.json`;
  - `mode-invalid-missing-owner.json`, `mode-invalid-coordinating-no-repos.json`, `mode-invalid-manual-with-smoke.json` and `mode-invalid-dup-path.json`;
  - no secret fixture: secrets are generated at run time by `synthetic_secret` in `lib.sh`, and `.betterleaksignore` is not changed.
- [X] T009 Create `tests/hack/test_mode_record.sh`: for each fixture, `make_clone`, copy the fixture to `.specify/mode.json`, and run `scripts/hack.sh check`. Each valid fixture passes validation (any R5 rule failures are out of scope here, since the clone has no extension installed, so assert only that the exit is not 3), and each invalid fixture exits 3 naming the offending field. (Run it before T007 to see it fail.)
- [X] T010 [P] Write `.specify/hack/extension/templates/hack-constitution.md` with exactly 4 principles:
  1. the demo script is the contract;
  2. happy path only;
  3. secrets never in the repository (the full constitution's Principle V, verbatim intent);
  4. debt is written down in `debt.md`, not paid.
  Add governance stating that it applies only while `.specify/mode.json` exists and is left only via graduate.
- [X] T011 Write `.specify/hack/extension/extension.yml` exactly per [contracts/extension-manifest.md](contracts/extension-manifest.md): id `hack`, version `1.0.0`, `requires.speckit_version: ">=1.1.1"`, the five `provides.commands`, seven mandatory unconditional `before_*` hooks to `speckit.hack.guard`, two mandatory unconditional hooks `before_implement` and `before_converge` to `speckit.hack.status` (pointer sync, research R4), and `events` `session_start` → `speckit.hack.status` (timeout 10) and `user_prompt_submit` → `speckit.hack.guard` (timeout 10). Use the `hooks` shape confirmed in T002(b).
- [X] T012 [P] Create `.specify/hack/extension/scripts/hack.sh`, an executable shim: `exec "$(git rev-parse --show-toplevel)/scripts/hack.sh" "$@"`. It exists because Spec Kit rewrites `scripts/…` command paths into the extension directory (research "Spike results"). Then create the thin command files in `.specify/hack/extension/commands/`:
  - `speckit.hack.status.md` (`scripts: sh: scripts/hack.sh status`; print the output verbatim);
  - `speckit.hack.guard.md` (`scripts: sh: scripts/hack.sh guard`; if it exits 2, stop, show its message, and never continue the blocked command);
  - `speckit.hack.graduate.md`, `speckit.hack.sprint.md` and `speckit.hack.demo.md`, each with frontmatter and a one-line description. Their bodies come in US5, US2 and Polish.
- [X] T013 Add a template self-test job to `.github/workflows/ci.yml`:
  - It goes in a new job `template-selftest`, wrapped in `# template-only:begin` / `# template-only:end` comment lines so adoption can remove it (research R16). Its steps run only when `grep -q '^## 0. First run' AGENTS.md` succeeds (the repo is the unadopted template).
  - It installs `uv` via `astral-sh/setup-uv` pinned by full commit SHA with the version in a comment (look it up with `gh api repos/astral-sh/setup-uv/git/ref/tags/<tag>`, never invent one), then `uv tool install specify-cli==<SPECKIT_VERSION from scripts/setup.sh>` and `uv tool install pre-commit==4.6.2`. Both are pinned (Constitution V); never install either unpinned.
  - It runs `tests/hack/run.sh`.

**Checkpoint**: `tests/hack/run.sh` runs and `test_mode_record.sh` passes; the extension source installs in a scratch clone.

---

## Phase 3: User Story 1 — Activate hackathon mode on a fresh project (Priority: P1) 🎯 MVP

**Goal**: A one-time, committed activation that every clone sees. Full-mode adoption and hackathon adoption exclude each other.

**Independent Test**: quickstart A1 and A2. A fresh clone runs `scripts/hack.sh on …`, and a second clone of the committed result reports the same event, end time and stack.

### Tests for User Story 1

- [X] T014 [P] [US1] Create `tests/hack/test_on.sh`. It covers:
  - A1: in a `make_clone`, `on` with all required flags exits 0; `.specify/mode.json` is valid; `## 0. First run` is gone from `AGENTS.md`; §1 has no `<PLACEHOLDERS>`; the template `specs/` is gone; the `# template-only` block is gone from `.github/workflows/ci.yml`; the extension is registered for every integration in `.specify/integration.json`.
  - A2: a second `on` exits 1 with "mode is chosen once"; `on` on a clone whose §1 is already filled exits 1.
  - A failing extension install (use `stub_bin specify` exiting 1) leaves the tree identical to before (rollback).

### Implementation for User Story 1

- [X] T015 [US1] Implement `on` argument parsing in `scripts/hack.sh`, with the flags exactly as in contracts/hack-cli.md `on`, then these preconditions:
  - §1 unadopted, using the same `grep -c '<PROJECT_NAME>\|<ONE_SENTENCE>\|<LANGUAGES / FRAMEWORKS>\|<COMMAND>' AGENTS.md` as `.claude/skills/kickoff/SKILL.md` Step 0;
  - `.specify/mode.json` absent;
  - `specify` on PATH, else exit 3 with `run ./scripts/setup.sh`;
  - owners parsed from `--owner <handle>=<glob>[,<glob>]`.
  It refuses when "a path pattern must not appear under two owners" is violated.
- [X] T016 [US1] Implement `on` effects 1–2 in `scripts/hack.sh`:
  - delete every directory under `specs/` (template-owned, R9), and delete the `# template-only:begin` … `# template-only:end` block from `.github/workflows/ci.yml` (R16);
  - derive the event slug: the event name lowercased, every run of characters outside `[a-z0-9]` replaced by one `-`, leading and trailing `-` trimmed, truncated to 40 characters;
  - in `AGENTS.md`, replace the four §1 bullets with Name (event slug), Purpose (`--event`), Stack (`--stack`), and Run/Test/Lint/Build, where Test = `scripts/hack.sh check` + smoke, Lint = `n/a (hackathon mode)` and Build = `--build`;
  - delete the `> Replace the <PROJECT> placeholders…` admonition and the whole `## 0. First run` section, as `/kickoff` Step 2 does.
- [X] T017 [US1] Implement `on` effect 3 in `scripts/hack.sh`: install `.specify/hack/extension` as the `hack` extension for every integration in `.specify/integration.json` `installed_integrations`, using the method recorded in research "Spike results":
  - run `specify extension add --dev .specify/hack/extension`;
  - snapshot the tracked tree (`git stash create`, or a list of `git ls-files -m` paths with their blobs);
  - run `specify integration use <key>` for each other installed integration, then `specify integration use <original default_integration>`;
  - restore with `git checkout -- <path>` every tracked file the loop changed, except `.specify/extensions/.registry`, `.specify/integrations/*.manifest.json` and `.specify/integration.json`. This undoes the executable-bit loss and the regeneration of existing Spec Kit command files;
  - keep the new untracked `bug` and `github` command files for Cursor and Cline (documented side effect);
  - assert `registered_commands` in `.specify/extensions/.registry` lists `hack` for every installed integration.
- [X] T018 [US1] Implement `on` effect 4 in `scripts/hack.sh`: write `.specify/mode.json` with the fields in [data-model.md](data-model.md):
  - `feature_directory` = `specs/001-<event-slug>`;
  - `constitution_sha256` = the sha256 of `.specify/extensions/hack/templates/hack-constitution.md`;
  - `activated_at` = the current UTC time in ISO-8601;
  - `demo_check` = `manual` when `--smoke manual` (then `commands.smoke: null`), and `commands.build: null` when `--build none`.
  Validate the result with `mode_validate`.
- [X] T019 [US1] Implement rollback in `on` in `scripts/hack.sh`: snapshot the paths it will touch, and on any failing step restore them (`git checkout -- <tracked>`, remove created files, `specify extension remove hack` if installed). Then exit 1 naming the failed step.
- [X] T020 [US1] Implement `on --require-check` in `scripts/hack.sh`: with `gh` present, require the status-check contexts `secrets` and `verify` (the job names in `.github/workflows/ci.yml`; never `template-selftest`) on the default branch via `gh api -X PUT repos/{owner}/{repo}/branches/{branch}/protection`, preserving existing settings where `gh api` returns them. If `gh` is missing or the call is refused, print a `WARN` with the manual steps; never fail activation.
- [X] T021 [US1] Create `.claude/skills/hack-kickoff/SKILL.md`, modeled on `.claude/skills/kickoff/SKILL.md`. It covers:
  - Step 0: unadopted §1 and `.specify/mode.json` absent, else stop.
  - Step 1: ask the event's imposed stack in one question, together with the event name, end time, team handles with their paths, spec owner, variant and runtime versions; propose a concrete block (run/build/smoke commands) and wait for confirmation.
  - Step 2: run `scripts/hack.sh on …`.
  - Step 3: as kickoff Step 3, add the sandbox `allowedDomains` and package-cache `allowWrite`, and the CI toolchain pinned by full commit SHA.
  - Step 4: offer `--require-check` and run it only on explicit confirmation.
  - Step 5: report, and hand off to `/speckit-hack-sprint` (plus `scripts/hack.sh hooks` per teammate in the coordinating variant).
  - It writes configuration and documentation only, never scaffolding (FR-005). It never commits.
- [X] T022 [US1] Edit `.claude/skills/kickoff/SKILL.md`:
  - in Step 0, before the grep, if `.specify/mode.json` exists, say "this project is in hackathon mode; the only exit is `/speckit-hack-graduate`" and stop (FR-003);
  - in Step 2, add "4. Delete every directory under `specs/` — a fresh clone has no project specs; these belong to the template (R9)" and "5. Remove the template-only hackathon tooling (R16): `.claude/skills/hack-kickoff/`, `.specify/hack/`, `scripts/hack.sh`, `tests/hack/`, and the `# template-only:begin/end` and `# hackathon-mode:begin/end` blocks in `.github/workflows/ci.yml`".

**Checkpoint**: `tests/hack/test_on.sh` passes; activation is one-time and committed.

---

## Phase 4: User Story 3 — Full-flow and bug-lane steps are blocked for any agent (Priority: P1)

**Goal**: Every agent with the template's commands is redirected, and the state check rejects full-flow artifacts at commit time and in CI regardless of agent.

**Independent Test**: quickstart A3–A7 and A15, plus manual M1–M3 at Polish.

### Tests for User Story 3

- [X] T023 [P] [US3] Create `tests/hack/test_guard.sh`:
  - A3: in an activated clone, `guard` exits 2 with a redirect for each of `speckit.constitution speckit.specify speckit.clarify speckit.plan speckit.tasks speckit.analyze speckit.checklist speckit.bug.assess speckit.bug.fix speckit.bug.test kickoff`, in the forms `speckit.clarify`, `/speckit-clarify` and `speckit-clarify`, and for a prompt payload on stdin starting with `/speckit-clarify`, in the shape found in T003(a).
  - A3 (no input): `guard` with no argument and stdin from `/dev/null`, and with no argument under `script -q /dev/null` (a TTY), exits 2 within 1 s, without waiting on stdin.
  - A4: `guard` exits 0 for `speckit.implement`, `speckit.converge` and `speckit.hack.sprint`, and for a piped plain prompt.
- [X] T024 [P] [US3] Create `tests/hack/test_check.sh`:
  - A5: in an activated clone with `specs/001-<slug>/spec.md`, `check` exits 0; then each of these makes it exit 1 with one `ERROR` naming the path: adding `specs/002-x/spec.md`; adding `research.md` in the active directory; adding `.specify/bugs/y/assessment.md`; editing `.specify/extensions/hack/templates/hack-constitution.md`.
  - A7: `check --changed api/a.py web/b.tsx` with two owners exits 0 and prints two `WARN` lines naming each owner.
  - Performance: with 10,000 extra committed files in the clone, `check` completes in under 2 s (plan Performance Goals).
  - In a full-mode clone, `check` exits 0 with no output.
- [X] T025 [P] [US3] Create `tests/hack/test_precommit.sh` (A6): with `pre-commit install` in an activated clone, a `git commit` containing each A5 violation is rejected by the `hack-check` hook.
- [X] T026 [P] [US3] Create `tests/hack/test_secrets.sh` (A15): committing a `leak.txt` written by `synthetic_secret` is rejected by the Betterleaks pre-commit hook, both in a full-mode clone and in an activated clone, with identical hook output apart from timing.

### Implementation for User Story 3

- [X] T027 [US3] Implement `guard <command-id>` in `scripts/hack.sh`.
  - Normalize `speckit.x.y`, `/speckit-x-y` and `speckit-x-y` to the dotted id.
  - Resolve input in the order of contracts/hack-cli.md `guard`: (1) an argument is evaluated as given; (2) with no argument and `[ ! -t 0 ]`, read the prompt payload from stdin (field per T003(a)) and evaluate its leading slash command, allowing a prompt with none; (3) with no argument and a TTY or empty stdin, exit 2 with a generic redirect (`hackathon mode: this command is disabled — run scripts/hack.sh status`). Never block waiting on stdin: use `[ -t 0 ]` and a non-blocking read.
  - Blocked in hackathon mode: `speckit.constitution, speckit.specify, speckit.clarify, speckit.plan, speckit.tasks, speckit.analyze, speckit.checklist, speckit.bug.assess, speckit.bug.fix, speckit.bug.test, kickoff`. Each exits 2 with its redirect:

    | Blocked | Redirect |
    |---|---|
    | specify, plan, tasks | `/speckit-hack-sprint` |
    | clarify | "record an assumption in spec.md" |
    | constitution | "the hackathon constitution is fixed" |
    | analyze, checklist | "skipped in hackathon mode" |
    | bug.* | "fix directly once the demo check reproduces it; otherwise add it to debt.md" |
    | kickoff | "graduate is the only exit" |

  - Everything else exits 0. Full mode always exits 0.
- [X] T028 [US3] Implement `check` in `scripts/hack.sh`.
  - Full mode: exit 0 silently.
  - Hackathon mode: run `mode_validate`, then the R5 rules:
    1. `specs/` contains only `feature_directory`;
    2. that directory contains only `spec.md`, `plan.md`, `tasks.md`, `demo.md`, `debt.md`;
    3. `.specify/bugs/` holds no content;
    4. sha256 of `.specify/extensions/hack/templates/hack-constitution.md` == `constitution_sha256`.
    Print one `ERROR` per violation with what to do, and exit 1 if any.
  - `--changed <file>…`: match each file against `owners[].paths` with Python `fnmatch` (stripping a `<repo>:` prefix in the coordinating variant), and print one `WARN` per owner when the files span more than one owner. This never changes the exit code.
- [X] T029 [US3] Implement `on` effect 6 in `scripts/hack.sh`: insert, between `# hackathon-mode:begin` / `# hackathon-mode:end` lines at the end of `.pre-commit-config.yaml`, a `repo: local` hook with `id: hack-check`, `name: hackathon mode check`, `entry: scripts/hack.sh check --changed`, `language: system`, `pass_filenames: true`, `always_run: true`. Then re-run `pre-commit install` if `pre-commit` is present.
- [X] T030 [US3] Edit `scripts/verify.sh`: when `.specify/mode.json` exists, run `scripts/hack.sh check` first (label `check`) and stop on failure. When it is absent, the existing full-mode path stays byte-for-byte unchanged in behavior and output.
- [X] T031 [US3] Add a step to the `verify` job in `.github/workflows/ci.yml`, wrapped in `# hackathon-mode:begin` / `# hackathon-mode:end` comment lines (research R16), gated with `if: github.event_name == 'pull_request' && hashFiles('.specify/mode.json') != ''`, that runs `scripts/hack.sh check --changed $(git diff --name-only origin/${{ github.base_ref }}...HEAD)`. Set `fetch-depth: 0` only on that job's checkout.
- [X] T032 [US3] Fill `.specify/hack/extension/commands/speckit.hack.guard.md` with the full agent instructions: when run as a lifecycle hook, run the script with **no argument and no stdin** (it blocks, per contracts/hack-cli.md `guard`); on exit 2, stop, show its message verbatim, and do not continue the command that invoked the hook; on exit 0, continue silently.

**Checkpoint**: `test_guard.sh`, `test_check.sh`, `test_precommit.sh` and `test_secrets.sh` pass.

---

## Phase 5: User Story 2 — Produce the single demo-centered spec, plan and work items (Priority: P1)

**Goal**: `/speckit-hack-sprint` produces spec, plan and tasks in one pass and publishes assigned issues.

**Independent Test**: quickstart M4 (manual, GitHub), plus the automated issue parsing below.

### Tests for User Story 2

- [X] T033 [P] [US2] Create `tests/hack/test_issues.sh`. With `stub_bin gh` recording its arguments and returning one existing issue titled `H001 …`, `issues --dry-run` on a fixture `tasks.md` with H001–H003 prints exactly H002 and H003, each with `--assignee <member>`. A work item whose `[@member]` does not own one of its `paths:` makes `issues` exit 1 naming it. A missing `gh` exits 3.

### Implementation for User Story 2

- [X] T034 [P] [US2] Write `.specify/hack/extension/templates/hack-spec-template.md` with these sections: Problem · Users · Demo script (numbered stage steps; each step states what the audience sees and becomes one demo-check step) · Out of scope · Assumptions. No `[NEEDS CLARIFICATION]` usage: assumptions replace questions.
- [X] T035 [P] [US2] Write `.specify/hack/extension/templates/hack-plan-template.md`, at most one page, with these sections: Stack and runtimes · Integration contract (inline; no `contracts/` directory) · Ownership map (member → paths, matching `.specify/mode.json`) · Mocks and fakes · Deploy target · Debt we accept.
- [X] T036 [P] [US2] Write `.specify/hack/extension/templates/hack-tasks-template.md`:
  - checkpoints `H0` (deploy a hello world), one per slice group, `FREEZE` (no new work after it) and `REHEARSAL`;
  - the work-item line format verbatim: `- [ ] H012 [@member] [slice: <demo step>] [≤90m] <description> — paths: <glob>, <glob>`;
  - the rules "A work item crossing owners is split, never shared" and "Done = that step is added to the demo check and passes";
  - a "Log debt" section with the `debt.md` entry format verbatim: `- D007 | <shortcut or unreproduced defect> | where: <path> | why: <hackathon reason> | repay: <what full mode needs>`, and the rule that graduation turns every entry into a task.
- [X] T037 [US2] Implement `issues` in `scripts/hack.sh`.
  - Parse work items from `<feature_directory>/tasks.md` with the data-model format.
  - Validate that `[@member]` is in `owners[].member` and owns every `paths:` glob.
  - List existing titles with `gh issue list --state all --json title --limit 1000`, and skip IDs matching `\bH\d{3,}\b` already present.
  - Create the rest with `gh issue create --title "H<NNN> <description>" --assignee <member> --body "<slice, time box, paths, link to tasks.md>"`.
  - Support `--dry-run`. Without `gh`, exit 3.
- [X] T038 [US2] Fill `.specify/hack/extension/commands/speckit.hack.sprint.md` with the agent instructions:
  - Read `.specify/mode.json`; write `.specify/feature.json` from `feature_directory`.
  - Refuse unless the caller is `spec_owner` (compare `gh api user -q .login` when `gh` is present, else ask).
  - Refuse a second spec. Revisions are allowed only by the owner, and scope cuts move items to "Out of scope" and close or relabel their issues with `gh`.
  - Resolve `hack-spec-template`, `hack-plan-template` and `hack-tasks-template` via `.specify/scripts/bash/resolve-template.sh <name>`, and fill all three in one pass: at most 3 questions, record assumptions, no `[NEEDS CLARIFICATION]`, the ownership map copied from `mode.json`.
  - Run `scripts/hack.sh check`, then `scripts/hack.sh issues`.
  - Report the issue links.

**Checkpoint**: `test_issues.sh` passes; a sprint on a scratch GitHub repo yields assigned issues (recorded in M4).

---

## Phase 6: User Story 4 — Teammates work in parallel against a shared definition of done (Priority: P2)

**Goal**: Any teammate, with any agent, learns the mode from the repository, finds the spec, and knows "done" means the demo check plus the build.

**Independent Test**: quickstart A8, A9 and A11, the notice part of A1, and M6 at Polish.

### Tests for User Story 4

- [X] T039 [P] [US4] Create `tests/hack/test_verify.sh`:
  - A8: an activated clone with `commands.smoke: "true"` and `commands.build: "true"`; `scripts/verify.sh` runs check → smoke and `--full` runs check → smoke → build, each ending `verify: OK`.
  - A9: with `demo_check: manual`, `--full` prints `MANUAL` and never `smoke` passed.
  - With `commands.build: null`, `--full` prints `build: not applicable`.
  - Full mode: verify.sh output is identical to `main`'s for the same env (`LINT_CMD=true TEST_CMD=true`).
- [X] T040 [P] [US4] Create `tests/hack/test_status_notices.sh`:
  - A11: delete `.specify/feature.json`, run `status`, and `.specify/feature.json` points at `feature_directory`.
  - After `on`, each of `AGENTS.md`, `.github/copilot-instructions.md`, `.cursor/rules/sdd-workflow.mdc` and `.clinerules/00-agents.md` contains exactly one `hackathon-mode:begin`/`end` block naming the active spec, `scripts/hack.sh status`, and the definition of done.
  - `status` prints the fields in contract order.

### Implementation for User Story 4

- [X] T041 [US4] Extend the hackathon branch of `scripts/verify.sh`. After check:
  - when `demo_check` is `automated`, run `commands.smoke` (label `smoke`);
  - when it is `manual`, print `verify: smoke MANUAL — run the demo checklist in <feature_directory>/demo.md`, plus `::warning::` under `GITHUB_ACTIONS`, without counting it as passed;
  - with `--full`, run `commands.build` (label `build`), or print `verify: build not applicable` when `null`.
  Read all values via `scripts/hack.sh` helpers, not duplicated parsing.
- [X] T042 [US4] Implement `status` in `scripts/hack.sh`.
  - Full mode: print `hack: full mode` and exit 0.
  - Hackathon mode: rewrite `.specify/feature.json` from `feature_directory` (R9), then print, in this order: event, ends at, variant, stack and runtimes, active spec, spec owner, owners and paths, allowed commands, blocked commands, definition of done.
- [X] T043 [US4] Implement `on` effect 5 in `scripts/hack.sh`: insert notices between `<!-- hackathon-mode:begin -->` / `<!-- hackathon-mode:end -->` at the top of the body of `AGENTS.md`, `.github/copilot-instructions.md`, `.cursor/rules/sdd-workflow.mdc` (after the frontmatter) and `.clinerules/00-agents.md`. The text: "HACKATHON MODE — `<event>`. Active spec: `<feature_directory>`. Run `scripts/hack.sh status`. Done = `scripts/verify.sh --full` (check + demo check + build). Full-flow and bug-lane commands are disabled. Do not create other specs. Before `/speckit-implement`, run `scripts/hack.sh status` (it syncs the active-spec pointer). Log shortcuts in `<feature_directory>/debt.md` as `- D<NNN> | <shortcut> | where: <path> | why: <reason> | repay: <what full mode needs>`."
- [X] T044 [US4] Fill `.specify/hack/extension/commands/speckit.hack.status.md`: run the script and print its output verbatim. As the `session_start` handler, it must stay under the 10 s event timeout.

**Checkpoint**: `test_verify.sh` and `test_status_notices.sh` pass.

---

## Phase 7: User Story 5 — Graduate a hackathon project to the full flow (Priority: P2)

**Goal**: Graduation removes every trace of hackathon mode, restores full verification, and hands the debt to `/speckit-converge`.

**Independent Test**: quickstart A12.

### Tests for User Story 5

- [X] T045 [P] [US5] Create `tests/hack/test_graduate.sh` (A12):
  - In an activated clone with a `debt.md` holding two entries, `graduate --lint true --test true` exits 0.
  - Afterwards: `.specify/mode.json`, every `hackathon-mode` block, the pre-commit block and `.specify/extensions/hack/` are gone; no hack entries remain in `.claude/settings.json`, `.cursor/hooks.json` or `.specify/extensions.yml`; `scripts/verify.sh --full` runs `LINT_CMD`/`TEST_CMD`; `tasks.md` has `## Inherited debt` with two tasks; `debt.md` is gone; `scripts/hack.sh`, `tests/hack/`, `.specify/hack/` and `.claude/skills/hack-kickoff/` are gone and AGENTS.md §1 is adopted (re-entry impossible).
  - The `# hackathon-mode` block is gone from `.github/workflows/ci.yml`.
  - `graduate` on a non-default branch exits 1 naming the branch.
  - Coordinating variant without `--code-repo` exits 1 with the reason.

### Implementation for User Story 5

- [X] T046 [US5] Implement `graduate` in `scripts/hack.sh`, per contracts/hack-cli.md. Precondition: the current branch is the default branch (`git symbolic-ref refs/remotes/origin/HEAD`, falling back to `main`), else exit 1 naming it.
  1. Set `LINT_CMD`, `TEST_CMD` and `BUILD_CMD` in `scripts/verify.sh`, keeping the `${VAR:-default}` form as `/kickoff` Step 3 does.
  2. Append each `D<NNN>` line in `debt.md` to `tasks.md` under `## Inherited debt` as `- [ ] T9<NNN> <shortcut> — where: <path> — repay: <what full mode needs>`, then delete `debt.md`.
  3. `specify extension remove hack --force`, then delete the empty `.specify/extensions/.backup/hack/` it leaves behind.
  4. Remove the sentinel blocks from the 4 instruction files, `.pre-commit-config.yaml` and `.github/workflows/ci.yml` (`# hackathon-mode:begin/end`).
  5. Delete `.specify/mode.json`, then remove the R16 hackathon tooling (`.claude/skills/hack-kickoff/`, `.specify/hack/`, `tests/hack/`, the `# hackathon-mode` blocks in `scripts/verify.sh` and `.github/workflows/ci.yml`, `<!-- template-only -->` lines in `AGENTS.md`, and `scripts/hack.sh` last).
  6. Report open branches (`git branch -a --no-merged`) without touching them, and print the next step `/speckit-converge`.
  - In the coordinating variant, `--code-repo` is required (else exit 1), and the full-mode adoption steps for that repository are printed.
- [X] T047 [US5] Fill `.specify/hack/extension/commands/speckit.hack.graduate.md`: ask for the real lint and test commands (and build if it changed), confirm with the user, run `scripts/hack.sh graduate …`, then point to `/speckit-converge`. Never commit.

**Checkpoint**: `test_graduate.sh` passes.

---

## Phase 8: User Story 6 — Hackathon mode with an organizer-provided repository (Priority: P2)

**Goal**: The coordinating variant. Spec and work live in the template project, code lives in event repositories, and local-only enforcement is stated everywhere.

**Independent Test**: quickstart A14, plus M7 at Polish.

### Tests for User Story 6

- [X] T048 [P] [US6] Create `tests/hack/test_coordinating.sh` (A14). It sets up two local bare repos as "event repositories" with clones beside the coordinating clone, then checks:
  - `on --variant coordinating --event-repo be=../be,<url>,trunk --event-repo fe=../fe,<url>,trunk --owner a=be:** --owner b=fe:** …` exits 0;
  - `hooks` installs pre-commit in both clones and `git status` there shows no changes;
  - a commit of a `synthetic_secret` file in `be` is rejected;
  - a commit adding `specs/x/spec.md` in `fe` is rejected by `hack-event-check`, and both rejections print `local-only check — nothing enforces this on the organizers' side`;
  - `git push` from `fe` prints `trunk` and the local-only warning;
  - `status` lists both repos with their target branches and the `WARN enforcement on event repositories is local-only and can be bypassed` line;
  - `on --variant coordinating` with no `--event-repo` exits 3 (invalid mode record: "requires at least 1 event repository").

### Implementation for User Story 6

- [X] T049 [US6] Extend `on` in `scripts/hack.sh`:
  - parse `--variant standard|coordinating` (default `standard`) and repeatable `--event-repo <name>=<path>,<url>,<target-branch>` into `event_repos[]`;
  - require at least one event repo for `coordinating`;
  - require owner paths prefixed by an existing `<repo-name>:`;
  - in the coordinating variant, apply `--require-check` to the coordinating project only.
- [X] T050 [US6] Implement `hooks` in `scripts/hack.sh`.
  - Standard variant: print `not needed` and exit 0.
  - Coordinating variant:
    - Write `.specify/hack/local/event-<name>-pre-commit.yaml` (one per event repository) with absolute paths: Betterleaks at the same `rev` as `.pre-commit-config.yaml` (`v1.9.0`), `detect-private-key` from `pre-commit-hooks` at the same `rev` (`v6.0.0`), a `repo: local` `hack-event-check` hook (`entry: <abs coordinating root>/scripts/hack.sh check --event-repo <name> --changed`, `language: system`, `pass_filenames: true`, `stages: [pre-commit]`), and a `repo: local` `pre-push` stage hook printing `target branch: <target_branch>` and `local-only enforcement` for that repo.
    - Implement `check --event-repo <name>` per contracts/hack-cli.md `check` "Event-repo mode": reject (exit 1) any `--changed` path under `specs/` or `.specify/`; apply the ownership warning with `<name>:` owner paths; always print `hack: WARN local-only check — nothing enforces this on the organizers' side`.
    - For each `event_repos[]` clone, run `pre-commit install -c <abs config> -t pre-commit -t pre-push`.
    - Report missing clones and migration mode.
    - Never write tracked files in event repositories. Without `pre-commit`, exit 3.
- [X] T051 [US6] Extend `status` and the `on` effect-5 notice in `scripts/hack.sh` for the coordinating variant: one line per event repo with its target branch, then `WARN enforcement on event repositories is local-only and can be bypassed`.
- [X] T052 [US6] Extend `.claude/skills/hack-kickoff/SKILL.md` Step 1 with the coordinating branch: ask for each event repository (name, local path, URL, target branch, verified with `git -C <path> remote show origin`, because a fork's default may not be `main`, as in Qodo `trunk`), and remind each teammate to run `scripts/hack.sh hooks` once per machine.

**Checkpoint**: `test_coordinating.sh` passes.

---

## Phase 9: User Story 7 — Expiry warning (Priority: P3)

**Goal**: After `ends_at`, a warning appears everywhere and never blocks.

**Independent Test**: quickstart A10.

### Tests for User Story 7

- [X] T053 [P] [US7] Create `tests/hack/test_expiry.sh` (A10): with `ends_at` set in the past, `status`, `check` and `scripts/verify.sh` print `WARN hackathon ended <ends_at> — graduate (/speckit-hack-graduate) or archive the repository`, and their exit codes equal those with a future `ends_at`. Under `GITHUB_ACTIONS=true` the line is also a `::warning::`.

### Implementation for User Story 7

- [X] T054 [US7] Add `warn_if_expired` to `scripts/hack.sh` (comparing UTC with offset-aware `ends_at` through `python3 -I`), and call it from `status`, `check` and the hackathon branch of `scripts/verify.sh`. It never changes an exit code.

**Checkpoint**: `test_expiry.sh` passes.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Governance, docs, the demo command, zero-change proof, and the manual validation.

- [X] T055 [P] Fill `.specify/hack/extension/commands/speckit.hack.demo.md`: build `<feature_directory>/demo.md` from the spec's demo script, with seed data, per-step timings, a fallback recording, a `FREEZE` time before the official end, a "do not restart services holding in-memory data" note, runtime versions, the event repos' target branches, and a rehearsal checklist (research "Lessons carried from the Qodo hackathon"). Traces to FR-037 and data-model `demo.md`.
- [X] T056 [P] Write `.specify/hack/extension/README.md`: what the extension is, that it is installed only by `scripts/hack.sh on` and removed by `graduate`, why its source lives outside `.specify/extensions/` (plan Complexity Tracking), and its commands, hooks and events.
- [X] T057 Amend `.specify/memory/constitution.md` to v1.2.0 (MINOR): add a `## Hackathon Mode` section stating that while `.specify/mode.json` exists the project is governed by `.specify/extensions/hack/templates/hack-constitution.md`, that Principle V and Quality Gates 4–5 still apply unchanged, and that the only exit is graduation. Update `**Last Amended**` to the commit date and add a Sync Impact Report comment.
- [X] T058 [P] Edit `AGENTS.md`: one line under §2 Rules ("Team hackathon (24–48h)? Adopt with `/hack-kickoff` instead — see `docs/TEMPLATE_USAGE.md` §Hackathon mode"), and in §9 add `.specify/hack/`, `scripts/hack.sh` and `tests/hack/`. Keep the file under about 120 lines excluding §0.
- [X] T059 [P] Add a `## Hackathon mode` section to `docs/TEMPLATE_USAGE.md`: when to use it (2–5 people, 24–48 h, happy-path PoC), activation, team setup (issues, ownership, the demo check growing per slice), the coordinating variant with its local-only limit, graduation, how to correct `ends_at` (edit `.specify/mode.json`, then `scripts/hack.sh check`), and the known limits from research R3, R4 and R14 (Cline has no native hooks; the bug lane has no hook points, so an agent invoking it on its own is caught only by the check; Codex, Copilot and Gemini get notices and CI only; no PowerShell parity).
- [X] T060 Create `tests/hack/test_full_mode_unchanged.sh` (A13): a never-activated clone has hook sets in `.claude/settings.json`, `.cursor/hooks.json` and `.specify/extensions.yml`, a skills list (`ls .claude/skills .cursor/skills .clinerules/workflows`) and `pre-commit run --all-files` hook names identical to `main` at the start of this feature, apart from the R16 template-only items (`.claude/skills/hack-kickoff/`, and the `template-selftest` job and hackathon-mode step in `.github/workflows/ci.yml`), listed as the only expected differences. Separately, assert that running T016's template-only removal on a clone leaves none of the `template-only` block. `/kickoff`'s own removal is verified manually in M9.
- [X] T061 Run `tests/hack/run.sh` and `./scripts/verify.sh --full`, reading the actual output. verify.sh is expected to report "no commands configured" in the template, which is not a pass; state that, with the run.sh result as the real proof.
- [ ] T062 Execute manual scenarios M1–M11 from quickstart.md:
  - Claude, Cursor and Cline sessions in an activated scratch clone;
  - `/speckit-hack-sprint` on a scratch GitHub repo;
  - a PR with `--require-check`;
  - a 3-person dry run that includes a Cline teammate;
  - a coordinating run against a fork whose default branch is not `main`;
  - `/hack-kickoff`, `/kickoff` refusal and cleanup, `/speckit-hack-graduate`, `/speckit-hack-demo`.
  Record the observed output **and the measured times** for each (SC-001 under 10 min, SC-002 under 60 min, SC-006 under 3 min, SC-011 under 15 min) in `specs/001-hackathon-mode/validation.md`, marking any `FAIL` and any R3 item that behaved differently.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T002 and T003 are blocking spikes; their results may change Phase 2 tasks.
- **Foundational (Phase 2)**: Depends on Setup. Blocks all stories.
- **User stories (Phases 3–9)**: Sequential, in this order: US1 → US3 → US2 → US4 → US5 → US6 → US7. Every story edits `scripts/hack.sh`, so none run in parallel worktrees.
  - US3 needs US1 (an activated clone to test against).
  - US2 needs US3's `check` (sprint runs it).
  - US4's notices extend `on` from US1.
  - US5 removes what US1, US3 and US4 add.
  - US6 extends `on`, `status` and the notices.
  - US7 adds a shared helper used by `status`, `check` and verify.sh.
- **Polish (Phase 10)**: After all stories. T060–T062 last.

### Within Each User Story

- Test tasks first; run them and see them fail before implementing.
- `scripts/hack.sh` subcommand → `scripts/verify.sh` / CI / instruction files → command-file bodies → skill files.
- The story's checkpoint test passes before the next story starts.

### Parallel Opportunities

- Setup: none (T002 and T003 both write research.md).
- Foundational: T004, T005, T008, T010 and T012 are [P]. T006 → T007 → T009 are sequential. T011 after T002. T013 after T005.
- Within stories: each story's test task is [P] with the other [P] tasks of that story. In US2, the three templates (T034–T036) are [P] with each other.
- Polish: T055, T056, T058 and T059 are [P].

---

## Parallel Example: User Story 2

```bash
# Different files, no shared dependency:
Task: "Write hack-spec-template.md in .specify/hack/extension/templates/"
Task: "Write hack-plan-template.md in .specify/hack/extension/templates/"
Task: "Write hack-tasks-template.md in .specify/hack/extension/templates/"
Task: "Create tests/hack/test_issues.sh"
# Then sequentially: T037 (issues in scripts/hack.sh) → T038 (sprint command body)
```

---

## Implementation Strategy

### MVP First (User Story 1, then US3)

1. Phase 1 (spike results recorded) → Phase 2 (harness green on `test_mode_record.sh`).
2. US1: activation is one-time and committed (`test_on.sh`).
3. US3: guard and check. Together with US1 this is the smallest version that delivers the team lead's core requirement, "can't drift into the full flow".
4. **Stop and validate**: run M1–M3 early on a scratch clone, because agent behavior is the riskiest assumption (R3, R4).

### Incremental Delivery

US2 (sprint and issues) → US4 (definition of done and notices) → US5 (graduate) → US6
(coordinating variant) → US7 (expiry warning) → Polish. After each story, run
`tests/hack/run.sh`, which must stay green, and commit with a Conventional Commit message,
for example `feat(hack): add hackathon mode check`.

---

## Notes

- `.claude/skills/` and `.claude/settings.json` are write-protected by the sandbox; expect a permission prompt for T021, T022 and T052, and for activation runs that write native hooks.
- `.git/hooks/` writes (`pre-commit install`) need the unsandboxed retry in Claude Code (research R12).
- `.specify/scripts/bash/*.sh` fail under the sandbox (`mktemp` writes in `/var/folders`), so tests that call them run unsandboxed, or with `TMPDIR` honoured by the test harness.
- Never edit `.claude/skills/speckit-*`, `.cursor/skills/speckit-*` or `.clinerules/workflows/speckit-*`: they are generated by Spec Kit.

## Phase 11: Convergence

- [X] T063 List the allowed commands (`/speckit-hack-sprint` for the spec owner, `/speckit-hack-status`, `/speckit-implement`, `/speckit-converge`, `/speckit-hack-demo`, `/speckit-hack-graduate`) in the hackathon notice written by `notice_text()` in `scripts/hack.sh`, and assert it in `tests/hack/test_status_notices.sh` per US4/AC1 (partial)
- [X] T064 Document the `verify [--full]` subcommand and the `check --event-repo <name> --push-note` flag in `specs/001-hackathon-mode/contracts/hack-cli.md` per plan: contracts/hack-cli.md (unrequested)
