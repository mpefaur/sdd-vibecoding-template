#!/usr/bin/env bash
# PreToolUse(Bash) — refuse a short list of unambiguously destructive commands.
#
# Scope is deliberately narrow: only actions that are irreversible or that
# AGENTS.md §7 forbids outright. Reading secrets is NOT handled here — that is
# permissions.deny in .claude/settings.json, which the harness enforces without
# the false positives a grep over command text would produce.
#
# Contract: exit 0 = allow, exit 2 = block (stderr goes back to the agent).
# Any other exit code is treated as a non-blocking error, so every failure path
# below must exit 0 — a guard that fails open is better than one that bricks
# the session.

set -uo pipefail

INPUT=$(cat)

# jq is the only dependency. If it is missing, allow rather than block
# (AGENTS.md §5: never block on a tool that may not be installed).
command -v jq >/dev/null 2>&1 || exit 0

TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null) || exit 0
[[ -n "$CMD" ]] || exit 0

block() {
  echo "BLOCKED by .claude/hooks/dangerous-actions-blocker.sh: $1" >&2
  exit 2
}

# --- Recursive delete of a root target: /, /*, ~, $HOME ----------------------
# Anchored on purpose. A substring test for "rm -rf /" matches every absolute
# path and would block legitimate deletes like `rm -rf ./dist` or /tmp/build.
# Tolerates flag order (-rf, -fr, -r -f, --recursive --force) and quoting.
RM_ROOT='(^|[;&|(]|[[:space:]])[[:space:]]*rm([[:space:]]+(-[a-zA-Z]+|--[a-zA-Z-]+))*[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]+(-[a-zA-Z]+|--[a-zA-Z-]+))*[[:space:]]+['\''"]?(/|~|\$\{?HOME\}?)[*/]*['\''"]?[[:space:]]*($|[;&|])'
grep -qE "$RM_ROOT" <<<"$CMD" && block "recursive delete of a root target (/, /*, ~, \$HOME)"

# --- Irreversible disk / filesystem writes -----------------------------------
for pat in 'dd if=' 'mkfs' '> /dev/sd' '> /dev/nvme' '--no-preserve-root' ':(){:|:&};:'; do
  [[ "$CMD" == *"$pat"* ]] && block "destructive command pattern '$pat'"
done
grep -qE 'chmod[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*777[[:space:]]+/([[:space:]]|$)' <<<"$CMD" \
  && block "chmod 777 on /"

# --- AGENTS.md §7: never force-push a shared branch --------------------------
SHARED='(main|master|develop)'
grep -qE "git[[:space:]]+push[^;&|]*(-f\b|--force(-with-lease)?\b)[^;&|]*\b$SHARED\b" <<<"$CMD" \
  && block "force-push to a shared branch (AGENTS.md §7)"
grep -qE "git[[:space:]]+push[^;&|]*[[:space:]]\+$SHARED\b" <<<"$CMD" \
  && block "force-push (+refspec) to a shared branch (AGENTS.md §7)"
# `git push -f` / `git push -f origin` with no branch named pushes the current
# branch — block it when that branch is a shared one.
if grep -qE 'git[[:space:]]+push[^;&|]*(-f\b|--force(-with-lease)?\b)' <<<"$CMD"; then
  ARGS=$(grep -oE 'git[[:space:]]+push[^;&|]*' <<<"$CMD" | head -1 | sed -E 's/^git[[:space:]]+push//')
  POSITIONAL=$(tr -s '[:space:]' '\n' <<<"$ARGS" | grep -cvE '^(-|$)')
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  [[ "$POSITIONAL" -le 1 && "$BRANCH" =~ ^$SHARED$ ]] \
    && block "force-push of the current branch '$BRANCH' (AGENTS.md §7)"
fi

# --- Commit hooks are the secret scanner: never skip them --------------------
# Agents reach for these when a hook fails; the fix is the failure, not the hook.
# Quoted text is dropped first so a commit message mentioning "-n" isn't a match.
UNQUOTED=$(sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g" <<<"$CMD")
grep -qE 'git[[:space:]]+[^;&|]*--no-verify\b' <<<"$UNQUOTED" \
  && block "--no-verify skips the commit hooks (secret scan) — fix the failure instead"
grep -qE 'git[[:space:]]+commit\b[^;&|]*[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' <<<"$UNQUOTED" \
  && block "git commit -n skips the commit hooks (secret scan) — fix the failure instead"
grep -qE 'git[[:space:]]+(-c[[:space:]]*core\.hooksPath|config[^;&|]*core\.hooksPath)' <<<"$CMD" \
  && block "overriding core.hooksPath disables the commit hooks"
grep -qE '(^|[;&|[:space:]])SKIP=[^[:space:]]*[[:space:]]+([^;&|]*[[:space:]])?git[[:space:]]+commit\b' <<<"$CMD" \
  && block "SKIP=… disables pre-commit hooks — fix the failure instead"

# --- Publishing is a human decision ------------------------------------------
grep -qE '\b(npm|pnpm|yarn)[[:space:]]+publish\b|\bcargo[[:space:]]+publish\b|\btwine[[:space:]]+upload\b' <<<"$CMD" \
  && block "package publication requires a human — run it yourself"

# Deliberately NOT blocked: `curl … | sh`. scripts/setup.sh installs its
# toolchain that way, so blocking it would break this template's own bootstrap.

exit 0
