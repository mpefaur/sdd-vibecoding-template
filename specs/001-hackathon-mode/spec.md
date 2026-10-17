# Feature Specification: Hackathon Mode

**Feature Branch**: `001-hackathon-mode`

**Created**: 2026-10-17

**Status**: Draft

**Input**: User description: "Modo hackathon para el template: un proyecto adoptado con /hack-kickoff tiene un flujo SDD reducido para equipos de 2 a 5 personas con 24–48 horas, pensado para pruebas de concepto que solo cubren el camino feliz y se presentan en una demo en vivo. El modo se fija una sola vez al adoptar el proyecto, en un archivo commiteado. Solo se sale con graduate, que lleva el proyecto al flujo completo. Mientras el modo está activo: hay una sola spec, centrada en el guion de la demo, y la escribe una persona. Las tareas se reparten como issues con dueños por ruta. 'Terminado' significa que pasan el smoke test del guion y el build. Los comandos del flujo completo y la vía de bugs quedan bloqueados para cualquier agente. Lo que obliga de verdad son la CI y el hook de commit, que detectan los archivos propios del flujo completo. Se aceptan stacks distintos según el evento. El vencimiento solo avisa. Las protecciones de secretos no cambian."

## User Scenarios & Testing *(mandatory)*

Actors:

- **Team lead** — adopts the template for a hackathon and, later, decides whether to graduate it.
- **Spec owner** — the one team member who writes the single hackathon spec (often the team lead).
- **Teammate** — any other team member, using any coding agent or none.
- **Full-mode project owner** — anyone adopting the template for a production project, as today.

### User Story 1 - Activate hackathon mode on a fresh project (Priority: P1)

At the start of a hackathon, the team lead creates a project from the template and adopts
it in hackathon mode, naming the event, its end time, and the stack the event imposes. From
that moment the project is in hackathon mode for every team member, on every machine, and
the mode cannot be switched to the full flow except by graduating.

**Why this priority**: Every other story depends on a project being unambiguously in
hackathon mode. Without a reliable, one-time activation there is nothing to enforce.

**Independent Test**: On a fresh clone, run the hackathon adoption with an event name, end
time and stack; confirm a second, independent clone of the pushed result reports
hackathon mode with the same event, end time and stack.

**Acceptance Scenarios**:

1. **Given** an unadopted template clone, **When** the team lead runs `/hack-kickoff` with
   an event, end time and stack, **Then** the project records hackathon mode in a committed
   record and every team member's clone reports the same mode after pulling.
2. **Given** a project already adopted in full mode, **When** anyone runs `/hack-kickoff`,
   **Then** the adoption is refused with a message explaining that a project's mode is
   chosen once.
3. **Given** a project in hackathon mode, **When** anyone runs the full-mode `/kickoff`,
   **Then** it is refused with a pointer to graduation as the only exit.
4. **Given** an event that imposes a stack the template has never seen, **When** the team
   lead names it, **Then** adoption completes and records the run, build and demo-check
   commands for that stack, without requiring any stack-specific support in the template.

---

### User Story 2 - Produce the single demo-centered spec, plan and work items (Priority: P1)

Within the first hour, the spec owner turns the team's idea into one spec whose core is the
demo script: the exact steps the presenters will perform on stage. In the same pass they
get a one-page plan (including the integration contract between parts of the system and
which team member owns which paths) and a list of time-boxed, vertically sliced work items,
which are published as issues assigned to their owners.

**Why this priority**: The value of the mode is speed from minute zero to parallel work.
This is where the full flow currently spends most of a hackathon's first hours.

**Independent Test**: From an idea of two or three sentences, the spec owner obtains the
spec, the plan and the assigned issues in a single guided pass, with no clarification
round or consistency analysis step required.

**Acceptance Scenarios**:

1. **Given** an active hackathon project and an idea, **When** the spec owner runs
   `/speckit-hack-sprint`, **Then** one spec is produced whose central section is the demo script,
   plus an explicit out-of-scope list and recorded assumptions in place of open questions.
2. **Given** the same pass, **When** it completes, **Then** a one-page plan records the
   integration contract and an ownership map from team member to paths, and work items are
   published as issues, each assigned to the owner of the paths it touches.
3. **Given** a spec already exists for this hackathon, **When** anyone tries to create a
   second spec, **Then** it is refused; the existing spec may be revised only by the spec
   owner.
4. **Given** a scope cut mid-hackathon, **When** the spec owner revises the spec, **Then**
   the cut items move to the out-of-scope list and their issues are closed or relabelled.

---

### User Story 3 - Full-flow and bug-lane steps are blocked for any agent (Priority: P1)

While hackathon mode is active, no team member — whatever agent they use, or none — can
pull the project back into the full flow, deliberately or by habit. Agents that understand
the template's commands are redirected before they start a full-flow step. Regardless of
agent, the shared commit-time check and the continuous-integration check reject any change
that introduces artifacts only the full flow produces.

**Why this priority**: The team lead's explicit concern is a teammate, on an unknown agent,
starting the full flow and making the team slow. Enforcement that depends on one agent is
not enough.

**Independent Test**: In an active hackathon project, attempt each blocked command from at
least two different agents and confirm redirection; then commit a full-flow artifact
without any agent and confirm both the commit-time check and the integration check reject
it with an actionable message.

**Acceptance Scenarios**:

1. **Given** an active hackathon project, **When** an agent with the template's commands
   installed is asked to run a full-flow step (constitution, specify, clarify, plan, tasks,
   analyze, checklist), **Then** it stops and names the hackathon command to use instead.
2. **Given** an active hackathon project, **When** someone types a bug-lane command in an
   agent that supports prompt-time hooks, **Then** it is refused with the redirect; and
   **When** any agent writes bug-lane output, **Then** the checks reject it (bug-lane
   commands have no pre-command hook point, so they are not intercepted when an agent
   invokes them on its own).
3. **Given** an active hackathon project, **When** a change adds a second spec or any
   full-flow-only artifact, **Then** the commit-time check rejects it, and if that check
   was skipped or not installed, the integration check rejects it.
4. **Given** an active hackathon project, **When** a change alters the hackathon
   constitution, **Then** the integration check rejects it.
5. **Given** a change touching paths owned by another team member, **When** it is
   checked, **Then** the check warns and names the owner, but does not reject the change.
6. **Given** a defect found on the demo path, **When** the team handles it, **Then** it is
   fixed directly once the demo check reproduces it; a defect the demo check cannot
   reproduce is recorded as debt rather than fixed.

---

### User Story 4 - Teammates work in parallel against a shared definition of done (Priority: P2)

A teammate who joins on a fresh clone, using any agent, learns from the repository alone
that the project is in hackathon mode, finds the single active spec and their assigned
issues, works only in their paths, and knows a change is done when the demo check and the
build pass.

**Why this priority**: Teams of 2–5 must parallelize from the first hour, and the template
cannot assume which agent each teammate uses.

**Independent Test**: A teammate with no prior context and a different agent than the spec
owner clones the project, locates the spec and their issues, completes one, and merges it
with the demo check and build passing, without asking anyone.

**Acceptance Scenarios**:

1. **Given** a fresh clone of an active hackathon project, **When** a teammate opens it
   with any agent, **Then** the agent's instruction files state the mode, the active spec,
   the allowed commands and the definition of done.
2. **Given** a fresh clone with no local feature pointer, **When** a hackathon command
   looks for the active spec, **Then** it finds it from the committed mode record.
3. **Given** a change, **When** it is checked locally or in integration, **Then** "done"
   means the demo check and the build both pass; no other test suite is required.
4. **Given** a stack whose demo cannot be checked automatically (for example, a mobile or
   hardware demo), **When** the mode is adopted, **Then** the demo check is recorded as a
   manual checklist, and the integration check reports it as manual rather than passed.

---

### User Story 5 - Graduate a hackathon project to the full flow (Priority: P2)

After the hackathon, if the proof of concept is worth continuing, the team lead graduates
it. Graduation removes every trace of hackathon mode, restores the full constitution and
verification, and hands the existing code and the recorded debt to the full flow's
convergence step so it is adopted under the normal production discipline.

**Why this priority**: The template exists for orderly, sustainable production work;
graduation is the bridge that keeps hackathon mode from becoming a dead end or a permanent
shortcut.

**Independent Test**: Graduate a project that went through a simulated hackathon and
confirm it is indistinguishable in process from a full-mode project, with its debt listed
as pending work.

**Acceptance Scenarios**:

1. **Given** an active hackathon project, **When** the team lead runs `/speckit-hack-graduate`, **Then**
   the mode record, the hackathon banners, the hackathon constitution and the blocking are
   removed, and the full constitution and full verification apply.
2. **Given** a graduated project, **When** the full flow's convergence step runs, **Then**
   the recorded hackathon debt and the gaps between code and the full flow's expectations
   become pending tasks.
3. **Given** a graduated project, **When** anyone tries to re-enter hackathon mode,
   **Then** it is refused.

---

### User Story 6 - Hackathon mode with an organizer-provided repository (Priority: P2)

Some events hand the team the code repository — often a fork with its own default branch
and no integration checks the team can configure. The team lead adopts the template as a
separate coordinating project: the mode record, the spec, the plan, the ownership map and
the work items live there, while the code lives in one or more event repositories. The
team gets the same reduced flow, and everyone is told plainly that enforcement on the event
repositories is local-only.

**Why this priority**: It is a common real hackathon shape (the team lead has already run
one this way), but it builds on the standard mode working first.

**Independent Test**: Adopt the coordinating variant against two event repositories the
team cannot configure; confirm the spec and work items live in the coordinating project,
that local commit-time checks reject a secret and a full-flow artifact in each event
repository clone, and that every status view and notice states the reduced enforcement.

**Acceptance Scenarios**:

1. **Given** an unadopted template clone and one or more event repositories, **When** the
   team lead runs `/hack-kickoff` choosing the coordinating variant, **Then** the mode
   record lists each event repository, its local location and the branch submissions must
   target.
2. **Given** the coordinating variant, **When** a teammate commits in an event repository
   clone with the local check installed, **Then** secrets are rejected exactly as in full
   mode, and the check states that nothing enforces it on the organizers' side.
3. **Given** the coordinating variant, **When** anyone views the project status or opens
   an agent session, **Then** the reduced, local-only enforcement on event repositories is
   stated explicitly.
4. **Given** the coordinating variant, **When** work is submitted to an event repository,
   **Then** the recorded target branch is surfaced so a submission is not sent to the
   wrong base (for example, the upstream of a fork).
5. **Given** the coordinating variant, **When** the team lead graduates, **Then** the
   spec, plan and debt log are carried into a full-mode adoption of a code repository the
   team owns; if the team owns none, graduation says so and stops.

---

### User Story 7 - Expiry warning (Priority: P3)

Once the recorded end time has passed, team members are reminded that the hackathon is
over and that the project should be graduated or archived. The reminder never blocks work.

**Why this priority**: A forgotten hackathon project silently operating with relaxed rules
is a risk, but the team lead decided a warning is enough.

**Independent Test**: Set the end time in the past and confirm the status view, the agent
session start (where supported) and the integration check all show the warning while
every check still passes.

**Acceptance Scenarios**:

1. **Given** an active hackathon project past its end time, **When** anyone checks the
   project status or runs the integration check, **Then** a warning names the end time and
   the graduate/archive options, and nothing is rejected because of it.

---

### Edge Cases

- A project in full mode has existing specs and someone runs `/hack-kickoff`: refused.
- Two team members run `/speckit-hack-sprint` at nearly the same time: only one spec survives;
  the second attempt is refused once the first is shared.
- A teammate's machine lacks the commit-time check: the integration check still rejects
  full-flow artifacts.
- A teammate's agent ignores the instruction files entirely: the integration check is the
  authority; instruction files and command redirection are aids, not guarantees.
- The event-imposed stack has no build step: the build part of "done" is recorded as not
  applicable, explicitly, rather than silently passing.
- The hackathon repository is provided by the organizers and the team cannot configure its
  integration checks: handled by the coordinating variant (User Story 6), with enforcement
  on the event repositories reduced to local commit-time checks and stated as such.
- The event repository forbids adding files: the coordinating variant installs its local
  checks without committing anything to the event repository unless the team lead
  confirms.
- The event repository does not allow issues, or the team cannot create them there: work
  items are published as issues in the coordinating project.
- Several event repositories (for example, separate backend and frontend): each is listed
  in the mode record with its own target branch, and ownership paths are qualified by
  repository.
- A secret is committed during the hackathon: rejected exactly as in full mode.
- The end time is wrong or extended: the team lead edits it in the mode record and re-runs
  the check; only the warning changes.
- Graduation is attempted with unmerged work in progress: graduation runs only on the
  default branch (it is refused elsewhere) and reports the open work as pending.

## Requirements *(mandatory)*

### Functional Requirements

**Activation and mode record**

- **FR-001**: The template MUST offer a hackathon adoption (`/hack-kickoff`) alongside the
  existing full-mode adoption, and a project MUST be adopted in exactly one of them.
- **FR-002**: Hackathon adoption MUST record, in a committed file shared by all clones,
  the mode, its variant (standard or coordinating), event name, end time, imposed stack,
  the run/build/demo-check commands, the active spec location and the ownership map.
- **FR-003**: Hackathon adoption MUST be refused on a project already adopted in full mode,
  and full-mode adoption MUST be refused on a project in hackathon mode.
- **FR-004**: Hackathon adoption MUST accept any stack the event imposes, asking for it in
  a single question and deriving the run, build and demo-check commands from it.
- **FR-005**: Hackathon adoption MUST complete with configuration and documentation only,
  without scaffolding application code.
- **FR-006**: The template's own default branch MUST ship hackathon mode inactive; a
  project not adopted in hackathon mode MUST see no extra steps, prompts or checks.

**Single spec and work distribution**

- **FR-007**: A single guided command (`/speckit-hack-sprint`) MUST produce, in one pass, the
  hackathon spec, a one-page plan and the work items.
- **FR-008**: The hackathon spec MUST center on the demo script and MUST contain an
  explicit out-of-scope list and recorded assumptions instead of open clarification items.
- **FR-009**: The one-page plan MUST record the integration contract between system parts
  and the ownership map from team member to paths.
- **FR-010**: Work items MUST be vertical slices ordered by the demo script, each with a
  time box and a demonstrable checkpoint, and MUST be published as issues assigned to the
  owner of the paths they touch.
- **FR-011**: Only one spec MUST exist per hackathon project; attempts to create another
  MUST be refused.
- **FR-012**: Hackathon commands MUST locate the active spec from the committed mode
  record, on any clone, without relying on machine-local state or branch names.

**Definition of done**

- **FR-013**: In hackathon mode, a change MUST count as done when the demo check (an
  end-to-end run of the demo script's happy path) and the build pass; no other test suite
  is required.
- **FR-014**: When the demo cannot be checked automatically, the demo check MUST be a
  recorded manual checklist, and checks MUST report it as manual, never as passed.
- **FR-015**: The local verification and the integration check MUST select hackathon or
  full verification from the mode record, so both modes share one verification entry point.

**Guardrails**

- **FR-016**: While hackathon mode is active, the full-flow commands (constitution,
  specify, clarify, plan, tasks, analyze, checklist) and full-mode adoption MUST be blocked
  and MUST redirect to the hackathon equivalent, for every agent integration the template
  installs. The bug-lane commands MUST be refused with a redirect wherever the agent
  supports prompt-time hooks, and their output MUST be rejected by the checks (FR-018)
  everywhere.
- **FR-017**: All mode logic (activation, status, command guarding, graduation) MUST be
  runnable as plain commands by any agent or person, with agent-specific commands only as
  thin entry points to it.
- **FR-018**: The commit-time check and the integration check MUST reject, in hackathon
  mode, any change that adds a second spec, adds artifacts produced only by the full flow
  or by the bug lane, or alters the hackathon constitution, with a message stating what to do instead.
- **FR-019**: The checks MUST warn, without rejecting, when a change touches paths owned by
  another team member, naming that owner.
- **FR-020**: Activation MUST add a visible hackathon-mode notice to every agent
  instruction file the template ships, and graduation MUST remove it.
- **FR-021**: Where an agent supports session-start or prompt-time hooks, the mode SHOULD
  additionally announce itself at session start and block full-flow commands before they
  run.
- **FR-022**: Activation MUST offer, with the team lead's explicit confirmation, to make
  the integration check required before merging to the default branch of the repository
  the team owns (in the coordinating variant, the coordinating project).
- **FR-023**: Defects on the demo path MUST be fixed directly when the demo check
  reproduces them; defects it cannot reproduce MUST be recorded as debt.

**Debt, expiry and graduation**

- **FR-024**: Shortcuts taken during the hackathon MUST be recordable in a debt log that
  graduation hands to the full flow.
- **FR-025**: After the recorded end time, the status view, the integration check and
  (where supported) the agent session start MUST show a warning; the warning MUST NOT block
  any action.
- **FR-026**: Graduation (`/speckit-hack-graduate`, backed by `scripts/hack.sh graduate`) MUST remove the mode record, notices, hackathon
  constitution and blocking; restore the full constitution and full verification; and
  prepare the project for the full flow's convergence step with the debt log as input.
- **FR-027**: A graduated project MUST NOT re-enter hackathon mode (a graduated project is
  a full-mode project, so this restates FR-003 explicitly for graduation).

**Unchanged protections**

- **FR-028**: Secret protections (read denials, commit-time and history secret scanning)
  and the dangerous-action blocking MUST behave identically in both modes.
- **FR-029**: Commit message conventions MUST remain in force in both modes.

**Demo run-sheet**

- **FR-037**: The mode MUST offer a command (`/speckit-hack-demo`) that turns the spec's
  demo script into a stage run-sheet (`demo.md`) with seed data, per-step timings, a
  fallback recording, a submission freeze time earlier than the official end, runtime
  versions, event repositories' target branches, and a rehearsal checklist.

**Organizer-provided repositories (coordinating variant)**

- **FR-030**: Hackathon adoption MUST offer a coordinating variant in which the template
  project holds the mode record, spec, plan, ownership map and work items, and the code
  lives in one or more event repositories.
- **FR-031**: In the coordinating variant, the mode record MUST list each event
  repository with its local location and the branch submissions must target, and
  ownership paths MUST be qualified by repository.
- **FR-032**: In the coordinating variant, the secret checks and the full-flow-artifact
  checks MUST be installable as local commit-time checks on each event repository clone,
  without committing files to the event repository unless the team lead confirms.
- **FR-033**: In the coordinating variant, the status view, the instruction notices and the
  local checks MUST state that enforcement on event repositories is local-only and can be
  bypassed.
- **FR-034**: In the coordinating variant, work items MUST be published as issues in the
  coordinating project when the event repository cannot host them.
- **FR-035**: In the coordinating variant, the recorded target branch of an event
  repository MUST be surfaced whenever work is submitted there.
- **FR-036**: In the coordinating variant, graduation MUST carry the spec, plan and debt log
  into a full-mode adoption of a code repository the team owns, and MUST stop with an
  explanation if the team owns none.

### Key Entities *(include if feature involves data)*

- **Mode record**: The committed, single source of truth for a project's mode; holds
  event, end time, stack, commands, active spec location and ownership map.
- **Hackathon spec**: The one spec of a hackathon project; its core is the demo script,
  plus out-of-scope list and assumptions.
- **Demo script**: The ordered steps shown on stage; doubles as the definition of the demo
  check.
- **Ownership map**: Team member → paths they own; drives issue assignment and the
  ownership warning.
- **Work item**: A time-boxed vertical slice published as an issue, assigned to one owner.
- **Debt log**: Shortcuts and unreproduced defects recorded during the hackathon, consumed
  on graduation.
- **Hackathon constitution**: The reduced principles that replace the full constitution
  while the mode is active.
- **Event repository**: In the coordinating variant, a code repository provided by the
  organizers; recorded with its local location and target branch.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A team lead goes from a fresh template clone to an active hackathon project
  with the event's stack recorded in under 10 minutes.
- **SC-002**: Within 60 minutes of the hackathon start, the spec, plan and assigned work
  items exist and every teammate can start work.
- **SC-003**: A teammate on a fresh clone, with any agent, finds the active spec and their
  assigned work in under 5 minutes without asking anyone.
- **SC-004**: 100% of changes that add a second spec, a full-flow-only artifact or a
  modified hackathon constitution are rejected before reaching the default branch, whichever
  agent (or none) produced them, when the integration check is required for merging.
- **SC-005**: For every agent integration the template installs, 100% of attempts to run a
  blocked full-flow command in hackathon mode are redirected, and 100% of typed bug-lane
  commands are refused in agents with prompt-time hooks.
- **SC-006**: The verdict for a change in hackathon mode, excluding the project's own build
  and demo-check time, arrives within 3 minutes.
- **SC-007**: Full-mode projects experience zero added steps, prompts or checks compared
  with today.
- **SC-008**: Secret-scanning results on the same test fixtures are identical in both modes.
- **SC-009**: A graduated project passes full verification and contains no hackathon-mode
  record, notice or constitution.
- **SC-010**: A simulated hackathon with three team members on at least two different agents
  delivers a passing demo check with no full-flow artifacts in the default branch.
- **SC-011**: In the coordinating variant, a team lead sets up a project against two event
  repositories in under 15 minutes.
- **SC-012**: In the coordinating variant, 100% of local commits containing a test secret
  or a full-flow artifact are rejected on event repository clones with the local check
  installed, and 100% of status views and notices state that enforcement there is
  local-only.

## Assumptions

- The team hosts the hackathon project (or, in the coordinating variant, the coordinating
  project) on GitHub with issues enabled, and at least one team member can configure
  required checks there. Event repositories make no such guarantee.
- Team size is 2–5 people and the hackathon window is 24–48 hours; larger teams or longer
  events should use the full flow.
- Teammates may use any coding agent or none; the integration check is the only guarantee,
  and command redirection and instruction notices are best-effort aids.
- Not every teammate has the commit-time check installed; the integration check covers them.
- The hackathon constitution replaces the full constitution for the project's lifetime in
  hackathon mode; the template's own constitution is amended to acknowledge this alternate
  mode explicitly, per its governance rules.
- The demo script covers only the happy path; edge cases, error handling and broad test
  coverage are intentionally out of scope and are captured as debt when relevant.
- Hackathon rules about prior work vary by event; the mode ships configuration and process
  only, never application code, so it is usable under strict "no prior code" rules.
- Spec Kit generated files (the standard command definitions) are not edited; hackathon
  behavior is layered through the template's supported extension mechanisms so upgrades
  keep working.
- The end time can be corrected by the team lead at any time; it only affects the warning.
- Artifacts are written in English, matching the rest of the template.
