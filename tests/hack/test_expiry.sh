#!/usr/bin/env bash
# US7 — past ends_at, warn everywhere and never block (quickstart A10; T053).
source "$(dirname "$0")/lib.sh"

make_clone expiry
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
git add -A && git commit -qm "chore: activate hackathon mode"

codes_future="$(scripts/hack.sh status >/dev/null 2>&1; echo $?) $(scripts/hack.sh check >/dev/null 2>&1; echo $?) $(scripts/verify.sh >/dev/null 2>&1; echo $?)"
assert_exit 0 scripts/hack.sh status
assert_not_contains - "hackathon ended"

python3 -I -c 'import json;p=".specify/mode.json";m=json.load(open(p));m["ends_at"]="2020-01-01T18:00:00+00:00";json.dump(m,open(p,"w"),indent=2)'
for cmd in "scripts/hack.sh status" "scripts/hack.sh check" "scripts/verify.sh"; do
  OUT=$($cmd 2>&1)
  assert_contains - "WARN hackathon ended 2020-01-01T18:00:00+00:00 — graduate (/speckit-hack-graduate) or archive the repository"
done
codes_past="$(scripts/hack.sh status >/dev/null 2>&1; echo $?) $(scripts/hack.sh check >/dev/null 2>&1; echo $?) $(scripts/verify.sh >/dev/null 2>&1; echo $?)"
assert_eq "$codes_past" "$codes_future" "exit codes are unchanged by the expiry warning"

# shellcheck disable=SC2034 # read by assert_contains -
OUT=$(GITHUB_ACTIONS=true scripts/hack.sh check 2>&1)
assert_contains - "::warning::hackathon ended"
finish
