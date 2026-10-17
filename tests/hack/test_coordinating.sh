#!/usr/bin/env bash
# US6 — coordinating variant: local-only checks in event repositories (quickstart A14; T048).
source "$(dirname "$0")/lib.sh"
command -v pre-commit >/dev/null 2>&1 || { _fail "pre-commit not installed"; finish; }

make_clone coord
base="$HACK_TEST_TMP"
for r in be fe; do
  rm -rf "$base/$r-$$.git" "$base/$r-$$"
  git init -q --bare -b trunk "$base/$r-$$.git"
  git clone -q "$base/$r-$$.git" "$base/$r-$$" 2>/dev/null
  (cd "$base/$r-$$" && git config user.email t@example.invalid && git config user.name t \
    && git switch -q -c trunk 2>/dev/null; echo "# $r" >README.md && git add README.md && git commit -qm init && git push -q origin trunk)
done

assert_exit 3 scripts/hack.sh on --event "Coord Hack" --ends-at "2099-01-01T18:00:00+00:00" --stack bash \
  --run true --build true --smoke true --spec-owner alice --owner "alice=be:**" --variant coordinating
assert_contains - "requires at least 1 event repository"

assert_exit 0 scripts/hack.sh on --event "Coord Hack" --ends-at "2099-01-01T18:00:00+00:00" --stack bash \
  --run true --build true --smoke true --spec-owner alice --owner "alice=be:**" --owner "bob=fe:**" \
  --variant coordinating --event-repo "be=../be-$$,file://$base/be-$$.git,trunk" \
  --event-repo "fe=../fe-$$,file://$base/fe-$$.git,trunk"
git add -A && git commit -qm "chore: activate hackathon mode"

assert_exit 0 scripts/hack.sh hooks
for r in be fe; do
  grep -q -- "--config=.*$(basename "$CLONE")/.specify/hack/local/event-$r-pre-commit.yaml" "$base/$r-$$/.git/hooks/pre-commit" \
    && _pass "$r: pre-commit uses the coordinating config" || _fail "$r: pre-commit hook not pointing at the coordinating config"
  assert_eq "$(git -C "$base/$r-$$" status --porcelain)" "" "$r: no tracked file changed in the event repository"
done

cd "$base/be-$$" || exit 1
synthetic_secret leak.txt && git add leak.txt
assert_exit 1 git commit -qm "test: leak"
assert_contains - "local-only"
git reset -q --hard HEAD && git clean -fdq

cd "$base/fe-$$" || exit 1
mkdir -p specs/x && echo x >specs/x/spec.md && git add -A
assert_exit 1 git commit -qm "test: spec in event repo"
assert_contains - "specs/x/spec.md"
assert_contains - "local-only"
git reset -q --hard HEAD && git clean -fdq
echo "page" >page.txt && git add page.txt
assert_exit 0 git commit -qm "feat: page"
assert_exit 0 git push origin HEAD:trunk
assert_contains - "target branch: trunk"
assert_contains - "local-only"

cd "$CLONE" || exit 1
assert_exit 0 scripts/hack.sh status
assert_contains - "event repo be"
assert_contains - "submit to trunk"
assert_contains - "enforcement on event repositories is local-only and can be bypassed"
assert_contains AGENTS.md "enforcement there is local-only"
finish
