#!/usr/bin/env bash
# US2 — work items become assigned issues, without duplicates (tasks T033).
source "$(dirname "$0")/lib.sh"

make_clone issues
hack_on_defaults >/dev/null || { _fail "activation failed"; finish; }
feature=specs/001-test-hack-2026
mkdir -p "$feature"
cat >"$feature/tasks.md" <<'MD'
# Tasks

- [ ] H001 [@alice] [slice: 1. sign in] [≤60m] Login endpoint — paths: api/auth/**
- [ ] H002 [@alice] [slice: 2. see the feed] [≤90m] Feed endpoint — paths: api/feed/**
- [ ] H003 [@bob] [slice: 2. see the feed] [≤90m] Feed page — paths: web/feed/**
- [ ] H005 [@bob] [slice: 2. see the feed] [≤30m] Feed page empty state that explains to a first-time visitor why the feed is empty and how to follow someone to fill it — paths: web/feed/**
MD

LOG="$HACK_TEST_TMP/gh-calls-$$.log"; : >"$LOG"
TITLES="$HACK_TEST_TMP/gh-titles-$$.log"; : >"$TITLES"
stub_bin gh "echo \"\$*\" >> '$LOG'
prev=''; for a in \"\$@\"; do [[ \"\$prev\" == --title ]] && echo \"\$a\" >> '$TITLES'; prev=\$a; done
case \"\$1 \$2\" in
  'issue list') echo '[{\"title\": \"H001 Login endpoint\"}]' ;;
  'issue create') echo 'https://github.com/example/repo/issues/9' ;;
esac"

assert_exit 0 scripts/hack.sh issues --dry-run
assert_not_contains - "H001"
assert_contains - "H002 Feed endpoint"
assert_contains - "--assignee alice"
assert_contains - "H003 Feed page"
assert_contains - "--assignee bob"
assert_eq "$(grep -c '^issue create' "$LOG")" "0" "--dry-run creates nothing"

assert_exit 0 scripts/hack.sh issues
assert_eq "$(grep -c '^issue create' "$LOG")" "3" "creates exactly the three missing issues"
long_title=$(grep '^H005' "$TITLES")
[[ ${#long_title} -le 100 ]] && _pass "long descriptions are truncated in the issue title" || _fail "title too long: $long_title"
assert_contains "$LOG" "how to follow someone to fill it"
assert_contains "$LOG" "--assignee bob"

# A work item whose owner does not own its paths is refused, naming it.
cat >>"$feature/tasks.md" <<'MD'
- [ ] H004 [@bob] [slice: 3. post] [≤30m] Post endpoint — paths: api/post/**
MD
assert_exit 1 scripts/hack.sh issues --dry-run
assert_contains - "H004"
assert_contains - "bob does not own api/post/**"

# Without gh: exit 3 (checked only where gh is not in the base system PATH).
unstub_all
if ! PATH=/usr/bin:/bin command -v gh >/dev/null 2>&1; then
  assert_exit 3 env PATH=/usr/bin:/bin scripts/hack.sh issues --dry-run
else
  echo "  - skipped: gh is part of the base system PATH here"
fi
finish
