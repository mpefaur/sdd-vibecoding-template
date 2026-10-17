#!/usr/bin/env bash
# US3 — the enforcing state check (quickstart A5, A7; T024).
source "$(dirname "$0")/lib.sh"

make_clone check
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
mkdir -p specs/001-test-hack-2026 && echo "# spec" >specs/001-test-hack-2026/spec.md
git add -A && git commit -qm "chore: activate hackathon mode"
assert_exit 0 scripts/hack.sh check

violate() { # <label> <path-in-error> <setup…>
  local label="$1" path="$2"; shift 2
  echo "  · $label"
  "$@"
  assert_exit 1 scripts/hack.sh check
  assert_contains - "$path"
  git checkout -q -- . && git clean -fdq
}
violate "second spec" "specs/002-x" bash -c 'mkdir -p specs/002-x && echo x > specs/002-x/spec.md'
violate "full-flow artifact" "research.md" bash -c 'echo x > specs/001-test-hack-2026/research.md'
violate "bug-lane output" ".specify/bugs" bash -c 'mkdir -p .specify/bugs/y && echo x > .specify/bugs/y/assessment.md'
violate "constitution edit" "hackathon constitution" bash -c 'echo "### V. More" >> .specify/extensions/hack/templates/hack-constitution.md'

# A7 — ownership warning names each owner, never fails.
assert_exit 0 scripts/hack.sh check --changed api/a.py web/b.tsx
assert_contains - "WARN"
assert_contains - "alice"
assert_contains - "bob"
assert_exit 0 scripts/hack.sh check --changed api/a.py api/b.py
assert_not_contains - "WARN"

# Performance: under 2 s with 10,000 extra committed files (plan Performance Goals).
python3 -I -c '
import os
os.makedirs("bulk", exist_ok=True)
for i in range(10000):
    open(f"bulk/f{i}.txt", "w").write("x")'
git add -A && git commit -qm "chore: bulk files"
t0=$(python3 -I -c 'import time; print(time.time())')
scripts/hack.sh check >/dev/null 2>&1
t1=$(python3 -I -c 'import time; print(time.time())')
python3 -I -c "import sys; sys.exit(0 if $t1 - $t0 < 2.0 else 1)" \
  && _pass "check takes under 2 s with 10,000 files" || _fail "check took $(python3 -I -c "print(round($t1 - $t0, 2))") s"

# Full mode: silent no-op.
make_clone check-full
assert_exit 0 scripts/hack.sh check
assert_eq "$OUT" "" "full-mode check prints nothing"
finish
