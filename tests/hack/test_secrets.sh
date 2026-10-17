#!/usr/bin/env bash
# FR-028 — secret scanning is identical in both modes (quickstart A15; T026).
source "$(dirname "$0")/lib.sh"
command -v pre-commit >/dev/null 2>&1 || { _fail "pre-commit not installed"; finish; }

hook_results() { # failing/passing hook lines, timing stripped, hack-check excluded
  grep -E '\.\.\.+(Passed|Failed|Skipped)' <<<"$1" | grep -v "hackathon mode check" | sed -E 's/\.{2,}/ … /'
}

make_clone secrets-full
pre-commit install >/dev/null 2>&1 || { _fail "pre-commit install failed"; finish; }
synthetic_secret leak.txt && git add leak.txt
assert_exit 1 git commit -qm "test: leak"
full=$(hook_results "$OUT")

make_clone secrets-hack
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
git add -A && git commit -qm "chore: activate hackathon mode"
pre-commit install >/dev/null 2>&1 || { _fail "pre-commit install failed"; finish; }
synthetic_secret leak.txt && git add leak.txt
assert_exit 1 git commit -qm "test: leak"
hack=$(hook_results "$OUT")

assert_contains - "betterleaks"
assert_eq "$hack" "$full" "secret-scan hook results are identical in both modes"
finish
