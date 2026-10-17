#!/usr/bin/env bash
# US4 — scripts/verify.sh is mode-aware: check → demo check (→ build) (quickstart A8, A9; T039).
source "$(dirname "$0")/lib.sh"

make_clone verify
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
assert_exit 0 scripts/verify.sh
assert_contains - "verify: check"
assert_contains - "verify: smoke"
assert_not_contains - "verify: build"
assert_contains - "verify: OK"
assert_exit 0 scripts/verify.sh --full
assert_contains - "verify: build"
assert_contains - "verify: OK"

python3 -I -c 'import json;p=".specify/mode.json";m=json.load(open(p));m["commands"]["smoke"]="false";json.dump(m,open(p,"w"))'
assert_exit 1 scripts/verify.sh
assert_contains - "verify: smoke FAILED"

# A9 — a manual demo check is reported as MANUAL, never as passed.
make_clone verify-manual
hack_on_defaults --smoke manual --build none >/dev/null 2>&1 || true
python3 -I -c 'import json;m=json.load(open(".specify/mode.json"));print(m["demo_check"], m["commands"]["build"])' | grep -q "manual None" \
  && _pass "--smoke manual / --build none recorded" || _fail "manual/none not recorded"
assert_exit 0 scripts/verify.sh --full
assert_contains - "MANUAL"
assert_not_contains - "verify: smoke —"
assert_contains - "build not applicable"

# Full mode: byte-identical to the original verify.sh for the same commands.
make_clone verify-full
if orig=$(git -C "$HACK_TEST_SRC" show main:scripts/verify.sh 2>/dev/null); then
  printf '%s\n' "$orig" >"$HACK_TEST_TMP/verify-orig-$$.sh"
  want=$(LINT_CMD=true TEST_CMD=true BUILD_CMD=true bash "$HACK_TEST_TMP/verify-orig-$$.sh" --full 2>&1)
  got=$(LINT_CMD=true TEST_CMD=true BUILD_CMD=true scripts/verify.sh --full 2>&1)
  assert_eq "$got" "$want" "full-mode verify.sh output is unchanged"
  want=$(bash "$HACK_TEST_TMP/verify-orig-$$.sh" 2>&1); got=$(scripts/verify.sh 2>&1)
  assert_eq "$got" "$want" "unconfigured verify.sh output is unchanged"
else
  echo "  - skipped: no local 'main' branch to compare against"
fi
finish
