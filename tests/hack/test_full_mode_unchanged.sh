#!/usr/bin/env bash
# FR-006 / SC-007 — a never-activated project sees no extra steps, prompts or checks
# (quickstart A13; T060). Compares against `main` at the start of this feature; the only
# allowed differences are the template-only items of research R16, which adoption removes.
source "$(dirname "$0")/lib.sh"

git -C "$HACK_TEST_SRC" rev-parse -q --verify main >/dev/null || { echo "  - skipped: no local 'main' branch"; finish; }
base() { git -C "$HACK_TEST_SRC" show "main:$1" 2>/dev/null; }
strip() { # <text-file> <begin> <end> — print the file without the marked blocks
  python3 -I - "$@" <<'PY'
import sys
path, begin, end = sys.argv[1:4]
out, inside = [], False
for line in open(path, encoding="utf-8"):
    if begin in line: inside = True; continue
    if inside:
        if end in line: inside = False
        continue
    out.append(line)
text = "".join(out)
while "\n\n\n" in text: text = text.replace("\n\n\n", "\n\n")
sys.stdout.write(text.rstrip("\n") + "\n")
PY
}
norm() { python3 -I -c 'import sys;t=sys.stdin.read();
while "\n\n\n" in t: t=t.replace("\n\n\n","\n\n")
sys.stdout.write(t.rstrip("\n")+"\n")'; }

make_clone full-mode

assert_eq "$(python3 -I -c 'import json;print(json.dumps(json.load(open(".claude/settings.json")).get("hooks"),sort_keys=True))')" \
  "$(base .claude/settings.json | python3 -I -c 'import json,sys;print(json.dumps(json.load(sys.stdin).get("hooks"),sort_keys=True))')" \
  "Claude Code hooks are identical"
assert_absent .cursor/hooks.json
assert_absent .specify/events.py
assert_eq "$(cat .specify/extensions.yml)" "$(base .specify/extensions.yml)" "Spec Kit lifecycle hooks are identical"
assert_eq "$(grep -o 'id: [a-z-]*' .pre-commit-config.yaml)" "$(base .pre-commit-config.yaml | grep -o 'id: [a-z-]*')" "pre-commit hooks are identical"

now=$( (ls .claude/skills; ls .cursor/skills; ls .clinerules/workflows) | sort)
was=$( (git -C "$HACK_TEST_SRC" ls-tree --name-only main .claude/skills/ .cursor/skills/ .clinerules/workflows/ | xargs -n1 basename) | sort)
assert_eq "$(comm -13 <(echo "$was") <(echo "$now") | tr '\n' ' ')" "hack-kickoff " "the only new agent command is the template-only hack-kickoff"
assert_eq "$(comm -23 <(echo "$was") <(echo "$now") | tr '\n' ' ')" "" "no agent command was removed"

assert_eq "$(strip .github/workflows/ci.yml '# template-only:begin' '# template-only:end' >"$HACK_TEST_TMP/ci-$$" && strip "$HACK_TEST_TMP/ci-$$" '# hackathon-mode:begin' '# hackathon-mode:end')" \
  "$(base .github/workflows/ci.yml | norm)" "CI is identical apart from the marked template-only and hackathon blocks"
assert_eq "$(strip scripts/verify.sh '# hackathon-mode:begin' '# hackathon-mode:end')" "$(base scripts/verify.sh | norm)" \
  "verify.sh is identical apart from the marked hackathon block"
assert_eq "$(strip AGENTS.md '<!-- template-only:begin -->' '<!-- template-only:end -->')" "$(base AGENTS.md | norm)" \
  "AGENTS.md is identical apart from the marked template-only lines"
finish
