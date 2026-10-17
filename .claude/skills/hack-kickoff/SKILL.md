---
name: "hack-kickoff"
description: "Adopt this template for a 24–48h team hackathon: one question for the event's stack, confirm, then activate hackathon mode (scripts/hack.sh on) and hand off to /speckit-hack-sprint."
argument-hint: "The event and what the team will build (one or two sentences)"
compatibility: "Run once, on a fresh clone of sdd-vibecoding-template"
user-invocable: true
disable-model-invocation: false
---

# hack-kickoff — adopt the template in hackathon mode

Hackathon mode is a reduced Spec-Driven flow for teams of 2–5 with 24–48 hours: one spec
centered on the demo script, work items assigned by path ownership, and "done" = the demo
check plus the build. A project's mode is chosen **once**; the only exit is
`/speckit-hack-graduate`. All logic lives in `scripts/hack.sh`, and this skill only collects
the inputs and runs it. See `docs/TEMPLATE_USAGE.md` §Hackathon mode.

**You write configuration and documentation only. You do NOT scaffold the project** (no
`package.json`, no `src/`, no framework `init`). The code is built during the hackathon,
from the work items `/speckit-hack-sprint` creates.

---

## Step 0 — Check this repo can still be adopted

```bash
test -f .specify/mode.json && echo "ALREADY IN HACKATHON MODE"
grep -c '<PROJECT_NAME>\|<ONE_SENTENCE>\|<LANGUAGES / FRAMEWORKS>\|<COMMAND>' AGENTS.md
```

- `ALREADY IN HACKATHON MODE` → say so, run `scripts/hack.sh status`, and stop.
- **0 placeholder matches** → the project is already adopted (full mode or graduated). Say
  that a project's mode is chosen once, and stop.
- Otherwise, proceed. If `$ARGUMENTS` is empty, ask exactly one question —
  *"¿Qué evento es y qué van a construir?"* — and wait.

## Step 1 — One question, then propose

Ask **in a single message**:

1. **The stack the event imposes** (many hackathons fix it). If it fixes none, propose the
   boring default for the idea.
2. Event name and **end time** (with timezone).
3. Team: each member's **GitHub handle** and the **paths** they own, for example
   `ana=api/**`, `luis=web/**`. Paths must not overlap.
4. Who is the **spec owner** (writes the one spec; often the team lead).
5. **Does the event provide the code repository?** If yes, this is the *coordinating
   variant*. For each event repository ask: a short name, the local clone path relative to
   this project, its URL, and the branch submissions must target. Verify the branch with
   `git -C <path> remote show origin`: a fork's default is often not `main` (it was `trunk`
   at the Qodo hackathon). Owner paths then take a `<repo-name>:` prefix (`be:api/**`).
6. Runtime versions the event requires (for example Node 20.9+). Runtime mismatches break
   builds on stage.

Then propose a concrete block and **stop until the user confirms**:

```
Propongo:
  Event:    <name> · ends <ISO-8601 with offset>
  Stack:    <stack> · runtimes <name=version …>
  Run:      <command>
  Build:    <command | none>
  Smoke:    <command that runs the demo script's happy path | manual>
  Owners:   ana=api/** · luis=web/**   (spec owner: ana)
  Variant:  standard | coordinating (be=../be,<url>,trunk …)
  Checks:   ¿hago obligatorios `secrets` y `verify` antes de mergear a la rama por defecto? (sí/no)

¿OK, o cambio algo?
```

- **Smoke** is the automated demo check. It starts empty-but-passing and grows one step per
  slice: for a web app, a Playwright script; for an API, a curl or httpx script; for a CLI, a
  shell script. Say `manual` only when the demo cannot be automated (mobile, hardware); the
  checks will then report it as MANUAL, never as passed.
- Run/Build/Smoke must be commands that will really exist once the stack is installed.

## Step 2 — Activate

```bash
scripts/hack.sh on --event "<name>" --ends-at "<iso>" --stack "<stack>" \
  --run "<cmd>" --build "<cmd|none>" --smoke "<cmd|manual>" --spec-owner <handle> \
  --owner "<handle>=<glob>[,<glob>]" … [--runtime <name>=<version>] … \
  [--variant coordinating --event-repo "<name>=<path>,<url>,<target-branch>" …] \
  [--require-check]
```

Pass `--require-check` **only** if the user explicitly answered yes to the Checks line. It
adds the `secrets` and `verify` contexts to the default branch's protection (FR-022); in the
coordinating variant, on this coordinating project only. If `gh` is missing or GitHub
refuses, the script prints the manual steps instead of failing.

It refuses a dirty tree; commit or stash first. It needs `specify` (run
`./scripts/setup.sh`). If it fails, it rolls everything back and names the failed step;
report that verbatim.

Expect permission prompts: it writes `.claude/settings.json` (native hooks) and
`.claude/skills/` (the `/speckit-hack-*` commands).

## Step 3 — Arm the stack (as /kickoff Step 3)

- `.github/workflows/ci.yml` `verify` job: add the stack's toolchain setup before `Verify`,
  pinned by full commit SHA with the version in a comment. Look it up with
  `gh api repos/<owner>/<action>/git/ref/tags/<tag>`; never invent one. CI runs the demo
  check, so it needs whatever the smoke command needs (browsers for Playwright, and so on).
- `.claude/settings.json`: add the package registry to `sandbox.network.allowedDomains` and
  the package-manager cache to `sandbox.filesystem.allowWrite`.
- Check the tools resolve (`command -v <tool>`), and report any missing ones.

## Step 4 — Report and hand off

Report what changed and anything left (missing tools, the git remote). Do **not** commit;
offer it (`chore: adopt template in hackathon mode`). Then:

- Spec owner: `/speckit-hack-sprint` with the idea.
- Every teammate: pull, run `scripts/hack.sh status`, and work only on their assigned issues.
- Coordinating variant: every teammate runs `scripts/hack.sh hooks` once per machine.
