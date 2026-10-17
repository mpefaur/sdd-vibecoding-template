# AGENTS.md — Canonical Agent Contract

Single source of truth for **every** coding agent in this repo (Claude Code, Cursor,
Cline, Copilot, Codex, Gemini…). Agent-specific files (`CLAUDE.md`,
`.cursor/rules/`, `.clinerules/`) import or point at this file — they never contradict it.

> Replace the `<PROJECT>` placeholders below when you start a real project — §0 does it.
> Keep this file short. If it grows past ~120 lines, move detail into `docs/`
> (§0 is temporary scaffolding and is deleted on adoption; it doesn't count).

## 0. First run — adopt this template

**§1 still shows `<PLACEHOLDERS>` → this repo is an unadopted template.** Adopt it before
anything else; a spec written against placeholder commands cannot be verified.

Claude Code: **`/kickoff <what you want to build>`**. Any other agent, same steps by hand:
propose and confirm name/purpose/stack/commands → write §1 → delete this section and the
note above → set `LINT_CMD`/`TEST_CMD`/`BUILD_CMD` in `scripts/verify.sh` → add the
toolchain to `.github/workflows/ci.yml` → `pre-commit install --install-hooks` →
`/speckit-constitution` → `/speckit-specify`.

Config and docs only — **no scaffolding**. §2 forbids code before `tasks.md`, `npm init`
included. Detail: `docs/TEMPLATE_USAGE.md` §3.

## 1. Project

- **Name:** `<PROJECT_NAME>`
- **Purpose:** `<ONE_SENTENCE>`
- **Stack:** `<LANGUAGES / FRAMEWORKS>` — this template is stack-agnostic; fill it in.
- **Run:** `<COMMAND>` · **Test:** `<COMMAND>` · **Lint:** `<COMMAND>` · **Build:** `<COMMAND>`

## 2. Workflow — Spec-Driven Development (non-negotiable)

Never jump straight to code. Follow [GitHub Spec Kit](https://github.com/github/spec-kit):

```
constitution → specify → [clarify] → plan → tasks → [analyze] → implement ⇄ converge
```

| Step                 | Skill (Claude Code / Cursor)   | Output                              |
| -------------------- | ------------------------------ | ----------------------------------- |
| Principles (once)    | `/speckit-constitution`        | `.specify/memory/constitution.md`   |
| What & why           | `/speckit-specify`             | `specs/<n>-<slug>/spec.md`          |
| De-risk ambiguity    | `/speckit-clarify`             | updated `spec.md`                   |
| How                  | `/speckit-plan`                | `plan.md`, `research.md`, contracts |
| Break down           | `/speckit-tasks`               | `tasks.md`                          |
| Consistency check    | `/speckit-analyze`             | report (no writes)                  |
| Build                | `/speckit-implement`           | code + tests                        |
| Close the gaps       | `/speckit-converge`            | unbuilt work appended to `tasks.md` |
| Fix a bug            | `/speckit-bug-assess` → `-fix` → `-test` | `.specify/bugs/<slug>/`   |

Rules:

- One feature = one branch = one `specs/<n>-<slug>/` directory.
- The spec describes **what and why**, never *how*. Implementation detail lives in `plan.md`.
- Any `[NEEDS CLARIFICATION]` marker blocks `/speckit-plan`. Resolve it first.
- Repeat implement → converge until converge reports **Converged**. It also adopts an
  existing codebase into the flow.
- Bugs take the bug lane, not a full spec: assess the cause, fix that cause, test the
  original symptom. A `failed` or missing verification is not a fix.
- Scope changes go back to the spec — do not silently widen the work.

## 3. Behavior — Karpathy principles

1. **Think Before Coding** — don't assume, don't hide confusion, surface tradeoffs.
2. **Simplicity First** — minimum code that solves the problem, nothing speculative.
3. **Surgical Changes** — touch only what you must, clean up only your own mess.
4. **Goal-Driven Execution** — define success criteria, loop until verified.

Expanded in [CLAUDE.md](CLAUDE.md) and [.cursor/rules/karpathy.mdc](.cursor/rules/karpathy.mdc).

## 4. Verification (definition of done)

A task is done only when a **real command** proves it — never "should work".

- `./scripts/verify.sh --full` runs the §1 lint, test and build commands. Run it and
  paste the actual result. "No commands configured" is not a pass.
- New behavior ships with a test that fails without the change.
- If verification is impossible, say so explicitly instead of implying success.
- Enforced, not trusted — three layers call the same script: the `verify` skill (Claude
  Code runs it before every commit), the `Stop` hook `.claude/hooks/verification-gate.sh`,
  and CI (`.github/workflows/ci.yml`), which no agent can skip.

## 5. Token discipline

- **Shell output → use [RTK](https://github.com/rtk-ai/rtk)** whenever an equivalent exists:
  `rtk ls`, `rtk read`, `rtk grep`, `rtk find`, `rtk git status`, `rtk git diff`,
  `rtk test`, `rtk lint`, `rtk err`. 60–90% fewer tokens, same information.
- **Prose → concise.** Lead with the answer; report results, not a narration of steps.
  Code, commands and paths are never abbreviated.
- Read the narrowest slice of a file that answers the question; avoid whole-file dumps.

## 6. Security

- **Never** hardcode or commit secrets: API keys, tokens, passwords, private keys, `.env`.
- `.env.example` is committed (keys only, dummy values). `.env*` is gitignored.
- Secrets come from the environment or a secret manager at runtime.
- Never print, log, or echo a secret's value — not even truncated.
- Never disable auth, TLS verification, or security checks "to make it work" — that
  includes `git commit --no-verify`.
- Enforced, not trusted:
  - `.claude/settings.json` denies reads of `.env*`, `*.pem`, `*.key`, `credentials*`,
    `id_rsa*` and `secrets/**`. The Bash sandbox is on, so the same denies bind shell
    commands (`cat .env`), not only the Read tool.
  - [Betterleaks](https://github.com/betterleaks/betterleaks) scans every commit
    (`.pre-commit-config.yaml`) and the full history in CI.
  - `.claude/hooks/dangerous-actions-blocker.sh` refuses irreversible commands (root-target
    `rm -rf`, disk writes, force-push to a shared branch, publish) and hook bypasses.

## 7. Git

- [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): subject`
  (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`).
  Imperative mood, ≤72 chars, `!` or `BREAKING CHANGE:` for breaks.
- Branch per feature: `<n>-<slug>` (created by `/speckit-specify`).
- Never commit, push, or open a PR unless asked. Never force-push shared branches.

## 8. Extra skills

Only when a task genuinely needs a specialized capability, pick from the curated
collection at <https://github.com/VoltAgent/awesome-agent-skills> and install **only**
what is needed. Unused skills are pure context tax. Record every addition in §9.

## 9. Repo map

```
.specify/        Spec Kit: constitution, templates, scripts, workflows, extensions (bug, github)
.claude/         Claude Code: speckit + verify + kickoff skills, settings.json, hooks/
.cursor/         Cursor: Karpathy rule, SDD pointer rule, speckit skills
.clinerules/     Cline rules + speckit workflows
.github/         CI workflow, dependabot, copilot-instructions.md
specs/           One directory per feature (created by /speckit-specify)
scripts/         verify.sh (definition of done) · setup.sh / setup.ps1 (bootstrap)
docs/            Extended documentation
AGENTS.md        This file — canonical contract
CLAUDE.md        Claude Code entry point (imports this file)
.pre-commit-config.yaml  Secret scan at the commit boundary (§6)
```
