#!/usr/bin/env bash
#
# The project's definition of done (AGENTS.md §4), in one place.
#
#   ./scripts/verify.sh           lint, then tests          (Stop hook)
#   ./scripts/verify.sh --full    lint, tests, then build   (verify skill, CI)
#
# Every enforcement layer calls this script instead of carrying its own copy of
# the commands: .claude/hooks/verification-gate.sh, the `verify` skill, and
# .github/workflows/ci.yml. Set the commands once, here.
#
# ---------------------------------------------------------------------------
# SETUP — fill these in when you fill in AGENTS.md §1 (/kickoff does it). While
# all are empty the script is a no-op, so the template stays stack-agnostic.
# Env vars override per machine (e.g. via .claude/settings.local.json "env").
#
#   Node   LINT_CMD="npm run lint --silent"   TEST_CMD="npm test --silent"   BUILD_CMD="npm run build"
#   Python LINT_CMD="ruff check ."            TEST_CMD="pytest -q"           BUILD_CMD="uv build"
#   Rust   LINT_CMD="cargo clippy -q"         TEST_CMD="cargo test -q"       BUILD_CMD="cargo build -q"
#   Go     LINT_CMD="go vet ./..."            TEST_CMD="go test ./..."       BUILD_CMD="go build ./..."
# ---------------------------------------------------------------------------
LINT_CMD="${LINT_CMD:-}"
TEST_CMD="${TEST_CMD:-}"
BUILD_CMD="${BUILD_CMD:-}"

set -uo pipefail

FULL=0
[[ "${1:-}" == "--full" ]] && FULL=1

if [[ -z "$LINT_CMD$TEST_CMD$BUILD_CMD" ]]; then
  echo "verify: no commands configured yet (scripts/verify.sh, AGENTS.md §1) — nothing to check."
  exit 0
fi

run() {
  local label="$1" cmd="$2"
  [[ -z "$cmd" ]] && return 0
  echo "verify: $label — \$ $cmd"
  if ! eval "$cmd"; then
    echo "verify: $label FAILED" >&2
    exit 1
  fi
}

run "lint" "$LINT_CMD"     # fastest first — fail before paying for tests
run "tests" "$TEST_CMD"
[[ "$FULL" == 1 ]] && run "build" "$BUILD_CMD"

echo "verify: OK"
