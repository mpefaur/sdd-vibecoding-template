# Contract: the `hack` Spec Kit extension

Source: `.specify/hack/extension/`, owned by the template and never touched by Spec Kit.
`scripts/hack.sh on` installs it to `.specify/extensions/hack/` and `graduate` removes it
(research R2). The keys follow Spec Kit 1.1.1's validated schema: `provides.commands`,
`hooks.<lifecycle>` (`command`, `optional`, `prompt`, `description`, and no `condition`, see
R4) and `events.<canonical>` (`command`, `matcher`, `timeout`; see `validate_events`).

```yaml
schema_version: "1.0"

extension:
  id: hack
  name: "Hackathon Mode"
  version: "1.0.0"
  description: "Reduced SDD flow for 24–48h team hackathons: one demo-centered spec, owner-assigned work items, demo-check definition of done"
  author: sdd-vibecoding-template
  license: MIT

requires:
  speckit_version: ">=1.1.1"

provides:
  commands:
    - name: speckit.hack.sprint      # spec + one-page plan + tasks in one pass, then `hack.sh issues`
      file: commands/speckit.hack.sprint.md
    - name: speckit.hack.demo        # demo.md run-sheet, freeze + rehearsal checklist
      file: commands/speckit.hack.demo.md
    - name: speckit.hack.status      # wraps `hack.sh status`; session_start handler
      file: commands/speckit.hack.status.md
    - name: speckit.hack.guard       # wraps `hack.sh guard`; lifecycle-hook and prompt handler
      file: commands/speckit.hack.guard.md
    - name: speckit.hack.graduate    # wraps `hack.sh graduate`
      file: commands/speckit.hack.graduate.md

hooks:                               # mandatory, unconditional (R4); guard on blocked commands, status for pointer sync (G4)
  before_constitution: { command: speckit.hack.guard, optional: false, description: "Hackathon mode: constitution is fixed" }
  before_specify:      { command: speckit.hack.guard, optional: false, description: "Hackathon mode: use /speckit-hack-sprint" }
  before_clarify:      { command: speckit.hack.guard, optional: false, description: "Hackathon mode: assumptions replace clarification" }
  before_plan:         { command: speckit.hack.guard, optional: false, description: "Hackathon mode: use /speckit-hack-sprint" }
  before_tasks:        { command: speckit.hack.guard, optional: false, description: "Hackathon mode: use /speckit-hack-sprint" }
  before_analyze:      { command: speckit.hack.guard, optional: false, description: "Hackathon mode: analysis is skipped" }
  before_checklist:    { command: speckit.hack.guard, optional: false, description: "Hackathon mode: checklists are skipped" }
  before_implement:    { command: speckit.hack.status, optional: false, description: "Hackathon mode: sync the active spec pointer" }
  before_converge:     { command: speckit.hack.status, optional: false, description: "Hackathon mode: sync the active spec pointer" }

events:                              # installed natively: Claude, Cursor (R3)
  session_start:      { command: speckit.hack.status, timeout: 10 }
  user_prompt_submit: { command: speckit.hack.guard,  timeout: 10 }
```

The exact YAML shape of `hooks` (map vs list per lifecycle point) is whatever
`register_hooks` accepts. The spike task confirms it before the files are written.

## Command files

Each `commands/*.md` carries a `scripts:` frontmatter (`sh: scripts/hack.sh <subcommand>`),
which Spec Kit resolves for both the agent command and the event dispatcher. Spec Kit
rewrites that path to `.specify/extensions/hack/scripts/hack.sh` (research "Spike results"),
so the extension ships `scripts/hack.sh` as a shim that execs the repository-root
`scripts/hack.sh`.

| Command | Agent behavior | Script |
|---|---|---|
| `speckit.hack.sprint` | Only `spec_owner`, only while no spec exists or for revisions by the owner. Resolve `hack-spec-template`, `hack-plan-template`, `hack-tasks-template` through the template stack, fill all three in one pass, at most 3 questions and no `[NEEDS CLARIFICATION]` markers, then `hack.sh issues` | `hack.sh issues` |
| `speckit.hack.demo` | FR-037: build `demo.md` from the spec's demo script with the Qodo checklist (research, "Lessons") | — |
| `speckit.hack.status` | Print the script's output verbatim | `hack.sh status` |
| `speckit.hack.guard` | As a lifecycle hook, run the script with no argument and no stdin (it blocks, per R4 "Invocation modes"); if it exits 2, stop and show its redirect; never continue the blocked command | `hack.sh guard` |
| `speckit.hack.graduate` | Ask for the lint and test commands, confirm, run the script, then point to `/speckit-converge` | `hack.sh graduate` |

## Templates (namespaced, so they never shadow core templates in full mode)

| Name | Sections |
|---|---|
| `hack-spec-template` | Problem · Users · **Demo script** (numbered stage steps, each the seed of a demo-check step) · Out of scope · Assumptions |
| `hack-plan-template` | Stack and runtimes · Integration contract (inline, no `contracts/` dir) · Ownership map · Mocks and fakes · Deploy target · Debt we accept |
| `hack-tasks-template` | `H0` deploy a hello world · slices in demo order (work-item format in [data-model.md](../data-model.md)) · `FREEZE` · `REHEARSAL` · how to log debt in `debt.md` (debt-entry format in data-model.md) |
| `hack-constitution` | 4 principles: the demo script is the contract · happy path only · secrets never in the repo · debt is written down, not paid |
