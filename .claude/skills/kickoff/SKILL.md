---
name: "kickoff"
description: "Adopt this template into a real project: fill AGENTS.md §1, arm the guardrails, rewrite the README, then hand off to the Spec-Driven Development flow."
argument-hint: "Describe what you want to build (one or two sentences)"
compatibility: "Run once, on a fresh clone of sdd-vibecoding-template"
user-invocable: true
disable-model-invocation: false
---

# kickoff — turn the template into a project

This template ships deliberately unconfigured: `AGENTS.md` §1 is placeholders and the
verification gate is a no-op. Until that is fixed, §4 ("done needs a real command") and
the `Stop` hook cannot do their job. This skill fixes it in one pass and then gets out of
the way.

**You write configuration and documentation only. You do NOT scaffold the project.**
No `package.json`, no `src/`, no framework `init`. `AGENTS.md` §2 forbids implementation
before `tasks.md` exists, and that rule applies to you. The stack gets installed during
`/speckit-implement`, from tasks that came from a spec.

---

## Step 0 — Check this repo still needs adopting

```bash
grep -c '<PROJECT_NAME>\|<ONE_SENTENCE>\|<LANGUAGES / FRAMEWORKS>\|<COMMAND>' AGENTS.md
```

- **0 matches** → already adopted. Say so, show the current §1, and stop. Continue only
  if the user explicitly asks to redo it.
- **1+ matches** → proceed.

Also read the user's input (`$ARGUMENTS`). If it is empty, ask exactly one question —
*"¿Qué vas a construir?"* — and wait. Do not guess a project into existence.

## Step 1 — Propose, then confirm

From the user's description, propose a **concrete** configuration. Name real tools and
real versions; "a JS framework" is not a proposal. Pick the boring, well-supported
default for the domain unless the user signalled otherwise.

Present exactly this shape and stop:

```
Propongo:
  Name:    habit-tracker
  Purpose: Web app that logs daily habits and shows streaks.
  Stack:   TypeScript · Next.js 16 · SQLite/Drizzle · Vitest · Biome
  Run:     pnpm dev
  Test:    pnpm vitest run
  Lint:    pnpm biome check .
  Build:   pnpm build

¿OK, o cambio algo?
```

Rules for this step:

- **Write nothing until the user confirms.** One round of edits is normal; apply them and
  re-show the block.
- Run/Test/Lint/Build must be commands that will really exist once the stack is installed.
  They are what every agent uses to prove work is done — a plausible-looking lie here
  poisons every later task.
- If the user's description does not imply a stack (a CLI? a service? a library?), ask
  that one thing inside the same round rather than guessing.

## Step 2 — Write `AGENTS.md`

1. Replace the four bullets in §1 with the confirmed values.
2. Delete the `> Replace the <PROJECT> placeholders…` admonition near the top.
3. Delete the whole `## 0. First run` section — it has served its purpose, and leaving it
   in means every future session is told to run this skill again.

Leave §2–§9 untouched. They are the contract, not template scaffolding.

## Step 3 — Arm verification (one script, three callers)

In `scripts/verify.sh`, set the three variables to the §1 commands:

```bash
LINT_CMD="${LINT_CMD:-pnpm biome check .}"
TEST_CMD="${TEST_CMD:-pnpm vitest run}"
BUILD_CMD="${BUILD_CMD:-pnpm build}"
```

Keep the `${VAR:-default}` form so an env var or `.claude/settings.local.json` can still
override per machine. The `Stop` hook, the `verify` skill and CI all call this script —
do not copy the commands anywhere else.

In `.github/workflows/ci.yml`, add the stack's toolchain setup to the `verify` job, before
the `Verify` step (e.g. `pnpm/action-setup` + `actions/setup-node`, or
`astral-sh/setup-uv`). Pin each action by full commit SHA with the version in a comment,
like the existing `actions/checkout` line — look the SHA up (`gh api
repos/<owner>/<action>/git/ref/tags/<tag>`), never invent one. Dependabot keeps them
current.

The Bash sandbox starts with no network domains allowed. If the stack's package registry
is known (`registry.npmjs.org`, `pypi.org` + `files.pythonhosted.org`, `crates.io`, …),
add it to `sandbox.network.allowedDomains` in `.claude/settings.json` so installs don't
prompt every time. Likewise add the package manager's cache to
`sandbox.filesystem.allowWrite` (`~/.cache/uv`, `~/.npm`, `~/Library/pnpm`,
`~/.cargo/registry`, …) — the sandbox only lets commands write inside the repo and temp
dir, so `uv run` or `npm ci` otherwise fail with `Operation not permitted`.

Then verify the *tools* resolve — the suites cannot pass yet, there is no code:

```bash
command -v pnpm || echo "MISSING: pnpm"
```

Report honestly. A missing tool is a note for the user, not a reason to change §1.

## Step 4 — Enable the commit hooks

```bash
pre-commit install --install-hooks
```

This writes `.git/hooks/` and downloads the Betterleaks hook, both of which the Bash
sandbox refuses; expect the unsandboxed-retry prompt. If `pre-commit` is not installed,
do not fail: tell the user the one-liner (`uv tool install pre-commit && pre-commit
install --install-hooks`) and move on.

## Step 5 — Rewrite the README

1. `git mv README.md docs/TEMPLATE_README.md` — the template's own README stays as
   reference, it explains the tooling.
2. Write a new `README.md` for **this project**: name, one-paragraph purpose, the §1
   run/test/lint/build commands, and a short "how this repo works" pointing at
   `AGENTS.md` and `docs/TEMPLATE_USAGE.md` §9 for the guardrails.
3. Keep it short. It describes a project that does not exist yet; do not invent features,
   screenshots, or a roadmap.

Leave `docs/TEMPLATE_USAGE.md` in place — it documents the tooling, not the project. Fix
its one stale link: line 3 says *"companion to the `[README](../README.md)`"*, which now
points at the project README. Repoint it to `TEMPLATE_README.md`.

## Step 6 — Check the git remote

```bash
git remote -v
```

A fresh `git clone` of the template leaves `origin` pointing at the **template repo**, so
the first `git push` would go there. If `origin` still looks like the template, warn the
user and show the fix — do not change it yourself:

```bash
git remote set-url origin <your-new-repo-url>
```

## Step 7 — Report and hand off

Report what changed, what you verified, and anything left for the user (missing tools,
the remote). Do **not** commit — `AGENTS.md` §7: never commit unless asked. Offer it.

Then continue straight into the flow, without waiting for another prompt:

1. `/speckit-constitution` — adapt the base constitution to this project.
2. `/speckit-specify` — pass the user's original description through as the first feature.

From there the normal cycle applies: `clarify → plan → tasks → analyze → implement ⇄ converge`.
