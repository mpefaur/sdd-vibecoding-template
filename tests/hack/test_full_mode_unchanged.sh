#!/usr/bin/env bash
# FR-006 / SC-007 — a never-activated project sees no extra steps, prompts or checks
# (quickstart A13; T060). Checked as properties, not as a diff against an old commit, so the
# test holds on any branch and survives later template changes. Hackathon mentions may only
# live inside the marked template-only / hackathon-mode blocks that adoption removes (R16).
source "$(dirname "$0")/lib.sh"

# outside_blocks <file> <begin> <end> — print the file without the marked blocks
outside_blocks() {
  python3 -I - "$@" <<'PY'
import sys
path, begin, end = sys.argv[1:4]
inside = False
for line in open(path, encoding="utf-8"):
    if begin in line:
        inside = True
        continue
    if inside:
        if end in line:
            inside = False
        continue
    sys.stdout.write(line)
PY
}

make_clone full-mode

# No hackathon hooks or events anywhere an agent or Spec Kit would run them.
python3 -I -c 'import json;h=json.dumps(json.load(open(".claude/settings.json")).get("hooks",{}));exit(0 if "speckit.hack" not in h and "events.py" not in h else 1)' \
  && _pass "no hackathon hooks in .claude/settings.json" || _fail "hackathon hooks in .claude/settings.json"
assert_absent .cursor/hooks.json
assert_absent .specify/events.py
assert_absent .specify/extensions/hack
assert_absent .specify/mode.json
assert_not_contains .specify/extensions.yml "speckit.hack"
assert_not_contains .pre-commit-config.yaml "hack-check"

# No /speckit-hack-* command for any agent; the only hackathon entry point is /hack-kickoff.
cmds=$( (ls .claude/skills; ls .cursor/skills; ls .clinerules/workflows) | grep -i hack | sort | tr '\n' ' ')
assert_eq "$cmds" "hack-kickoff " "the only hackathon command is the template-only /hack-kickoff"

# Outside the marked blocks, the shared files carry no hackathon logic or wording.
assert_eq "$(outside_blocks .github/workflows/ci.yml '# template-only:begin' '# template-only:end' >"$HACK_TEST_TMP/ci-$$"
  outside_blocks "$HACK_TEST_TMP/ci-$$" '# hackathon-mode:begin' '# hackathon-mode:end' | grep -ci 'hack')" "0" \
  "CI mentions hackathon mode only inside marked blocks"
assert_eq "$(outside_blocks scripts/verify.sh '# hackathon-mode:begin' '# hackathon-mode:end' | grep -ci 'hack')" "0" \
  "verify.sh mentions hackathon mode only inside its marked block"
assert_eq "$(outside_blocks AGENTS.md '<!-- template-only:begin -->' '<!-- template-only:end -->' | grep -ci 'hack')" "0" \
  "AGENTS.md mentions hackathon mode only inside its marked block"

# Full-mode verification still behaves as before: unconfigured is a no-op, configured runs.
assert_exit 0 scripts/verify.sh
assert_contains - "no commands configured"
OUT=$(LINT_CMD=true TEST_CMD=true BUILD_CMD=true scripts/verify.sh --full 2>&1)
assert_eq "$OUT" "$(printf 'verify: lint — $ true\nverify: tests — $ true\nverify: build — $ true\nverify: OK')" \
  "configured full-mode verify runs lint, tests, build"
finish
