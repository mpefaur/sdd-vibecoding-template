---
description: "Hackathon mode: write the one demo-centered spec, plan and tasks in one pass, then publish assigned issues"
scripts:
  sh: scripts/hack.sh issues
---

## User Input

```text
$ARGUMENTS
```

The input is the team's idea (or, on a re-run, the change the spec owner wants). This
project is in **hackathon mode**: one spec, written in one pass, centered on the demo script.
The hackathon constitution (`.specify/extensions/hack/templates/hack-constitution.md`)
governs; read it first.

## 1. Preconditions

1. Read `.specify/mode.json`. If it does not exist, stop: this command only runs in
   hackathon mode.
2. Write `.specify/feature.json` as `{"feature_directory": "<feature_directory>"}` from the
   mode record, so other Spec Kit commands find the active spec on this clone.
3. **Only the spec owner** (`spec_owner`) runs this command. If `gh` is available, compare
   `gh api user -q .login` with it; otherwise ask the user whether they are `@<spec_owner>`.
   If not, stop and tell them to ask the spec owner.
4. If `<feature_directory>/spec.md` already exists, this is a **revision**, not a second
   spec. Never create another directory under `specs/`.

## 2. Write the three files in one pass

Resolve each template through Spec Kit's template stack and copy it into the feature
directory:

```bash
mkdir -p <feature_directory>
.specify/scripts/bash/resolve-template.sh hack-spec-template  > <feature_directory>/spec.md
.specify/scripts/bash/resolve-template.sh hack-plan-template  > <feature_directory>/plan.md
.specify/scripts/bash/resolve-template.sh hack-tasks-template > <feature_directory>/tasks.md
```

Then fill all three from the input and the mode record:

- **Questions**: at most 3, asked together, only when a choice changes what the audience
  sees on stage. Everything else: decide and record it under Assumptions. Never write
  `[NEEDS CLARIFICATION]`.
- **spec.md**: the demo script is the core. Write numbered stage steps, each with an
  observable result that fits the event's demo slot. Make the out-of-scope list explicit.
- **plan.md**: one page. The integration contract goes inline, so parts owned by different
  people can be built against a mock from the first hour. Copy the ownership map from
  `owners` in the mode record. Name the mocks, the deploy target and the debt accepted
  up front.
- **tasks.md**: `H0` (deploy a hello world) first, then slices in demo order, then
  `FREEZE` (set it well before `ends_at`) and `REHEARSAL`. Every work item uses the exact
  format in the template, `- [ ] H012 [@member] [slice: …] [≤90m] … — paths: …`, has one
  owner who owns every listed path, and is at most about 2 hours. Split anything that
  crosses owners.

Do not create any other file in the feature directory. Only `spec.md`, `plan.md`,
`tasks.md`, `demo.md` and `debt.md` are allowed, and the check rejects anything else.

## 3. Revisions and scope cuts

When re-run on an existing spec, edit the three files in place. A **scope cut** moves the
cut demo steps to "Out of scope" and removes their work items from `tasks.md`. Then close
the matching issues: `gh issue close <number> --comment "Cut from the demo (scope cut)"`.
Never reuse a work-item ID.

## 4. Check and publish

1. Run `scripts/hack.sh check` and fix anything it reports.
2. Run `{SCRIPT}` (publishes one issue per new work item, assigned to its owner, skipping IDs
   that already have an issue). To preview first, run `scripts/hack.sh issues --dry-run`.
3. Report the issue links, and tell the team: pull, run `scripts/hack.sh status`, and work
   only on your assigned issues. A work item is done when its demo step is added to the demo
   check and `scripts/verify.sh --full` passes.

Do not commit unless asked. Suggest `docs(hack): add hackathon spec, plan and tasks`.
