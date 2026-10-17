# Data Model: Hackathon Mode

## Project mode lifecycle

```text
                 /kickoff                         
  [unadopted] ─────────────────────────────▶ [full]
       │                                         ▲
       │ /hack-kickoff (scripts/hack.sh on)      │ graduate (scripts/hack.sh graduate)
       ▼                                         │
  [hackathon] ───────────────────────────────────┘
```

| State | How it is detected | Allowed transitions |
|---|---|---|
| unadopted | `AGENTS.md` §1 still has `<PLACEHOLDERS>` | → full (`/kickoff`), → hackathon (`/hack-kickoff`) |
| hackathon | `.specify/mode.json` exists with `"mode": "hackathon"` | → full (graduate) only |
| full | §1 adopted and no `.specify/mode.json` | none (`hack.sh on` refuses: §1 adopted) |

A graduated project is simply `full`. No separate "graduated" marker is needed, because
re-entering hackathon mode is already refused on any adopted §1 (FR-027).

## Mode record — `.specify/mode.json` (committed)

Schema: [contracts/mode-record.schema.json](contracts/mode-record.schema.json).

| Field | Type | Required | Rule / source |
|---|---|---|---|
| `mode` | `"hackathon"` | yes | Constant. The file exists only in hackathon mode |
| `variant` | `"standard"` \| `"coordinating"` | yes | Chosen at `/hack-kickoff` (FR-030) |
| `event` | string | yes | Event name |
| `ends_at` | ISO-8601 datetime with offset | yes | Drives the expiry warning only (FR-025). Edited by hand, then validated with `scripts/hack.sh check` |
| `stack` | string | yes | Free text, as imposed by the event (FR-004) |
| `runtime` | object `{name: version}` | no | Pinned runtime versions (Qodo lesson) |
| `commands.run` | string | yes | How to start the app |
| `commands.build` | string \| `null` | yes | `null` means not applicable, and checks say so explicitly |
| `commands.smoke` | string \| `null` | yes | The automated demo check; `null` means manual |
| `demo_check` | `"automated"` \| `"manual"` | yes | `manual` requires `commands.smoke = null` (FR-014) |
| `feature_directory` | string | yes | `specs/001-<event slug>`; the only allowed spec directory (FR-011, FR-012). Event slug: the event name lowercased, every run of characters outside `[a-z0-9]` replaced by one `-`, leading and trailing `-` trimmed, truncated to 40 characters |
| `spec_owner` | string | yes | GitHub handle; the only person allowed to revise the spec |
| `owners[]` | array | yes, ≥1 | Ownership map (below) |
| `event_repos[]` | array | only if coordinating | Event repositories (below) |
| `constitution_sha256` | string | yes | Hash of the hackathon constitution at activation (R5, R7) |
| `activated_at` | ISO-8601 datetime | yes | Written by `hack.sh on` |

### Owner (`owners[]`)

| Field | Type | Rule |
|---|---|---|
| `member` | string | GitHub handle; used as the issue assignee (R10) |
| `paths` | string[] | Glob patterns. In the coordinating variant they are prefixed `<repo-name>:` (FR-031) |

Validation: a path pattern must not appear under two owners. The paths are what the
ownership warning compares against (R11).

### Event repository (`event_repos[]`)

| Field | Type | Rule |
|---|---|---|
| `name` | string | Unique; the prefix used in `owners[].paths` |
| `path` | string | Location of the clone, relative to the coordinating project |
| `url` | string | The team's clone/fork URL |
| `target_branch` | string | The branch submissions must target (FR-035); surfaced on every push |

## Active spec directory — `specs/<NNN>-<slug>/` (allow-list, R5)

| File | Written by | Content |
|---|---|---|
| `spec.md` | `/speckit-hack-sprint` | Problem, users, **demo script**, out of scope, assumptions (`hack-spec-template`) |
| `plan.md` | `/speckit-hack-sprint` | One page: stack, integration contract, ownership map, mocks, deploy target (`hack-plan-template`) |
| `tasks.md` | `/speckit-hack-sprint` | Work items (below), ordered by the demo script (`hack-tasks-template`) |
| `demo.md` | `/speckit-hack-demo` | Stage run-sheet: seed data, step timings, fallback video, freeze and "do not restart" notes |
| `debt.md` | anyone | Debt log entries (below) |

Anything else in that directory, any other directory in `specs/`, and any content under
`.specify/bugs/` fail the check while the mode is active.

## Work item (a line in `tasks.md`, mirrored as an issue)

```text
- [ ] H012 [@member] [slice: <demo step>] [≤90m] <description> — paths: <glob>, <glob>
```

| Part | Rule |
|---|---|
| `H<NNN>` | Unique ID. Issue titles start with it, which is how re-runs avoid duplicates (R10) |
| `[@member]` | Must be an `owners[].member`, and must own every listed path (FR-010) |
| `[slice: …]` | The demo-script step it makes demonstrable. Done = that step is added to the demo check and passes (R8) |
| `[≤Nm]` | Time box in minutes |
| `paths:` | Paths touched. A work item crossing owners is split, never shared |

Checkpoints in `tasks.md`: `H0` (deploy a hello world), one per slice group, `FREEZE`
(no new work after it), and `REHEARSAL`.

## Debt log entry (`debt.md`)

```text
- D007 | <shortcut or unreproduced defect> | where: <path> | why: <hackathon reason> | repay: <what full mode needs>
```

On graduation, every entry becomes a task under "Inherited debt" in `tasks.md`, which is
what `/speckit-converge` consumes (FR-024, FR-026).

## Machine-local state (gitignored)

| Path | Purpose |
|---|---|
| `.specify/feature.json` | Spec Kit's per-checkout pointer. `scripts/hack.sh status` rewrites it from `mode.json`; it runs at session start (Claude, Cursor) and before implement and converge (every integration) (R4, R9) |
| `.specify/hack/local/event-<name>-pre-commit.yaml` | Per-machine, per-event-repository config for its local hooks (R12) |
