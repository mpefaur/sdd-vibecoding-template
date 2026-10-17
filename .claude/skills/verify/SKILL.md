---
name: verify
description: "Prove the working tree is done: run the project's lint, tests and build (scripts/verify.sh --full) and report the real result. Run before every commit and before saying a task is finished."
user-invocable: true
---

# verify — the definition of done (AGENTS.md §4)

Claude Code runs a skill named `verify` right before committing. It is also the step
to run before reporting any task as done.

1. Run the full check from the repo root:

   ```bash
   ./scripts/verify.sh --full
   ```

2. Read the actual output.
   - **Exit 0 with `verify: OK`** → done. Quote the final lines in your report.
   - **Exit 0 with `no commands configured yet`** → nothing was verified. Say so
     explicitly; never report it as a pass. The fix is `/kickoff` (or filling the
     commands in `scripts/verify.sh`).
   - **Non-zero** → fix the cause and run it again. Do not commit, and do not weaken a
     test or a lint rule to make it pass unless the user asked for that.

3. Never bypass the commit hooks to get past a failure (`--no-verify`, `-n`,
   `SKIP=…`, `core.hooksPath`). The hook blocker refuses them; CI re-runs the same
   checks anyway.
