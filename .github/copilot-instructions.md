# Copilot Instructions

[`AGENTS.md`](../AGENTS.md) at the repository root is the canonical contract for
every coding agent here, including Copilot. Read it before proposing changes.

Non-negotiables, restated so they survive truncation:

- **Spec-Driven Development.** No implementation before a spec, plan and
  `tasks.md` exist under `specs/<n>-<slug>/` (§2).
- **Surgical changes.** Touch only what the task requires. Do not refactor,
  reformat or "fix" code you merely read (§3).
- **Verification.** A change is done only when `./scripts/verify.sh --full` (the
  real lint/test/build commands) proves it. Never imply success you did not observe (§4).
- **Secrets.** Never hardcode, print, or commit a key, token or `.env` value (§6).
- **Commits.** Conventional Commits, imperative mood, ≤72 chars (§7).
