#!/usr/bin/env bash
# US4 — status, the active-spec pointer and the instruction notices (quickstart A11, A1; T040).
source "$(dirname "$0")/lib.sh"

make_clone status
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
rm -f .specify/feature.json
assert_exit 0 scripts/hack.sh status
assert_contains .specify/feature.json "specs/001-test-hack-2026"
python3 -I - "$OUT" <<'PY' && _pass "status fields in contract order" || _fail "status order wrong: $OUT"
import sys
out = sys.argv[1]
keys = ["event:", "ends at:", "variant:", "stack:", "active spec:", "spec owner:", "owners:",
        "allowed:", "blocked:", "done ="]
pos = [out.find(k) for k in keys]
sys.exit(0 if all(p >= 0 for p in pos) and pos == sorted(pos) else 1)
PY

for f in AGENTS.md .github/copilot-instructions.md .cursor/rules/sdd-workflow.mdc .clinerules/00-agents.md; do
  assert_eq "$(grep -c 'hackathon-mode:begin' "$f")" "1" "$f has exactly one notice"
  assert_contains "$f" "specs/001-test-hack-2026"
  assert_contains "$f" "scripts/hack.sh status"
  assert_contains "$f" "Done = \`scripts/verify.sh --full\`"
  assert_contains "$f" "Allowed: \`/speckit-hack-sprint\` (spec owner), \`/speckit-hack-status\`, \`/speckit-implement\`, \`/speckit-converge\`, \`/speckit-hack-demo\`, \`/speckit-hack-graduate\`"
done
head -4 .cursor/rules/sdd-workflow.mdc | grep -q '^---$' && _pass "mdc frontmatter stays first" || _fail "mdc frontmatter moved"

make_clone status-full
assert_exit 0 scripts/hack.sh status
assert_contains - "full mode"
finish
