# Contract: `scripts/hack.sh`

The single home of all mode logic (FR-017). Agent commands (`/hack-kickoff`,
`/speckit-hack-*`) and the native hooks are thin wrappers around it. Any person can run it,
with any agent or with none.

Runtime: Bash 3.2+ (the macOS default), `git`, `python3` (stdlib only, run as `python3 -I`).
Optional tools are listed per subcommand. The script never prints secret values.

## Global behavior

- Run it from the repository root, or from any subdirectory: it resolves the root with `git rev-parse`.
- Output is plain text. Lines prefixed `hack:` are informational, `hack: WARN` are warnings,
  and `hack: ERROR` are failures. Inside GitHub Actions (`GITHUB_ACTIONS=true`), warnings
  are also emitted as `::warning::` and failures as `::error::`.
- Every refusal names the allowed alternative. Example:
  `hack: ERROR /speckit-clarify is disabled in hackathon mode — use /speckit-hack-sprint`.

| Exit code | Meaning |
|---|---|
| 0 | Success, or nothing to do (for example `check` in full mode) |
| 1 | The check failed or the request was refused (the message says why) |
| 2 | Blocked. Used by `guard` so agent hooks stop the action |
| 3 | Usage or environment error (missing required tool, invalid mode record) |

## Subcommands

### `on` — activate (wrapped by `/hack-kickoff`)

```text
scripts/hack.sh on --event <name> --ends-at <iso8601> --stack <text>
                   --run <cmd> --build <cmd|none> --smoke <cmd|manual>
                   --spec-owner <handle> --owner <handle>=<glob>[,<glob>]...
                   [--runtime <name>=<version>]... [--variant standard|coordinating]
                   [--event-repo <name>=<path>,<url>,<target-branch>]...
                   [--require-check]
```

- **Preconditions**:
  - §1 of AGENTS.md is unadopted.
  - `.specify/mode.json` is absent.
  - `specify` is on PATH. If it is not, exit 3 with: run `./scripts/setup.sh`.
- **Effects**, in order. Any failure rolls back what was already written.
  1. Delete the template-owned `specs/` (R9) and the `template-selftest` job between the
     `# template-only:begin/end` sentinels in `.github/workflows/ci.yml` (R16).
  2. Write AGENTS.md §1 and delete §0, as `/kickoff` does. Name = the event slug: the event
     name lowercased, every run of characters outside `[a-z0-9]` replaced by one `-`,
     leading and trailing `-` trimmed, truncated to 40 characters.
  3. Install the `hack` extension for every installed integration (R2).
  4. Write `.specify/mode.json`. `feature_directory` = `specs/001-<event slug>`; the
     directory is created by `/speckit-hack-sprint`.
  5. Insert notices between `<!-- hackathon-mode:begin -->` / `<!-- hackathon-mode:end -->`
     sentinels in: `AGENTS.md`, `.github/copilot-instructions.md`,
     `.cursor/rules/sdd-workflow.mdc`, `.clinerules/00-agents.md`.
  6. Insert the `hack-check` local hook into `.pre-commit-config.yaml` between
     `# hackathon-mode:begin/end` sentinels.
  7. `--require-check`: after confirmation (the wrapper asks), run `gh api` to require the
     status-check contexts `secrets` and `verify` (the `ci` workflow's job names) on the
     default branch. Never `template-selftest`. Variant `coordinating`: on the coordinating
     project only.
- **Output**: a summary, plus the next step (`/speckit-hack-sprint`, and
  `scripts/hack.sh hooks` for each teammate in the coordinating variant).
- **Refusals** (exit 1): §1 adopted (full or graduated project); mode already active.

### `status` — show the mode (wrapped by `/speckit-hack-status`; used by the `session_start` event)

- **Full mode**: prints `hack: full mode` and exits 0.
- **Hackathon mode**, in this order: event, ends at (`WARN` once past), variant, stack and
  runtimes, active spec, spec owner, owners and paths, allowed commands, blocked commands,
  definition of done.
  - Coordinating variant: one line per event repo with its target branch, then
    `WARN enforcement on event repositories is local-only and can be bypassed`.

### `guard <command-id>` — permit or refuse a command (lifecycle hooks, `user_prompt_submit` event)

- Input, resolved in this order (research R4, "Invocation modes"):
  1. an argument `<command-id>`: a Spec Kit id (`speckit.clarify`) or a slash or hyphen form
     (`/speckit-clarify`, `speckit-clarify`), evaluated as given;
  2. no argument and a non-terminal stdin (`[ ! -t 0 ]`): the `user_prompt_submit` payload.
     The prompt field is the one the spike T003(a) confirmed; its leading slash command is
     evaluated, and a prompt with none is allowed;
  3. no argument and a terminal or empty stdin: **exit 2** with a generic redirect. This only
     happens as a lifecycle hook, and those are registered on blocked commands only.
  - It never waits on stdin.
- **Blocked in hackathon mode**:
  - `speckit.constitution`, `speckit.specify`, `speckit.clarify`, `speckit.plan`,
    `speckit.tasks`, `speckit.analyze`, `speckit.checklist`.
  - `speckit.bug.assess`, `speckit.bug.fix`, `speckit.bug.test`.
  - `kickoff`.
  - Each exits 2 with its redirect.
- **Always allowed**: everything else, including `speckit.implement`, `speckit.converge`
  and all `speckit.hack.*`.
- **Full mode**: exits 0 for every id. Not reached in practice, because the extension is not
  installed in full mode.

### `check` — the enforcing check (pre-commit `hack-check` hook, `verify.sh` in hackathon mode)

- **Full mode**: exits 0 silently.
- **Hackathon mode**: validates the mode record against
  [mode-record.schema.json](mode-record.schema.json), then the R5 rules:
  1. `specs/` contains only `feature_directory`.
  2. That directory contains only `spec.md`, `plan.md`, `tasks.md`, `demo.md`, `debt.md`.
  3. `.specify/bugs/` holds no content.
  4. The hackathon constitution's sha256 equals `constitution_sha256`.
  - Each violation: one `ERROR` line with the path and what to do. Exit 1 if there is any.
- **Event-repo mode** (`--event-repo <name>`, run from an event repository by its local
  hook; coordinating variant, FR-032/FR-033): skips the R5 rules and instead rejects (exit 1)
  any `--changed` path under `specs/` or `.specify/`, because Spec Kit artifacts belong in the
  coordinating project. The ownership warning uses the `<name>:` owner paths. It always
  prints `hack: WARN local-only check — nothing enforces this on the organizers' side`.
- **Ownership warning** (R11): given `--changed <file>...` (pre-commit passes the staged files;
  CI passes the PR diff), print one `WARN` line per owner when the files span more than one
  owner. It never changes the exit code.
- **Expiry**: print a `WARN` past `ends_at`. It never changes the exit code.

- **Push note** (`--event-repo <name> --push-note`, the event repository's `pre-push` hook):
  print the recorded target branch for `<name>` and the local-only warning; always exit 0.

### `verify [--full]` — the hackathon definition of done (called by `scripts/verify.sh`)

`scripts/verify.sh` delegates here whenever `.specify/mode.json` exists (its
`# hackathon-mode` block), so the Stop hook, the `verify` skill and CI keep one entry point
(FR-015). Steps, each printed as `verify: <label> — $ <command>`, stopping on the first
failure with `verify: <label> FAILED` and exit 1:

1. `check` — `scripts/hack.sh check`.
2. `smoke` — `commands.smoke` when `demo_check` is `automated`. When it is `manual`, prints
   `verify: smoke MANUAL — …` (plus `::warning::` in GitHub Actions) and does not count it as
   passed.
3. With `--full`: `build` — `commands.build`, or `verify: build not applicable` when `null`.

Ends with `verify: OK`. Outside hackathon mode: exit 3.

### `issues` — publish work items (called by `/speckit-hack-sprint`)

- Parses `tasks.md` work items (see [data-model.md](../data-model.md)) and runs
  `gh issue create --title "H<NNN> <description>" --assignee <member> --body <slice, time box, paths, link>`.
- Skips IDs already present in an existing issue title (open or closed).
- `--dry-run` prints the issues without creating them.
- Coordinating variant: creates the issues in the coordinating project.
- Requires `gh` (exit 3 if missing).

### `hooks` — install local checks in event repositories (coordinating variant; each teammate, once per machine)

- Writes one `.specify/hack/local/event-<name>-pre-commit.yaml` per event repository, with
  absolute paths: Betterleaks,
  `detect-private-key`, a local `hack-event-check` hook
  (`<abs>/scripts/hack.sh check --event-repo <name> --changed`), and a pre-push stage that
  prints the target branch and the local-only notice (`check --event-repo <name> --push-note`).
- For each `event_repos[]` clone, runs
  `pre-commit install -c <that file> -t pre-commit -t pre-push`.
- Never writes into an event repository's tracked files.
- Reports clones that are missing, and any existing hook manager (migration mode).
- Requires `pre-commit` (exit 3 if missing). Standard variant: prints "not needed" and exits 0.

### `graduate` — leave hackathon mode (wrapped by `/speckit-hack-graduate`)

```text
scripts/hack.sh graduate --lint <cmd> --test <cmd> [--build <cmd>] [--code-repo <path>]
```

1. Set `LINT_CMD`, `TEST_CMD` and `BUILD_CMD` in `scripts/verify.sh` (`/kickoff` step 3).
2. Append every `debt.md` entry to `tasks.md` under `## Inherited debt` as tasks, then delete
   `debt.md`.
3. Remove the extension, the notices (sentinel blocks), the pre-commit block and
   `.specify/mode.json`.
4. Remove the hackathon tooling a full-mode project never uses (research R16), as `/kickoff`
   does on a full adoption: `.claude/skills/hack-kickoff/`, `.specify/hack/`, `tests/hack/`,
   the `# hackathon-mode` blocks in `scripts/verify.sh` and `.github/workflows/ci.yml`, the
   `<!-- template-only -->` lines in `AGENTS.md`, and finally `scripts/hack.sh` itself. Re-entry
   is therefore impossible by construction (FR-027).
5. Print the next step: `/speckit-converge`.

- **Precondition**: the current branch is the default branch, else exit 1 naming it.
- **Coordinating variant**: without `--code-repo` (a repository the team owns), exit 1
  explaining why. With it, print the full-mode adoption steps for that repository, carrying
  the spec, plan and tasks.
- Work in progress on other branches is reported, never touched.
