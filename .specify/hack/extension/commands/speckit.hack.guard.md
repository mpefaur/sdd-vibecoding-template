---
description: "Hackathon mode: refuse full-flow and bug-lane commands with a redirect"
scripts:
  sh: scripts/hack.sh guard
---

This project is in **hackathon mode** (`.specify/mode.json` exists). This command runs as a
mandatory hook before the full-flow commands (constitution, specify, clarify, plan, tasks,
analyze, checklist), and as the prompt-submit handler in agents that support one.

1. Run `{SCRIPT}` from the repository root **with no argument and no input**. As a
   lifecycle hook it only ever runs before a blocked command, and with no input it blocks.
2. If it exits **2**: stop. Show its message to the user verbatim, and **do not continue the
   command that invoked this hook** — not partially, not "just the safe parts". The message
   names what to use instead (usually `/speckit-hack-sprint`).
3. If it exits **0**: continue silently with the command that invoked this hook.

Never edit `.specify/mode.json`, the hackathon constitution, or this file to get around the
block. A team member who wants the full flow graduates the project with
`/speckit-hack-graduate`.
