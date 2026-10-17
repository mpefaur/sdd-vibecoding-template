# Cline Rules

`AGENTS.md` at the repo root is the canonical contract — workflow (§2), behavior (§3),
verification (§4), token discipline (§5), security (§6), git (§7). Read it before
non-trivial work. This file repeats nothing from it so the two cannot drift.

Cline-specific:

- Spec Kit workflows live in `.clinerules/workflows/` and run as `/speckit-specify.md`,
  `/speckit-plan.md`, `/speckit-tasks.md`, `/speckit-implement.md`,
  `/speckit-converge.md` (and the rest of `AGENTS.md` §2).
- The bug lane (`speckit-bug-*`) is installed for Claude Code only; follow
  `.claude/skills/speckit-bug-assess/SKILL.md` by hand.
- Done = `./scripts/verify.sh --full` passed and you read its output. CI runs the same
  script on every push.
