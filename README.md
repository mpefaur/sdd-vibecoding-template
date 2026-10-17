# sdd-vibecoding-template

A clean, stack-agnostic starting point for **any** new project built with an AI coding
agent: [Spec-Driven Development](https://github.com/github/spec-kit) for the workflow,
[RTK](https://github.com/rtk-ai/rtk) for token cost,
[Karpathy's principles](https://github.com/multica-ai/andrej-karpathy-skills) for agent
behavior, and guardrails the harness enforces instead of trusting the agent.

Built for **VS Code + Claude** (Claude Code, Cline, Cursor). No opinion about your
language, framework, or architecture.

---

## What's inside

| Piece                      | What it gives you                                                     |
| -------------------------- | --------------------------------------------------------------------- |
| **GitHub Spec Kit 1.x**    | `/speckit-*` workflow, bug lane, templates, scripts, base constitution |
| **RTK**                    | Shell output at 60–90% fewer tokens (`rtk ls/read/grep/git/test/…`)    |
| **Karpathy principles**    | Think → Simplify → Stay surgical → Verify, wired into every agent file |
| **`AGENTS.md`**            | Canonical cross-agent contract — one source of truth                   |
| **`CLAUDE.md`**            | Claude Code entry point; imports `AGENTS.md`                           |
| **`.cursor/rules/`**       | Cursor rules (Karpathy + SDD workflow), always applied                 |
| **`.clinerules/`**         | Cline rules + Spec Kit workflows                                       |
| **`/kickoff`**             | One command turns the template into a configured project              |
| **`scripts/verify.sh`**    | The definition of done — one script the hook, the `verify` skill and CI share |
| **Guardrails**             | Bash sandbox + secret-read denies, destructive-command blocker, `Stop` gate, Betterleaks |
| **CI + Dependabot**        | Secret scan and verify on every push; pinned versions kept current     |
| **`scripts/setup.*`**      | Idempotent bootstrap for macOS/Linux/WSL and Windows                   |

```
sdd-vibecoding-template/
├── .specify/          Spec Kit: constitution, templates, scripts, workflows
├── .claude/           Claude skills (speckit-*, verify, kickoff),
│                      settings.json (sandbox, denies, hook wiring), hooks/
├── .cursor/           Cursor rules + Spec Kit skills
├── .clinerules/       Cline rules + Spec Kit workflows
├── .github/           CI workflow, dependabot.yml, copilot-instructions.md
├── docs/TEMPLATE_USAGE.md
├── scripts/           verify.sh · setup.sh · setup.ps1
├── AGENTS.md          canonical agent contract
├── CLAUDE.md          Claude Code entry point (imports AGENTS.md)
├── .editorconfig · .env.example · .gitignore · .pre-commit-config.yaml · LICENSE
```

---

## Start a new project

Three commands in your shell, then you're talking to the agent.

```bash
# 1. Get the template (pick one)
gh repo create my-project --template mpefaur/sdd-vibecoding-template --private --clone
#   …or the "Use this template" button on GitHub, then clone your new repo
#   …or: git clone https://github.com/mpefaur/sdd-vibecoding-template my-project \
#          && rm -rf my-project/.git && cd my-project && git init -b main

cd my-project

# 2. Bootstrap the toolchain (idempotent — safe to re-run)
./scripts/setup.sh          # macOS / Linux / WSL
.\scripts\setup.ps1         # Windows PowerShell 5.1+

# 3. Open the agent
claude                      # or Cursor / Cline / VS Code
```

Everything else happens in conversation:

```
/kickoff a web app that logs daily habits and shows streaks
```

`/kickoff` proposes a concrete stack and command set, waits for your OK, then writes
`AGENTS.md` §1, sets the commands in `scripts/verify.sh`, adds the toolchain to CI,
enables the commit hooks, rewrites this README for your project, and hands off to the
flow:

```
/speckit-constitution   Adapt the base constitution to this project
/speckit-specify        Describe the first feature — what & why
/speckit-clarify        Answer the questions that de-risk the spec
/speckit-plan           Choose the stack and the approach — how
/speckit-tasks          Break it into ordered, testable tasks
/speckit-analyze        Check spec ↔ plan ↔ tasks consistency
/speckit-implement      Build it, verified
/speckit-converge       Append what's still unbuilt; repeat implement ⇄ converge
```

> `/kickoff` writes **configuration only** — no `npm init`, no `src/`. Your stack gets
> installed during `/speckit-implement`, from tasks that came from a spec. That is the
> point of the template: nothing exists until something specified it.
>
> Not on Claude Code? `AGENTS.md` §0 lists the same steps for any agent to follow, and
> [docs/TEMPLATE_USAGE.md](docs/TEMPLATE_USAGE.md) §3 has the manual version.

> **Naming note.** Spec Kit installs skills named `speckit-<name>` — `/speckit-plan` in
> Claude Code, the `speckit-plan` skill in Cursor, the `/speckit-plan.md` workflow in
> Cline.

---

## Recommended workflow

```
constitution ──> specify ──> clarify ──> plan ──> tasks ──> analyze ──> implement ⇄ converge
   (once)         what/why    de-risk     how     ordered    consistency   verified, until Converged
```

- **`clarify` before `plan`.** Any `[NEEDS CLARIFICATION]` marker left in the spec turns
  into a wrong assumption in the plan. One round of questions is far cheaper than
  rebuilding a misunderstood feature.
- **`analyze` before `implement`.** It's read-only: it reports requirements with no task,
  tasks with no requirement, and constitution violations — before you spend tokens coding.
- **One feature = one branch = one `specs/<n>-<slug>/` directory.** `/speckit-specify`
  creates all three.
- **`spec.md` says *what and why*; `plan.md` says *how*.** Keep tech choices out of specs.
- **Converge after implement.** `/speckit-converge` compares the code to spec, plan and
  tasks and appends whatever is still unbuilt. It also adopts an existing codebase.
- **Bugs get their own lane.** `/speckit-bug-assess` → `/speckit-bug-fix` →
  `/speckit-bug-test`: a scoped fix of the assessed cause, verified against the
  original symptom — no full spec needed.
- **Scope creep goes back to the spec**, not into the diff.

---

## How this saves tokens

Two independent layers, no overlap:

1. **RTK — input tokens.** Wraps common dev commands and returns the same information in a
   compact form: `rtk ls`, `rtk read`, `rtk grep`, `rtk find`, `rtk git status`,
   `rtk git diff`, `rtk test`, `rtk lint`, `rtk err`. Typically 60–90% smaller than the raw
   output. Check your own numbers:

   ```bash
   rtk gain        # savings report
   rtk discover    # commands you're still running the expensive way
   ```

2. **Karpathy principles — wasted work.** The cheapest token is the one never generated.
   Simplicity First kills speculative code; Surgical Changes keeps diffs small;
   Goal-Driven Execution stops the retry loops that burn whole context windows.

Output prose is kept short by instruction (`AGENTS.md` §5). [Caveman](https://github.com/JuliusBrussee/caveman)
is available as an opt-in (`./scripts/setup.sh --with-caveman`), not a default: its own
evals on current models measure ~3% fewer output tokens than a plain "be concise" for
~1k extra input tokens per call, and its CLI sends telemetry unless `DO_NOT_TRACK=1`.

On top of that, Spec Kit itself is a token strategy: a spec the agent re-reads is far
cheaper than re-deriving intent from a long chat history.

---

## Customizing `AGENTS.md` / `CLAUDE.md`

`AGENTS.md` is the **canonical contract** — every agent reads it. `CLAUDE.md` imports it
with `@AGENTS.md` and adds only Claude-specific detail.

1. **Always edit `AGENTS.md` first.** §1 (project, stack, commands) is mandatory; §9 tracks
   any extra skills you install.
2. **Put shared rules in `AGENTS.md`.** Only genuinely Claude-specific behavior belongs in
   `CLAUDE.md`; Cursor-specific rules go in `.cursor/rules/`, Cline's in `.clinerules/`.
3. **Keep both short.** These files are re-sent on every request — every line is a
   recurring cost. If `AGENTS.md` passes ~120 lines, move the detail into `docs/`.
4. **Write rules as commands, not essays.** "Run `pytest -q` before saying done" beats a
   paragraph about the value of testing.
5. **Project-wide conventions belong in the constitution**, not in agent files.

---

## Useful commands

| Command                                   | What it does                            |
| ----------------------------------------- | --------------------------------------- |
| `./scripts/setup.sh`                      | Bootstrap / repair the toolchain        |
| `./scripts/setup.sh --skip-rtk`           | Spec Kit + commit hooks only            |
| `./scripts/verify.sh --full`              | Lint, tests, build — the definition of done |
| `specify check`                           | Which agents and tools are detected     |
| `specify integration list`                | Installed / available agent integrations|
| `specify integration install <key>`       | Add another agent (e.g. `copilot`)      |
| `specify self upgrade`                    | Upgrade the Spec Kit CLI                |
| `specify integration upgrade <key>`       | Refresh an agent's Spec Kit files (keeps your edits) |
| `rtk gain` · `rtk discover`               | Token savings · missed opportunities    |
| `rtk init --show`                         | Verify the RTK agent integration        |

---

## Additional skills

This template installs **no** extra skills on purpose — every loaded skill costs context
on every request.

When a task genuinely needs a specialized capability, browse the curated collection at
**<https://github.com/VoltAgent/awesome-agent-skills>** and install **only** what that task
requires. Then record it in `AGENTS.md` §9 so the next person (or agent) knows why it's
there. Remove skills you stopped using.

---

## Keeping the template current

A template freezes the day it is cloned, so the moving parts are pinned and visible:

| What | Where it's pinned | How it moves |
| ---- | ----------------- | ------------ |
| GitHub Actions, pre-commit hooks (Betterleaks) | `.github/workflows/ci.yml`, `.pre-commit-config.yaml` | Dependabot PRs, weekly — in this repo and in every project made from it |
| Spec Kit, RTK, Caveman | top of `scripts/setup.sh` / `setup.ps1` | bump by hand, then `specify self upgrade` and `specify integration upgrade claude` (and `cursor-agent`, `cline`) |
| Claude Code, local tools | your machine | `claude update`, `brew upgrade rtk uv`, `uv tool upgrade pre-commit` |

After upgrading, run `/doctor prompt-audit` and `/skill-doctor` in Claude Code to catch
instructions written for older models and skills that only cost context.

Projects already created from the template don't receive these changes automatically;
re-run the same `specify integration upgrade` there, and copy over whichever guardrail
files you want.

---

## Docs

- [docs/TEMPLATE_USAGE.md](docs/TEMPLATE_USAGE.md) — detailed guide: first feature
  walkthrough, multi-agent setup, troubleshooting, adapting the template.
- [AGENTS.md](AGENTS.md) — the contract every agent follows.
- [.specify/memory/constitution.md](.specify/memory/constitution.md) — project principles.

## Author

Created and maintained by [**@mpefaur**](https://github.com/mpefaur).

Contributions are welcome — open an issue or a PR. Please follow the workflow this
template teaches: spec first, [Conventional Commits](https://www.conventionalcommits.org/),
and a verified test run before marking anything done.

## License

MIT — see [LICENSE](LICENSE).
