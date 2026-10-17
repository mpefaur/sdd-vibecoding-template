#!/usr/bin/env bash
# US5 — graduation leaves no trace of hackathon mode (quickstart A12; T045).
source "$(dirname "$0")/lib.sh"

make_clone graduate
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
feature=specs/001-test-hack-2026
mkdir -p "$feature"
printf '# Hackathon Tasks\n\n- [X] H001 [@alice] [slice: 1. a] [≤60m] A — paths: api/**\n' >"$feature/tasks.md"
cat >"$feature/debt.md" <<'MD'
- D001 | in-memory store | where: api/store.py | why: no time for a DB | repay: real database with migrations
- D002 | no auth on admin page | where: web/admin/** | why: demo only | repay: role-based access
MD
git add -A && git commit -qm "chore: hackathon work"

# Refused off the default branch.
git switch -q -c feature-x
assert_exit 1 scripts/hack.sh graduate --lint true --test true
assert_contains - "default branch"
git switch -q main

assert_exit 0 scripts/hack.sh graduate --lint "true" --test "true"
assert_contains - "/speckit-converge"
for p in .specify/mode.json .specify/extensions/hack .specify/extensions/.backup/hack "$feature/debt.md" \
  scripts/hack.sh tests/hack .specify/hack .claude/skills/hack-kickoff .claude/skills/speckit-hack-status; do
  assert_absent "$p"
done
for f in AGENTS.md .github/copilot-instructions.md .cursor/rules/sdd-workflow.mdc .clinerules/00-agents.md \
  .pre-commit-config.yaml .github/workflows/ci.yml scripts/verify.sh; do
  assert_not_contains "$f" "hackathon-mode:begin"
done
assert_not_contains AGENTS.md "template-only"
for f in .claude/settings.json .specify/extensions.yml; do assert_not_contains "$f" "speckit.hack"; done
[[ -f .cursor/hooks.json ]] && assert_not_contains .cursor/hooks.json "speckit.hack"
assert_contains "$feature/tasks.md" "## Inherited debt"
assert_contains "$feature/tasks.md" "in-memory store — where: api/store.py — repay: real database with migrations"
assert_eq "$(grep -c '^- \[ \] T9' "$feature/tasks.md")" "2" "every debt entry became a task"
assert_contains scripts/verify.sh 'LINT_CMD="${LINT_CMD:-true}"'
assert_exit 0 scripts/verify.sh --full
assert_contains - "verify: lint"
assert_contains - "verify: tests"
assert_eq "$(grep -c '<PROJECT_NAME>\|<COMMAND>' AGENTS.md)" "0" "AGENTS.md §1 stays adopted"
assert_not_contains AGENTS.md "n/a (hackathon mode)"

# Coordinating variant needs a code repository the team owns.
make_clone graduate-coord
scripts/hack.sh on --event "Test Hack 2026" --ends-at "2099-01-01T18:00:00+00:00" --stack bash \
  --run true --build true --smoke true --spec-owner alice --owner "alice=be:api/**" \
  --variant coordinating --event-repo "be=../be,https://example.invalid/be.git,trunk" >/dev/null 2>&1
if [[ -f .specify/mode.json ]]; then
  git add -A && git commit -qm "chore: activate"
  assert_exit 1 scripts/hack.sh graduate --lint true --test true
  assert_contains - "--code-repo"
else
  _fail "coordinating activation failed"
fi
finish
