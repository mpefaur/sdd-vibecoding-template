# Research: Hackathon Mode

Findings from reading the installed Spec Kit 1.1.1 (`specify_cli`), the template's scripts and
hooks, and the team lead's previous hackathon (Qodo "Roast My PR", 2026-08). Each entry:
Decision / Rationale / Alternatives considered.

## R1 — Delivery mechanism

- **Decision**: One Spec Kit extension, `hack`, providing commands, lifecycle hooks, native
  agent events and its own namespaced templates. Its source lives in a template-owned
  directory (`.specify/hack/extension/`) and is installed only on activation.
- **Rationale**: An extension is the only Spec Kit primitive that carries all four pieces
  and survives Spec Kit upgrades. The `.claude/skills/speckit-*` files are generated, so
  editing them is not an option.
- **Alternatives considered**:
  - *Preset*: its templates enter the resolution stack under the core names, so they would
    shadow `spec-template` and the other core templates in full mode too. Namespaced
    templates inside the extension (`hack-spec-template`, …) avoid that.
  - *Custom workflow*: `/speckit-hack-sprint` is a single command, so a workflow would wrap one step.
  - *Bundle*: there is only one component to bundle.
  - *Long-lived branch*: drifts with every Spec Kit and guardrail change.

## R2 — Activation and deactivation

- **Decision**: `scripts/hack.sh on` installs the extension (`specify extension add --dev
  .specify/hack/extension`) for every installed integration (claude, cursor-agent, cline).
  `graduate` removes it (`specify extension remove hack`). The template's default branch
  ships it **not installed**.
- **Rationale**: `.specify/extensions/.registry` shows commands registered per integration
  (`bug` and `github` are registered for `claude` only, which is why Cursor and Cline lack
  the bug lane). Installed-but-disabled would still put `/speckit-hack-*` skills into every
  full-mode session, an ongoing context cost (AGENTS.md §8) that breaks SC-007. The source
  directory lives outside `.specify/extensions/` for two reasons:
  - `collect_extension_events` also scans unregistered directories there, treating them as
    partially-staged installs, so the hack events would leak into full mode on any refresh.
  - `extension remove` deletes the installed directory.
- **Alternatives considered**: `specify extension enable/disable`. It works:
  `command_disable.py` flips the registry and every hook's `enabled` flag, and refreshes the
  native events. But the command files stay on disk.
- **To verify early (spike task)**: how to register an extension's commands for several
  integrations in one project (re-run `add` per active integration, or an equivalent), and
  that `add` and `remove` refresh the native events the same way `enable` and `disable` do.

## R3 — Native agent hooks

- **Decision**: The extension declares `events:` for `session_start` (mode banner, active
  spec, allowed commands, expiry warning) and `user_prompt_submit` (refuse typed full-flow
  or bug-lane commands). Spec Kit installs them natively:
  - Claude: `.claude/settings.json`, as `SessionStart` and `UserPromptSubmit`.
  - Cursor: `.cursor/hooks.json`, as `sessionStart` and `beforeSubmitPrompt`.
  - Cline: has no native events.
- **Rationale**: One declaration produces hooks for every agent that supports them, through
  Spec Kit's own dispatcher (`.specify/events.py`, Python stdlib). The dispatcher passes the
  handler's exit code through, so a non-zero exit blocks the prompt.
- **Alternatives considered**:
  - *Hand-written Claude hooks*: Claude-only, and the template already has two to maintain.
  - *`pre_tool_use` on the `Skill` tool*: redundant with R4 for agent-invoked commands, and
    matcher semantics differ per agent.
- **To verify**: Cursor's `beforeSubmitPrompt` blocking semantics under the dispatcher (exit
  code vs JSON). Codex, Copilot and Gemini get native hooks only if their integration is
  installed; that is not part of v1 (see R14).

## R4 — Blocking agent-invoked full-flow commands

- **Decision**: Mandatory (`optional: false`) lifecycle hooks with **no `condition`** on
  `before_constitution`, `before_specify`, `before_clarify`, `before_plan`, `before_tasks`,
  `before_analyze` and `before_checklist`. They run `speckit.hack.guard`, which stops the
  command and names the hackathon equivalent.
- **Rationale**: The generated commands for Claude, Cursor and Cline all read
  `hooks.before_*` from `.specify/extensions.yml`. They skip hooks that carry a `condition`
  ([speckit-implement/SKILL.md:31](../../.claude/skills/speckit-implement/SKILL.md)), so the
  mode check has to live inside the guard command. Implement and converge stay allowed.
- **Bug lane (decided 2026-10-17, analysis G2 → option B)**: The bug-lane commands
  (`speckit.bug.*`) have no hook points, and they are registered for Claude only. They are
  covered by:
  - the prompt-submit refusal (R3);
  - the instruction notices;
  - the artifact guard (R5), which rejects any `.specify/bugs/` content.
  When an agent invokes them on its own, nothing intercepts them at command time. The spec
  (FR-016, SC-005, US3 #2) states this explicitly.
  - *Rejected*: a Claude-only `pre_tool_use` hook with matcher `Skill`. It covers one agent,
    adds a per-tool-call cost, and its matcher semantics differ across agents.
- **Invocation modes of `speckit.hack.guard` (analysis U1)**: The same command is the
  lifecycle-hook handler and the `user_prompt_submit` handler. `scripts/hack.sh guard`
  therefore resolves its input in this order:
  1. an explicit argument: evaluate that command id;
  2. otherwise, a non-terminal stdin (`[ ! -t 0 ]`): read the event payload, extract the
     prompt and evaluate its leading slash command;
  3. otherwise: **block** (exit 2) with a generic redirect. That case only happens when the
     guard runs as a lifecycle hook, and those hooks are registered exclusively on blocked
     commands.
  The guard never blocks on reading stdin.
- **Active-spec pointer for implement and converge (analysis G4)**: Mandatory
  `before_implement` and `before_converge` hooks run `speckit.hack.status`, which rewrites
  `.specify/feature.json` from the mode record. That reaches Cline too, which has no
  session-start event.
- **Alternatives considered**: Editing the generated command files. They are overwritten on
  upgrade.

## R5 — The enforcing check

- **Decision**: `scripts/hack.sh check` is a **state-based** check. In hackathon mode the
  tree is valid only if all of the following hold:
  1. `specs/` contains only the active spec directory.
  2. That directory contains only allow-listed files: `spec.md`, `plan.md`, `tasks.md`,
     `demo.md` and `debt.md`.
  3. `.specify/bugs/` is absent or empty.
  4. The hackathon constitution's hash matches the one recorded in the mode record.
  - The same check runs in pre-commit and CI.
- **Rationale**: A state check needs no diff base, so it behaves the same locally, in CI,
  and on a fresh clone. An allow-list catches any future full-flow artifact without having
  to update a deny-list.
- **Alternatives considered**: A diff-based "added files" check. It needs a base ref and
  `fetch-depth` in CI, and it misses artifacts that arrived through a merge.

## R6 — Mode record format

- **Decision**: JSON at `.specify/mode.json`, read with `python3 -I` stdlib.
- **Rationale**: Spec Kit already requires Python 3 (`common.sh` and the events dispatcher),
  and its own state files are JSON (`feature.json`, `init-options.json`). YAML has no stdlib
  parser. `tomllib` needs Python 3.11, but macOS ships 3.9 with the command-line tools, and
  that may be all a teammate has.
- **Alternatives considered**: YAML with `yq` (an extra dependency); TOML (Python 3.11+).

## R7 — Hackathon constitution

- **Decision**: It is a separate file, installed with the extension and read by the hack
  commands. The full constitution file is never touched. The template constitution gets a
  MINOR amendment (1.1.0 → 1.2.0): while `.specify/mode.json` exists, the project is
  governed by the hackathon constitution until graduation.
- **Rationale**: Nothing has to be swapped or restored, so graduation only deletes files.
  The constitution's own governance rules require an explicit amendment for an alternate
  mode.
- **Alternatives considered**: Swapping `.specify/memory/constitution.md` on activation. It
  is fragile on graduation, and full-flow commands would read the wrong file.

## R8 — Definition of done and `verify.sh`

- **Decision**: `scripts/verify.sh` branches on the mode record.

  | Mode | `verify.sh` (Stop hook) | `verify.sh --full` (skill, CI) |
  |---|---|---|
  | full | lint → tests (unchanged) | lint → tests → build (unchanged) |
  | hackathon | check → smoke | check → smoke → build |

  - The demo check **grows one step per slice**: a slice is done when its demo-script step is
    automated and passing. That keeps the check green at every checkpoint instead of failing
    until the end.
  - A manual demo check prints `MANUAL` (a `::warning::` in GitHub Actions) and is never
    reported as passed.
  - The expiry warning is printed the same way and never changes the exit code.
- **Rationale**: One entry point for both modes (FR-015). The Stop hook, the `verify` skill
  and CI all stay unchanged.
- **Alternatives considered**: A separate `verify-hack.sh`, which would mean a second entry
  point to wire into three callers.

## R9 — Single spec and locating it

- **Decision**:
  - `mode.json.feature_directory` is authoritative. Hack commands write
    `.specify/feature.json` from it, because that file is gitignored per-checkout state.
  - The check rejects any other spec directory.
  - Both kickoffs delete the template's own `specs/` on adoption: a fresh clone has no
    project specs yet, so anything there belongs to the template.
- **Rationale**: A teammate's clone has no `feature.json`, and story branches do not follow
  `<n>-<slug>`. Without the deletion, this very feature (`specs/001-hackathon-mode/`) would
  be inherited by every new project.
- **Alternatives considered**: Keeping template specs off `main`, which breaks the template's
  own SDD history.

## R10 — Publishing work items

- **Decision**: `scripts/hack.sh issues` creates one issue per work item with
  `gh issue create --assignee <handle>`, using the GitHub handles in the ownership map.
  Re-runs skip work items whose ID already appears in an issue title.
- **Rationale**: `/speckit-github-taskstoissues` depends on the GitHub MCP server and has
  no assignee support. `gh` is scriptable and works with any agent.
- **Alternatives considered**: Extending the github extension, which is generated upstream.

## R11 — Ownership warning

- **Decision**: Warn, without failing, when a change touches paths of **more than one
  owner**, naming each owner and path. Pre-commit uses the staged files; CI uses the PR's
  changed files.
- **Rationale**: Mapping git identities to team members is fragile across machines. A change
  that crosses owners is the conflict signal that matters.
- **Alternatives considered**: Matching the git author email to a member's email.

## R12 — Coordinating variant (organizer-provided repositories)

- **Decision**:
  - `mode.json.variant = "coordinating"`, with an `event_repos[]` list (name, path relative
    to the coordinating project, target branch).
  - Each teammate runs `scripts/hack.sh hooks` once per machine. It writes a gitignored
    `.specify/hack/local/event-pre-commit.yaml` with absolute paths, and runs
    `pre-commit install -c <that file> -t pre-commit -t pre-push` in each event clone.
  - Nothing is committed to the event repository.
  - The pre-commit hooks: Betterleaks, `detect-private-key`, and a local `hack-event-check`
    that runs `<coordinating>/scripts/hack.sh check --event-repo <name> --changed`. It
    rejects staged paths under `specs/` or `.specify/`, because Spec Kit artifacts belong in
    the coordinating project (FR-032; analysis G1 → option A). It warns when the staged
    paths cross owners of that repository, and prints the local-only notice (FR-033).
  - The pre-push hook prints the recorded target branch and a reminder that enforcement is
    local-only.
- **Rationale**: `pre-commit install -c/--config` (4.6.2) embeds an alternate config path, so
  the event repo needs no committed file. In Qodo, a fork's PR defaulted to the upstream
  base, which is why the target branch is printed on push.
- **Known limit**: `.git/hooks/` writes are refused by the Claude Code Bash sandbox, so the
  unsandboxed-retry prompt is expected. An existing hook manager in the event repo (husky,
  etc.) makes pre-commit run in migration mode; `hooks` reports this.

## R13 — Verifying the template's own tooling

- **Decision**: Bash scenario tests in `tests/hack/`, run by `tests/hack/run.sh` against
  throwaway git repos in `$TMPDIR`. A CI step runs them **only while the repo is the
  unadopted template** (AGENTS.md still has `## 0. First run`), so adopted projects never
  run them.
- **Rationale**: Setting `TEST_CMD` in the template's `verify.sh` would leak into every
  adopted project. See Complexity Tracking in [plan.md](plan.md).
- **Alternatives considered**: bats (an extra dependency for about 15 scenarios).

## R14 — Out of scope for v1

- Windows-native PowerShell parity: `verify.sh` is already bash-only. Git Bash or WSL works.
- Native hooks for agents whose integration is not installed (Codex, Copilot, Gemini). Those
  teammates rely on the instruction notices and on the enforcing check.
- A hard expiry block: the team lead decided a warning is enough.

## R15 — Graduation

- **Decision**: `scripts/hack.sh graduate`, wrapped by `/speckit-hack-graduate`, does
  the following:
  1. Asks for the real lint and test commands and sets them in `verify.sh`, as `/kickoff`
     step 3 does.
  2. Moves `debt.md` into the spec's `tasks.md` as an "Inherited debt" section.
  3. Removes the extension, the notices, the pre-commit block and `mode.json`.
  4. Points to `/speckit-converge` as the next step.
  - Re-entry is impossible because §1 is adopted, and `hack.sh on` refuses on an adopted §1.
  - In the coordinating variant it stops unless the team names a code repository it owns,
    and then prints the full-mode adoption steps for it.
- **Rationale**: Converge already adopts existing code into the flow (AGENTS.md §2), so
  graduation does not need its own adoption logic.

## R16 — Template-only tooling removed on adoption (analysis I1)

- **Decision**: Some items exist only so the template can offer and test the mode. On
  adoption they are removed:
  - the `template-selftest` CI job and the hackathon ownership step, each between
    `# template-only:begin` / `# template-only:end` and `# hackathon-mode:begin/end`
    sentinels in `.github/workflows/ci.yml`;
  - on a **full** adoption, also `.claude/skills/hack-kickoff/`, `.specify/hack/`,
    `scripts/hack.sh` and `tests/hack/`.
  `/kickoff` removes them. `scripts/hack.sh on` removes only the `template-selftest` job,
  because a hackathon project still needs the rest until graduation.
- **Rationale**: FR-006 and SC-007 require that full-mode projects see no extra steps,
  prompts or checks. Keeping the `hack-kickoff` skill would be the same context cost R2
  rejected for installed-but-disabled commands.
- **Alternatives considered**: Leaving the job with a step-level skip. It still runs a
  checkout in every adopted project, and shows a skipped step.

## Spike results (2026-10-17, tasks T002–T003)

Run against Spec Kit 1.1.1 in a throwaway clone of this repository.

- **Hook shape (T002b)**: `hooks.<lifecycle>` accepts a mapping or a list
  (`coerce_hook_entries`). `register_hooks` writes each entry to `.specify/extensions.yml`
  with `enabled: true`, `optional`, `priority: 10`, `prompt`, `description` and
  `condition: null`. The map shape in contracts/extension-manifest.md is valid.
- **Script paths are rewritten (new finding)**: `scripts/<x>` in a command's `scripts.sh`
  frontmatter is rewritten to `.specify/extensions/<id>/scripts/<x>`, both in the generated
  skill (`{SCRIPT}`) and for the event dispatcher. **Decision**: the extension ships a
  two-line shim, `scripts/hack.sh`, that execs the repository-root `scripts/hack.sh` (resolved
  with `git rev-parse --show-toplevel`). The repo-root script stays the single home of the
  logic (FR-017).
- **Registration across agents (T002a)**: `specify extension add --dev <dir>` registers
  commands for the **default integration only** (`registered_commands: {claude: [...]}`), but
  writes native events for every events-capable installed integration (Claude
  `.claude/settings.json`, Cursor `.cursor/hooks.json` + `.specify/events.py`; Cline gets
  none). `specify integration use <key>` calls `_register_extensions_for_agent`, which
  registers commands of **all** installed extensions for that agent. There is no public
  per-agent, per-extension command.
  - **Decision**: `hack.sh on` runs `extension add`, then `integration use <key>` for each
    other installed integration, then `integration use <original default>`.
  - **Side effects of `integration use`, and how activation handles them**:
    - It drops the executable bit on `.specify/scripts/bash/*.sh`.
    - It regenerates existing Spec Kit command files, losing template customizations such as
      commit c65a1ed's.
    - It also registers `bug` and `github` for Cursor and Cline.
    - Activation snapshots the tracked tree after `extension add`. After the loop it restores
      (`git checkout -- <path>`) every tracked file the loop changed, except the files that
      legitimately record registrations: `.specify/extensions/.registry`,
      `.specify/integrations/*.manifest.json`, `.specify/integration.json`. The new `bug` and
      `github` files for Cursor and Cline are **kept**, as a documented side effect. They are
      blocked in hackathon mode like any bug-lane command, and graduation leaves them
      (harmless: they make the bug lane available to Cursor and Cline after graduation).
- **Removal (T002c, T002d)**: `specify extension remove <id> --force` removes the generated
  commands for every agent, its `.specify/extensions.yml` hook entries, the native event
  entries, `.specify/events.py` and `.cursor/hooks.json` (when nothing else uses them). It
  leaves an empty `.specify/extensions/.backup/<id>/` directory, which `graduate` deletes.
- **Prompt payload (T003a)**: The dispatcher passes the agent's JSON payload unchanged on
  stdin. Claude `UserPromptSubmit` and Cursor `beforeSubmitPrompt` both carry the text in
  `prompt`.
- **Blocking (T003b)**: The dispatcher returns the handler's exit code. Claude blocks a
  prompt on exit 2 and shows stderr. Cursor's `beforeSubmitPrompt` is installed with the
  `suppress` envelope (no stdout reaches Cursor), so blocking depends on Cursor honoring
  exit code 2. **Not verifiable here; recorded as an open item for manual scenario M2.**
- **Alternate pre-commit config (T003c)**: `pre-commit install -c <path>` stores the path in
  `.git/hooks/*` (`ARGS=(hook-impl --config=<path> …)`). A relative path is stored verbatim; an
  absolute one is stored **relative to the event repository** (seen during US6:
  `--config=../coord/.specify/hack/local/…`). Either way it works while the coordinating
  project and the event clones keep their relative layout; moving either means re-running
  `scripts/hack.sh hooks`. A failing local hook blocks the commit and prints its output. YAML values that
  contain `: ` must be quoted: generate them as JSON strings.
- **Synthetic secrets (T003d)**: `.betterleaksignore` supports fingerprints only; path
  allowlists need a Betterleaks config file. **Decision**: tests generate the synthetic
  secret at run time from concatenated fragments inside the throwaway clone, so the
  repository never contains a secret-shaped string and no ignore entry is needed.

## Lessons carried from the Qodo hackathon (into `/speckit-hack-demo` and the templates)

- An early merge beats a heroic late feature, so the tasks template ends at a freeze
  checkpoint.
- The submission freeze comes before the official end time.
- Restarting an app with an in-memory database before the demo wipes its data, so `demo.md`
  includes seed data and a "do not restart" note.
- Runtime version mismatches broke the build (Node 18), so `hack-kickoff` records runtime
  versions.
- In repos with several clones, always `cd` to an absolute path, so the multi-repo commands
  use absolute paths.
- A fork's PR defaulted to the upstream base, so the target branch is surfaced (R12).
