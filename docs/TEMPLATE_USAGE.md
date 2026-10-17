# Template Usage Guide

Detailed companion to the [README](../README.md). Covers the first feature end to end,
multi-agent setup, customization, and troubleshooting.

---

## 1. Prerequisites

| Tool           | Why                                  | Required |
| -------------- | ------------------------------------ | -------- |
| Git            | Spec Kit creates a branch per feature| yes      |
| Python 3.11+   | Runtime for `specify-cli` (via `uv`) | yes      |
| `uv`           | Installs/updates `specify-cli`       | installed by setup |
| `pre-commit`   | Runs Betterleaks on every commit     | installed by setup |
| Node 18+       | Caveman installer                    | only with `--with-caveman` |
| An agent       | Claude Code, Cursor, Cline, Copilot… | yes      |

`./scripts/setup.sh` installs `uv`, `specify-cli`, RTK and `pre-commit` itself (Caveman
only with `--with-caveman`). Versions are pinned at the top of the script. It never
installs Git, Python, or Node — install those the way your OS expects.

---

## 2. Creating a new project

### From GitHub (template repo)

```bash
gh repo create my-project --template mpefaur/sdd-vibecoding-template --private --clone
cd my-project
./scripts/setup.sh
```

### From a clone (no GitHub)

```bash
git clone https://github.com/mpefaur/sdd-vibecoding-template my-project
cd my-project
rm -rf .git && git init -b main       # start a fresh history
./scripts/setup.sh
```

### What setup does

| Step | Action                         | Idempotency guard                        |
| ---- | ------------------------------ | ---------------------------------------- |
| 1    | Install `uv`                   | skipped if `uv` on PATH                  |
| 2    | Install pinned `specify-cli`   | `uv tool install --force` is safe to repeat |
| 3    | `specify init`                 | **skipped** if `.specify/memory/constitution.md` exists — your constitution is never overwritten |
| 4    | Install RTK                    | skipped if `rtk` on PATH                 |
| 5    | `rtk init` for detected agent  | `--auto-patch` re-applies harmlessly     |
| 6    | Install `pre-commit` + hooks   | `pre-commit install` is idempotent       |
| 7    | Caveman (opt-in)               | skipped unless `--with-caveman`          |
| 8    | Verify every artifact          | read-only                                |
| 9    | Print summary + next steps     | —                                        |

Flags: `--skip-rtk`, `--skip-speckit`, `--with-caveman`, `--agent <name>` (same names on
`setup.ps1`, as `-SkipRtk`, `-SkipSpeckit`, `-WithCaveman`, `-Agent`).

If a step fails the script keeps going and reports it at the end — a missing RTK
degrades cost, not correctness. A missing `pre-commit` removes the local secret scan;
CI still runs it.

---

## 3. Adopt the template (your first prompt)

A fresh clone is deliberately unconfigured: `AGENTS.md` §1 is placeholders and the
verification gate is a no-op. `AGENTS.md` §0 tells every agent to fix that before doing
anything else, so you do not have to remember it.

### The agentic path

```
/kickoff a REST API that issues and reconciles customer invoices
```

The `kickoff` skill proposes a concrete configuration and waits:

```
Propongo:
  Name:    invoice-api
  Purpose: REST API that issues and reconciles customer invoices.
  Stack:   Python 3.12 · FastAPI · PostgreSQL · pytest · ruff
  Run:     uv run fastapi dev
  Test:    uv run pytest -q
  Lint:    uv run ruff check .
  Build:   docker build .

¿OK, o cambio algo?
```

On your OK it writes `AGENTS.md` §1, deletes §0 and the placeholder note, sets
`LINT_CMD`/`TEST_CMD`/`BUILD_CMD` in `scripts/verify.sh`, adds the stack's toolchain to
the CI `verify` job, runs `pre-commit install --install-hooks`, moves this template's
README to `docs/TEMPLATE_README.md` and writes a new one for your project, checks whether
`origin` still points at the template, then continues into `/speckit-constitution` and
`/speckit-specify` with your description.

**It writes configuration and docs only.** No `npm init`, no `src/`, no framework
scaffolding — `AGENTS.md` §2 forbids code before `tasks.md`, and the skill is bound by it
like anything else. Your stack gets installed during `/speckit-implement`.

### The manual path

Not on Claude Code, or you'd rather do it yourself. Same seven steps:

1. Fill `AGENTS.md` §1 with real values:
   ```markdown
   - **Name:** invoice-api
   - **Purpose:** REST API that issues and reconciles customer invoices.
   - **Stack:** Python 3.12, FastAPI, PostgreSQL, pytest
   - **Run:** `uv run fastapi dev` · **Test:** `uv run pytest -q` · **Lint:** `uv run ruff check .` · **Build:** `docker build .`
   ```
2. Delete `AGENTS.md` §0 and the `> Replace the <PROJECT> placeholders…` note.
3. Set `LINT_CMD` / `TEST_CMD` / `BUILD_CMD` in `scripts/verify.sh` to the same
   Lint, Test and Build commands (see §9).
4. Add the toolchain setup (e.g. `actions/setup-node`, `astral-sh/setup-uv`, pinned by
   commit SHA) to the `verify` job in `.github/workflows/ci.yml`.
5. `pre-commit install --install-hooks`.
6. Rewrite `README.md` for your project.
7. `git remote -v` — a plain `git clone` leaves `origin` on the template repo. Fix it with
   `git remote set-url origin <your-repo>` before your first push.

Those four commands in §1 are what every agent uses to prove work is done, so they must be
real and runnable. Everything else in `AGENTS.md` works unchanged.

### Then: the constitution

`/speckit-constitution` adapts
[`.specify/memory/constitution.md`](../.specify/memory/constitution.md) (`/kickoff` calls
it for you). The shipped version is deliberately light (5 principles + quality gates); add
only principles you'd actually enforce in review — a constitution nobody follows is worse
than none.

---

## 4. Your first feature, end to end

```
/speckit-specify  Users authenticate with email and password. Sessions last 24h and
                  can be revoked. Failed logins are rate-limited per account.
```

Creates branch `001-user-auth`, directory `specs/001-user-auth/`, and `spec.md` with
requirements, user stories, and `[NEEDS CLARIFICATION]` markers where you were vague.

```
/speckit-clarify
```

Asks focused questions (token lifetime? lockout policy? password rules?) and writes the
answers back into `spec.md`. **Run this whenever markers remain** — an unresolved marker
becomes a wrong assumption in the plan.

```
/speckit-plan  Use FastAPI + PostgreSQL, argon2 for hashing, JWT access tokens with a
               server-side revocation list. Prefer stdlib over new dependencies.
```

Produces `plan.md`, `research.md`, `data-model.md`, and contracts. Technology choices live
**here**, never in `spec.md`.

```
/speckit-tasks
```

Produces `tasks.md`: ordered, dependency-aware, each mapped to a requirement.

```
/speckit-analyze
```

Read-only consistency report: requirements without tasks, tasks without requirements,
constitution violations, ambiguity that survived clarification. Fix what it finds before
spending implementation tokens.

```
/speckit-implement
/speckit-converge
```

Implement executes the tasks, writes the tests, runs them. Converge then compares the
code against spec, plan and tasks and appends whatever is still unbuilt to `tasks.md`.
Repeat the pair until converge reports **Converged**. Review the diff like any PR — the
constitution's Quality Gates section is the checklist.

Optional along the way:

- `/speckit-checklist` — quality checklists validating requirement completeness/clarity.
- `/speckit-github-taskstoissues` — push `tasks.md` into GitHub Issues (the core
  `/speckit-taskstoissues` is deprecated upstream).

### Fixing a bug

Bugs don't need a feature spec — they need a confirmed cause and a verified fix:

```
/speckit-bug-assess "Submitting an empty password crashes the login form." slug=login-crash
/speckit-bug-fix slug=login-crash
/speckit-bug-test slug=login-crash
```

Reports land in `.specify/bugs/login-crash/`. The final verdict is `verified`, `partial`
or `failed`; missing verification is not a fix.

### Adopting an existing codebase

```bash
cd existing-project
# copy AGENTS.md, CLAUDE.md, .cursor/, .clinerules/, scripts/ from this template
./scripts/setup.sh
```

Then `/speckit-constitution` → `/speckit-converge`. Converge assesses what exists against
your artifacts and appends the remaining work as tasks, instead of pretending the codebase
is greenfield.

---

## 5. Multi-agent setup

Spec Kit is installed here for three integrations. They share `.specify/` and coexist:

| Agent           | Files                                    | How you invoke Spec Kit  |
| --------------- | ---------------------------------------- | ------------------------ |
| **Claude Code** | `.claude/skills/`                        | `/speckit-plan`          |
| **Cursor**      | `.cursor/skills/`, `.cursor/rules/`      | `speckit-plan` skill     |
| **Cline**       | `.clinerules/workflows/`, `.clinerules/00-agents.md` | `/speckit-plan.md`  |
| **Copilot**     | `.github/copilot-instructions.md` → `AGENTS.md`         | ambient; add prompts with `specify integration install copilot` |
| **Others**      | `AGENTS.md` (read natively by Codex, Gemini, Amp, Zed…) | add with `specify integration install <key>` |

Add another agent at any time:

```bash
specify integration list                 # see all keys and multi-install safety
specify integration install copilot      # e.g. GitHub Copilot → .github/prompts/
specify self upgrade                     # upgrade the CLI
specify integration upgrade claude       # refresh an agent's files; keeps your edits
specify extension add bug                # extensions install into the active integration
```

The precedence rule is simple: **`AGENTS.md` is canonical**; agent-specific files add
detail and never contradict it. When you change a rule, change it in `AGENTS.md` first.

The `bug` and `github` extensions are installed for Claude Code only (the active
integration). Cursor and Cline get the core skills/workflows; the Claude skill files in
`.claude/skills/speckit-bug-*` are plain Markdown any agent can follow.

---

## 6. Token optimization in practice

### RTK

Verify and inspect:

```bash
rtk init --show     # confirm the agent integration is patched in
rtk gain            # tokens and cost saved so far
rtk discover        # commands you're still running the expensive way
rtk session         # adoption metrics
```

Everyday swaps (all produce the same information, compacted):

```bash
rtk ls                 # instead of ls -R / tree
rtk read src/api.py    # instead of cat
rtk grep "TODO"        # instead of grep -r
rtk find "*.test.ts"   # instead of find
rtk git status         # instead of git status
rtk git diff           # instead of git diff
rtk test               # instead of npm test / pytest / cargo test
rtk lint               # instead of eslint / ruff
rtk err <command>      # collapse a noisy stack trace
```

Re-run `rtk init` after switching agents so the new agent gets the same instructions.

### Caveman (opt-in)

Not installed by default since Caveman 3.x. Its maintainer's own evals on current Claude
models: `/caveman` cuts ~3% more output than a plain "Answer concisely." (`/ultracave`
~35%), while the rules add ~1k input tokens per call; the CLI and its hooks also send
usage telemetry by default. If you want it anyway:

```bash
./scripts/setup.sh --with-caveman      # pinned version, installed with DO_NOT_TRACK=1
caveman telemetry off                  # or export DO_NOT_TRACK=1 in your profile
```

### The compounding effect

RTK cuts what goes *in*, concise prose keeps what comes *out* small, and the Karpathy
principles cut how much work happens at all. Spec Kit underpins all three: an agent that re-reads
`spec.md` and `tasks.md` doesn't need to re-read a 200-message conversation.

---

## 7. Customizing the agent files

**Order of edits**

1. `AGENTS.md` — anything that applies to every agent (stack, commands, conventions).
2. `.specify/memory/constitution.md` — durable project principles and quality gates.
3. `CLAUDE.md` / `.cursor/rules/` / `.clinerules/` — only genuinely agent-specific detail.

**Rules that work**

- Imperative and checkable: "Run `pytest -q` and paste the output before saying done."
- Include the *why* in one clause; agents follow rules they understand.
- Prefer a table or list to a paragraph.
- Delete rules that stopped being true. A stale rule is worse than a missing one.

**Rules that waste tokens**

- Restating general good practice ("write clean code", "be careful").
- Duplicating the same rule in `AGENTS.md` and every agent file.
- Long rationale essays. Move those to `docs/`.

**Budget**: `AGENTS.md` ≤ ~120 lines, `CLAUDE.md` ≤ ~100. These are re-sent on every
request — they're the highest-leverage lines in the repo, in both directions.

---

## 8. Additional skills

The template installs **no** extra skills by design. Every installed skill consumes
context on every request, whether or not it's used.

When a task genuinely needs a specialized capability — a niche framework, a document
format, a domain review style — browse the curated collection at
**<https://github.com/VoltAgent/awesome-agent-skills>** and install only that one.

Checklist before adding a skill:

1. Does an existing skill, or a plain prompt, already cover it?
2. Will it be used more than once?
3. Is it from a source you'd trust with repo access? (Skills can contain instructions —
   read them.)
4. Record it in `AGENTS.md` §9 with one line on why.
5. Remove it when the need passes.

---

## 9. Guardrails

`AGENTS.md` §4 and §6 are rules an agent *can* ignore. These files make the harness
enforce them instead. The verification layers are inert until `scripts/verify.sh` has
commands, so the template stays stack-agnostic.

| File | Event | What it does |
| ---- | ----- | ------------ |
| `.claude/settings.json` | — | `permissions.deny` blocks reads of `.env*`, `*.pem`, `*.key`, `credentials*`, `id_rsa*`, `secrets/**`. `sandbox.enabled` runs every Bash command in an OS sandbox, which merges those denies in — so `cat .env` is refused too, not only the Read tool — and write-protects `.claude/` config and `.git/hooks`. Wires the two hooks below. |
| `.claude/hooks/dangerous-actions-blocker.sh` | `PreToolUse(Bash)` | Refuses root-target `rm -rf`, raw disk writes, fork bombs, force-push to `main`/`master`/`develop` (named, `+refspec`, or the current branch), `npm`/`cargo` publish, and commit-hook bypasses (`--no-verify`, `commit -n`, `SKIP=`, a `core.hooksPath` override). |
| `scripts/verify.sh` | — | The definition of done: lint, tests, and (`--full`) build. Every layer below calls it. |
| `.claude/hooks/verification-gate.sh` | `Stop` | Runs `scripts/verify.sh` before the agent may finish a turn that left changes (including new files). Exit 2 hands it the real output. |
| `.claude/skills/verify/` | before commit | Claude Code runs a skill named `verify` right before committing. It runs `scripts/verify.sh --full`. |
| `.pre-commit-config.yaml` | `git commit` | Betterleaks secret scan, `detect-private-key`, `check-added-large-files`. |
| `.github/workflows/ci.yml` | push / PR | Betterleaks over the full history + `scripts/verify.sh --full`. The only layer every agent — and every human — passes through. |
| `.github/dependabot.yml` | weekly | PRs bumping the pinned actions and pre-commit hooks. |

### Arming verification

Open `scripts/verify.sh` and set the commands to the ones you put in `AGENTS.md` §1:

```bash
LINT_CMD="${LINT_CMD:-uv run ruff check .}"
TEST_CMD="${TEST_CMD:-uv run pytest -q}"
BUILD_CMD="${BUILD_CMD:-docker build .}"
```

All empty → the script prints "no commands configured" and exits 0, which is the shipped
state. The `Stop` gate skips when the working tree is clean (a question-and-answer turn
shouldn't pay for the test suite) and honours `stop_hook_active`, so a failing suite
can't put the agent in a loop. Then add the stack's toolchain to the CI `verify` job.

Prefer not to edit a tracked file? Set them in `.claude/settings.local.json` instead —
copy `.claude/settings.local.json.example`, which is gitignored and also shows how to
allowlist commands or disable an inherited hook on one machine.

### Enabling the commit hooks

```bash
pre-commit install --install-hooks   # once per clone (setup.sh does it)
pre-commit run --all-files           # audit what is already tracked
betterleaks git --redact .           # audit the whole history, as CI does
```

A reviewed false positive goes into `.betterleaksignore` as its fingerprint
(`betterleaks git -f json -r report.json .` prints it) — never disable the rule.

### Notes

- Both hooks need `jq`; without it they exit 0 rather than block. A guard that fails
  open beats one that bricks the session — which is why CI exists.
- The sandbox starts with no network domains allowed: the first command that needs one
  prompts (auto mode decides on its own). Add your package registry to
  `sandbox.network.allowedDomains` to stop the prompts. Manage it all with `/sandbox`.
- Cursor loads `.claude/settings.json` hooks by default ("Third-Party Imports"); the
  hook commands fall back to the working directory when `CLAUDE_PROJECT_DIR` is unset.
  Whether Cursor honours exit 2 on `stop` the same way is unverified — rely on CI.
- Secret *reading* is handled by `permissions.deny`, not by grepping command text — that
  is why the blocker doesn't reject commands containing `token=`. No false positives.
- `curl … | sh` is deliberately allowed: `scripts/setup.sh` installs its own toolchain
  that way.
- Hook `timeout` in `settings.json` is **seconds**, not milliseconds.
- To loosen or drop any of it, edit `.claude/settings.json` — it's your repo.

---

## 10. Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| `specify: command not found` | `uv tool install specify-cli --force` then `export PATH="$HOME/.local/bin:$PATH"` (persist it in your shell profile). |
| `/speckit-*` not offered in Claude Code | Restart the agent so it rescans `.claude/`. Confirm `.claude/skills/speckit-specify/` exists. |
| Cursor ignores the rules | `.cursor/rules/*.mdc` need `alwaysApply: true` in frontmatter (both shipped files have it). Reload the window. |
| Cline ignores the rules | Rules live in `.clinerules/`; confirm `.clinerules/00-agents.md` is present and the workspace root is the repo root. |
| `specify init` refuses to run | Directory isn't empty — that's expected here. Use `specify init . --integration claude --force`; it merges. |
| Re-running setup wiped my constitution | It shouldn't: step 3 is skipped when `.specify/memory/constitution.md` exists. If you ran `specify init --force` manually, recover it with `git checkout .specify/memory/constitution.md`. |
| Spec Kit scripts fail on Windows | The committed `.specify/scripts/` are POSIX (`sh`). Run them from WSL or Git Bash, or regenerate for PowerShell: `specify init . --integration claude --script ps --force` (back up your constitution first). |
| `rtk: command not found` after install | Add `~/.local/bin` and `~/.cargo/bin` to PATH, or install via `brew install rtk`. Agents fall back to raw commands — nothing breaks. |
| Caveman install fails | Needs Node ≥ 18 (`node -v`). On npm 12+ follow the workaround in Caveman's README. |
| `Operation not permitted` from a shell command | The Bash sandbox. Writes outside the repo/temp dir and into `.claude/` or `.git/hooks` are refused by design; Claude retries unsandboxed with a prompt. For a tool that always needs a path, add it to `sandbox.filesystem.allowWrite`. |
| `gh` (or another Go binary) fails with `x509: OSStatus -26276` | macOS sandbox + Go TLS through the sandbox proxy. Let Claude retry unsandboxed, or add the command to `sandbox.excludedCommands` in your user settings. |
| A commit is blocked by Betterleaks | It found a secret: remove it and rotate it. A reviewed false positive goes into `.betterleaksignore` by fingerprint. |
| Agent skips straight to code | Point it at `AGENTS.md` §2 and ask for `/speckit-specify` first. If it happens repeatedly, tighten the rule — don't repeat it every prompt. |
| Agent starts coding on a fresh clone | It skipped `AGENTS.md` §0. Say `/kickoff` (or point it at §0). If it keeps happening, §0 has drifted below the placeholders — it must stay above §1. |
| `/kickoff` says the repo is already adopted | `AGENTS.md` §1 has no `<PLACEHOLDERS>` left. That is the expected end state; re-run only if you want to change the stack. |
| Agent says `BLOCKED by .claude/hooks/dangerous-actions-blocker.sh` | Working as intended — it hit a destructive command. If the pattern is wrong for your project, edit the hook. |
| Every turn runs the test suite | The `Stop` gate is armed and your tree is dirty. Commit, or set `"hooks": {"Stop": []}` in `.claude/settings.local.json`. |
| Agent can't read a file it should | A `permissions.deny` glob in `.claude/settings.json` matched it. Narrow the glob there. |
| Spec Kit files look outdated | `specify self upgrade && specify integration upgrade claude` (repeat for `cursor-agent`, `cline`). Your constitution and specs are preserved; locally edited managed files block the upgrade until you confirm. |

---

## 11. Reference

- Spec Kit — <https://github.com/github/spec-kit>
- RTK — <https://github.com/rtk-ai/rtk>
- Betterleaks — <https://github.com/betterleaks/betterleaks>
- Claude Code sandboxing — <https://code.claude.com/docs/en/sandboxing>
- Caveman (opt-in) — <https://github.com/JuliusBrussee/caveman>
- Karpathy skills — <https://github.com/multica-ai/andrej-karpathy-skills>
- Curated skills — <https://github.com/VoltAgent/awesome-agent-skills>
- Conventional Commits — <https://www.conventionalcommits.org/>
- `AGENTS.md` convention — <https://agents.md>
