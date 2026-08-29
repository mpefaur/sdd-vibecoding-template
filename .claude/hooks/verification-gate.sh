#!/usr/bin/env bash
# Stop — AGENTS.md §4 ("done" needs a real command) enforced by the harness.
#
# Runs the project's lint and test commands when the agent tries to finish a
# turn that touched the working tree. On failure it exits 2, which keeps the
# agent working and feeds it the actual output instead of letting it report a
# success nobody observed.
#
# Independent-evaluator principle: the invocation that writes the code should
# not be the one that certifies it. This hook is that second evaluator.
#
# ---------------------------------------------------------------------------
# SETUP — fill these in when you fill in AGENTS.md §1. Until both are empty-
# checked below the gate is a no-op, so the template stays stack-agnostic.
# Override per machine with env vars instead of editing, if you prefer.
#
#   Node   LINT_CMD="npm run lint --silent"   TEST_CMD="npm test --silent"
#   Python LINT_CMD="ruff check ."            TEST_CMD="pytest -q"
#   Rust   LINT_CMD="cargo clippy -q"         TEST_CMD="cargo test -q"
#   Go     LINT_CMD="go vet ./..."            TEST_CMD="go test ./..."
# ---------------------------------------------------------------------------
LINT_CMD="${LINT_CMD:-}"
TEST_CMD="${TEST_CMD:-}"

set -uo pipefail

# Nothing configured yet — stay silent rather than nag on every turn.
[[ -z "$LINT_CMD" && -z "$TEST_CMD" ]] && exit 0

INPUT=$(cat)

# Claude Code sets stop_hook_active when it is already re-running because of a
# Stop hook. Honour it or the gate loops forever on a genuine failure.
if command -v jq >/dev/null 2>&1; then
  [[ "$(jq -r '.stop_hook_active // false' <<<"$INPUT" 2>/dev/null)" == "true" ]] && exit 0
fi

# Only gate turns that actually changed something. A question-and-answer turn
# should not pay for the whole test suite.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    exit 0
  fi
fi

run_check() {
  local label="$1" cmd="$2" output
  [[ -z "$cmd" ]] && return 0
  if ! output=$(eval "$cmd" 2>&1); then
    echo "Verification gate: $label failed — fix it before finishing (AGENTS.md §4)." >&2
    echo "\$ $cmd" >&2
    echo "$output" | tail -n 60 >&2
    exit 2
  fi
}

run_check "lint" "$LINT_CMD"   # fastest first — fail before paying for tests
run_check "tests" "$TEST_CMD"

exit 0
