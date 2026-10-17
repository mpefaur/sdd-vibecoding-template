---
description: "Hackathon mode: leave the mode and hand the project to the full flow"
scripts:
  sh: scripts/hack.sh graduate
---

## User Input

```text
$ARGUMENTS
```

Graduation turns a hackathon proof of concept into a full-mode project. It is the **only**
exit from hackathon mode, and it is one-way.

1. Run `scripts/hack.sh status` and show it. Check you are on the default branch with a
   clean tree; otherwise tell the user what to merge, commit or stash first.
2. Ask the user for the project's real full-mode commands, in one message:
   - **lint** command (required);
   - **test** command (required);
   - **build** command (optional; defaults to the hackathon build command).
   - Coordinating variant (`variant: coordinating` in `.specify/mode.json`): the path of a
     code repository **the team owns**, passed as `--code-repo`. If the team owns none, stop
     and explain that the proof of concept stays as is.
3. Show what will happen and wait for an explicit yes:
   - the lint, test and build commands are set in `scripts/verify.sh` and AGENTS.md §1;
   - every `debt.md` entry becomes a task under `## Inherited debt` in the spec's
     `tasks.md`;
   - the hack extension, its native hooks, the notices, the commit-time check and the
     hackathon tooling are removed;
   - hackathon mode cannot be re-entered.
4. Run `{SCRIPT} --lint "<cmd>" --test "<cmd>" [--build "<cmd>"] [--code-repo <path>]` and
   report its output verbatim. If it fails, it rolls everything back and names the step.
   **Do not install tools** (no `pip`, `npm` or `brew` installs) to make the new commands
   pass: if a lint or test tool is missing, say so and give the install command. The
   project's setup is the user's call.
   Expect permission prompts: it writes `.claude/settings.json` and `.claude/skills/`.
5. Next steps: `/speckit-converge`, which adopts the existing code and the inherited debt into
   the full flow, then `/speckit-constitution` if the project needs its own principles. Do
   not commit unless asked; suggest `chore: graduate from hackathon mode`.
