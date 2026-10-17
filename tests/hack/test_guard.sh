#!/usr/bin/env bash
# US3 — full-flow and bug-lane commands are refused with a redirect (quickstart A3, A4; T023).
source "$(dirname "$0")/lib.sh"

make_clone guard
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }

for id in constitution specify clarify plan tasks analyze checklist bug.assess bug.fix bug.test; do
  hyphen=${id//./-}
  for form in "speckit.$id" "/speckit-$hyphen" "speckit-$hyphen"; do
    assert_exit 2 scripts/hack.sh guard "$form"
  done
done
assert_exit 2 scripts/hack.sh guard kickoff
assert_contains - "graduate is the only exit (/speckit-hack-graduate)"
assert_exit 2 scripts/hack.sh guard speckit.specify
assert_contains - "/speckit-hack-sprint"
assert_exit 2 scripts/hack.sh guard /speckit-bug-fix
assert_contains - "debt.md"

# Prompt payload on stdin (the user_prompt_submit event; field per research "Spike results").
assert_exit 2 bash -c 'printf "%s" "{\"prompt\": \"/speckit-clarify what about auth?\"}" | scripts/hack.sh guard'
assert_exit 0 bash -c 'printf "%s" "{\"prompt\": \"add a login button\"}" | scripts/hack.sh guard'
assert_exit 0 bash -c 'printf "%s" "{\"prompt\": \"/speckit-implement\"}" | scripts/hack.sh guard'

# No argument and no input: lifecycle-hook invocation → block, without waiting on stdin.
t0=$(python3 -I -c 'import time; print(time.time())')
assert_exit 2 bash -c 'scripts/hack.sh guard </dev/null'
t1=$(python3 -I -c 'import time; print(time.time())')
python3 -I -c "import sys; sys.exit(0 if $t1 - $t0 < 1.0 else 1)" \
  && _pass "no-input guard returns in under 1 s" || _fail "no-input guard took $(python3 -I -c "print(round($t1 - $t0, 2))") s"
if [[ "$(uname)" == Darwin ]]; then tty_cmd=(script -q /dev/null scripts/hack.sh guard)
else tty_cmd=(script -qec "scripts/hack.sh guard" /dev/null); fi
if [[ "$(uname)" == Darwin ]]; then tty_probe=(script -q /dev/null true); else tty_probe=(script -qec true /dev/null); fi
if command -v script >/dev/null 2>&1 && "${tty_probe[@]}" >/dev/null 2>&1; then
  assert_exit 2 "${tty_cmd[@]}"
else
  echo "  - skipped: no pseudo-terminal available here (TTY case covered where script(1) works)"
fi

# A4 — allowed commands
for id in speckit.implement speckit.converge speckit.hack.sprint /speckit-hack-status; do
  assert_exit 0 scripts/hack.sh guard "$id"
done

# Full mode: nothing is blocked.
make_clone guard-full
assert_exit 0 scripts/hack.sh guard speckit.clarify
finish
