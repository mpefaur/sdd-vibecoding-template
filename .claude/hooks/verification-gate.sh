#!/usr/bin/env bash
# Stop — AGENTS.md §4 ("done" needs a real command) enforced by the harness.
#
# Runs scripts/verify.sh (lint + tests) when the agent tries to finish a turn
# that left the working tree dirty. On failure it exits 2, which keeps the
# agent working and feeds it the actual output instead of letting it report a
# success nobody observed.
#
# Independent-evaluator principle: the invocation that writes the code should
# not be the one that certifies it. This hook is that second evaluator.
#
# The commands live in scripts/verify.sh, not here — one definition shared
# with the `verify` skill and CI. Unconfigured, verify.sh is a no-op.

set -uo pipefail

VERIFY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/verify.sh"
[[ -f "$VERIFY" ]] || exit 0

INPUT=$(cat)

# Claude Code sets stop_hook_active when it is already re-running because of a
# Stop hook. Honour it or the gate loops forever on a genuine failure.
if command -v jq >/dev/null 2>&1; then
  [[ "$(jq -r '.stop_hook_active // false' <<<"$INPUT" 2>/dev/null)" == "true" ]] && exit 0
fi

# Only gate turns that leave changes behind. A question-and-answer turn should
# not pay for the whole test suite. `status --porcelain` (not `diff --quiet`)
# so a turn that only creates new, untracked files is gated too.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  [[ -z "$(git status --porcelain 2>/dev/null)" ]] && exit 0
fi

if ! output=$(bash "$VERIFY" 2>&1); then
  echo "Verification gate: scripts/verify.sh failed — fix it before finishing (AGENTS.md §4)." >&2
  echo "$output" | tail -n 60 >&2
  exit 2
fi

exit 0
