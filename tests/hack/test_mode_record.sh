#!/usr/bin/env bash
# Mode-record validation (contracts/mode-record.schema.json) — tasks T007, T009.
source "$(dirname "$0")/lib.sh"
FIX="$HACK_TEST_SRC/tests/hack/fixtures"

make_clone mode-record
for f in mode-valid-standard mode-valid-coordinating; do
  cp "$FIX/$f.json" .specify/mode.json
  OUT=$(scripts/hack.sh check 2>&1); code=$?
  if [[ "$code" != 3 ]]; then _pass "$f: validation passes (exit $code)"; else _fail "$f rejected: $OUT"; fi
done

check_invalid() { # <fixture> <field named in the error>
  cp "$FIX/$1.json" .specify/mode.json
  assert_exit 3 scripts/hack.sh check
  assert_contains - "$2"
}
check_invalid mode-invalid-missing-owner "owners: required"
check_invalid mode-invalid-coordinating-no-repos "event_repos: variant coordinating requires"
check_invalid mode-invalid-manual-with-smoke "commands.smoke: must be null"
check_invalid mode-invalid-dup-path "a path pattern must not appear under two owners"
finish
