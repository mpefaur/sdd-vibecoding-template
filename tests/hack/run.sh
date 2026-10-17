#!/usr/bin/env bash
# Runs every hackathon-mode scenario test (specs/001-hackathon-mode/quickstart.md A1–A15).
#
#   tests/hack/run.sh              all tests
#   tests/hack/run.sh check guard  only test_check.sh and test_guard.sh
#
# Each test runs in its own process against throwaway clones under $TMPDIR. CI runs this
# only while the repository is the unadopted template (.github/workflows/ci.yml,
# template-selftest job).

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 0 ]]; then
  files=(); for n in "$@"; do files+=("$DIR/test_$n.sh"); done
else
  files=("$DIR"/test_*.sh)
fi

passed=0 failed=0 failed_names=""
for f in "${files[@]}"; do
  name=$(basename "$f" .sh)
  if [[ ! -f "$f" ]]; then echo "FAIL $name (no such test)"; failed=$((failed + 1)); continue; fi
  if output=$(bash "$f" 2>&1); then
    echo "PASS $name"; passed=$((passed + 1))
  else
    echo "FAIL $name"; printf '%s\n' "$output" | sed 's/^/  /'
    failed=$((failed + 1)); failed_names="$failed_names $name"
  fi
done

echo "$passed passed, $failed failed${failed_names:+ —$failed_names}"
[[ "$failed" == 0 ]]
