#!/usr/bin/env bash
# US3 — the commit-time layer rejects full-flow artifacts (quickstart A6; T025).
source "$(dirname "$0")/lib.sh"
command -v pre-commit >/dev/null 2>&1 || { _fail "pre-commit not installed"; finish; }

make_clone precommit
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
assert_contains .pre-commit-config.yaml "id: hack-check"
git add -A && git commit -qm "chore: activate hackathon mode"
pre-commit install >/dev/null 2>&1 || { _fail "pre-commit install failed"; finish; }

reject() { # <label> <setup…>
  local label="$1"; shift
  "$@" && git add -A
  assert_exit 1 git commit -qm "test: $label"
  assert_contains - "hackathon mode check"
  git reset -q --hard HEAD && git clean -fdq
}
reject "second spec" bash -c 'mkdir -p specs/002-x && echo x > specs/002-x/spec.md'
reject "full-flow artifact" bash -c 'mkdir -p specs/001-test-hack-2026 && echo x > specs/001-test-hack-2026/data-model.md'
reject "bug-lane output" bash -c 'mkdir -p .specify/bugs/y && echo x > .specify/bugs/y/fix.md'

mkdir -p specs/001-test-hack-2026 && echo "# spec" >specs/001-test-hack-2026/spec.md && git add -A
assert_exit 0 git commit -qm "docs: hackathon spec"
finish
