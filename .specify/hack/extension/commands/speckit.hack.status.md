---
description: "Hackathon mode: show the mode, the active spec and the definition of done"
scripts:
  sh: scripts/hack.sh status
---

Run `{SCRIPT}` from the repository root and print its output verbatim. Do not summarize it
or add anything to it.

It also rewrites `.specify/feature.json` from the mode record, so the next Spec Kit command
finds the active spec on any clone.
