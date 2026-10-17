#!/usr/bin/env bash
# Shared helpers for the hackathon-mode scenario tests (specs/001-hackathon-mode/quickstart.md).
# Sourced by tests/hack/run.sh and by each tests/hack/test_*.sh. Bash 3.2 compatible.
#
# Every scenario works on a throwaway copy of this checkout under $TMPDIR, never on the
# checkout itself.

HACK_TEST_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HACK_TEST_TMP="${TMPDIR:-/tmp}/hack-tests"
HACK_TEST_FAILS=0
HACK_TEST_ORIG_PATH="$PATH"

# make_clone <name> — copy the working tree (tracked + untracked, not ignored) into a fresh
# git repo, commit it, cd into it, and set $CLONE to its path. Call it directly, not in $(…).
make_clone() {
  local dest="$HACK_TEST_TMP/$1-$$"
  rm -rf "$dest" && mkdir -p "$dest"
  (cd "$HACK_TEST_SRC" && git ls-files -co --exclude-standard -z -- . ':!:.env*' ':!:**/.env*' | tar --null -T - -cf -) \
    | (cd "$dest" && tar -xf -)
  (
    cd "$dest" || exit 1
    git init -q -b main
    git config user.email "hack-tests@example.invalid"
    git config user.name "hack tests"
    git config commit.gpgsign false
    git add -A && git commit -qm "fixture: template snapshot"  # fresh repo: no hooks installed
  )
  # shellcheck disable=SC2034 # read by the sourcing test
  CLONE="$dest"
  cd "$dest" || return 1
}

# synthetic_secret <file> — write a secret-shaped line assembled at run time, so no
# secret-shaped string exists in the repository (research "Spike results", T003d).
synthetic_secret() {
  local body
  body=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)
  printf 'github_token = "%s%s"\n' "gh" "p_$body" >"$1"
}

# stub_bin <name> <script-body> — put a fake executable first on PATH.
stub_bin() {
  local dir="$HACK_TEST_TMP/stubs-$$"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$dir/$1"
  chmod +x "$dir/$1"
  case ":$PATH:" in *":$dir:"*) ;; *) PATH="$dir:$PATH" ;; esac
}

unstub_all() { PATH="$HACK_TEST_ORIG_PATH"; rm -rf "$HACK_TEST_TMP/stubs-$$"; }

_fail() { HACK_TEST_FAILS=$((HACK_TEST_FAILS + 1)); echo "  ✗ $*"; }
_pass() { echo "  ✓ $*"; }

# assert_exit <code> <cmd…> — run cmd, capture stdout+stderr in $OUT, compare exit code.
assert_exit() {
  local want="$1"; shift
  OUT=$("$@" 2>&1); local got=$?
  if [[ "$got" == "$want" ]]; then _pass "exit $want: $*"
  else _fail "exit $got (want $want): $*"; printf '%s\n' "$OUT" | sed 's/^/      | /' | head -20
  fi
}

# assert_contains <file|-> <text> — '-' checks $OUT.
assert_contains() {
  local src="$1" text="$2" hay
  if [[ "$src" == "-" ]]; then hay="$OUT"; else hay=$(cat "$src" 2>/dev/null); fi
  if grep -qF -- "$text" <<<"$hay"; then _pass "contains '$text' ($src)"
  else _fail "missing '$text' in $src"; fi
}

assert_not_contains() {
  local src="$1" text="$2" hay
  if [[ "$src" == "-" ]]; then hay="$OUT"; else hay=$(cat "$src" 2>/dev/null); fi
  if grep -qF -- "$text" <<<"$hay"; then _fail "unexpected '$text' in $src"
  else _pass "no '$text' ($src)"; fi
}

assert_file() { if [[ -e "$1" ]]; then _pass "exists $1"; else _fail "missing $1"; fi; }
assert_absent() { if [[ -e "$1" ]]; then _fail "still present $1"; else _pass "absent $1"; fi; }

# assert_eq <got> <want> <label>
assert_eq() {
  if [[ "$1" == "$2" ]]; then _pass "$3"; else _fail "$3: got '$1', want '$2'"; fi
}

# finish — end of a test file: clean stubs and exit with the failure count.
finish() {
  unstub_all
  exit "$HACK_TEST_FAILS"
}

# hack_on_defaults [extra args…] — activate hackathon mode with a standard test setup.
hack_on_defaults() {
  scripts/hack.sh on --event "Test Hack 2026" --ends-at "2099-01-01T18:00:00+00:00" \
    --stack "bash" --run "true" --build "true" --smoke "true" \
    --spec-owner alice --owner "alice=api/**" --owner "bob=web/**" "$@"
}
