#!/usr/bin/env bash
# US1 — activate hackathon mode once (quickstart A1, A2; tasks T014).
source "$(dirname "$0")/lib.sh"

# A1 — activation on a fresh clone
make_clone on-a1
assert_exit 0 hack_on_defaults
assert_file .specify/mode.json
assert_exit 0 scripts/hack.sh check
assert_not_contains AGENTS.md "## 0. First run"
assert_eq "$(grep -c '<PROJECT_NAME>\|<ONE_SENTENCE>\|<LANGUAGES / FRAMEWORKS>\|<COMMAND>' AGENTS.md)" "0" "AGENTS.md §1 has no placeholders"
assert_contains AGENTS.md '**Name:** `test-hack-2026`'
assert_absent specs
assert_not_contains .github/workflows/ci.yml "template-only:begin"
assert_eq "$(python3 -I -c 'import json;print(json.load(open(".specify/mode.json"))["feature_directory"])')" \
  "specs/001-test-hack-2026" "feature_directory derived from the event slug"
missing=$(python3 -I -c '
import json
reg = json.load(open(".specify/extensions/.registry"))["extensions"]["hack"]["registered_commands"]
inst = json.load(open(".specify/integration.json"))["installed_integrations"]
print(" ".join(k for k in inst if "speckit.hack.guard" not in reg.get(k, [])))')
assert_eq "$missing" "" "hack commands registered for every installed integration"
assert_file .specify/extensions/hack/scripts/hack.sh
[[ -x .specify/scripts/bash/common.sh ]] && _pass "Spec Kit scripts keep their executable bit" || _fail "common.sh lost its executable bit"
git diff --quiet HEAD -- .claude/skills/speckit-github-taskstoissues/SKILL.md \
  && _pass "existing Spec Kit commands are not regenerated" || _fail "speckit-github-taskstoissues/SKILL.md changed"
assert_eq "$(git -C "$CLONE" rev-parse --abbrev-ref HEAD)" "main" "activation does not switch branches"

# The committed result is the same mode on every clone.
git add -A && git commit -qm "chore: activate hackathon mode"
second="$HACK_TEST_TMP/on-a1-second-$$"
rm -rf "$second" && git clone -q "$CLONE" "$second"
assert_eq "$(python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1]));print(m["event"],m["ends_at"],m["stack"])' "$second/.specify/mode.json")" \
  "Test Hack 2026 2099-01-01T18:00:00+00:00 bash" "a second clone sees the same event, end time and stack"

# A2 — the mode is chosen once
assert_exit 1 hack_on_defaults
assert_contains - "mode is chosen once"

make_clone on-a2-full
sed -i.bak 's/`<PROJECT_NAME>`/`real-project`/' AGENTS.md && rm -f AGENTS.md.bak
sed -i.bak 's/`<ONE_SENTENCE>`/`A real project.`/; s/`<LANGUAGES \/ FRAMEWORKS>`/`Go`/; s/`<COMMAND>`/`go test`/g' AGENTS.md && rm -f AGENTS.md.bak
git commit -qam "chore: adopt in full mode"
assert_exit 1 hack_on_defaults
assert_contains - "already adopted"

# Input errors are usage errors and change nothing.
make_clone on-usage
assert_exit 3 scripts/hack.sh on --event "X"
assert_exit 3 hack_on_defaults --owner "carol=api/**"
assert_contains - "a path pattern must not appear under two owners"
assert_eq "$(git status --porcelain)" "" "a refused activation leaves the tree untouched"

# A failing step rolls everything back.
make_clone on-rollback
stub_bin specify 'echo "specify stub: failing on purpose" >&2; exit 1'
assert_exit 1 hack_on_defaults
assert_contains - "rolled back"
assert_eq "$(git status --porcelain)" "" "rollback leaves the tree identical"
unstub_all

finish
