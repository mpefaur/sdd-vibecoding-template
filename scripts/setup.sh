#!/usr/bin/env bash
#
# sdd-vibecoding-template — one-shot toolchain bootstrap (Linux / macOS / WSL).
#
#   ./scripts/setup.sh [--skip-rtk] [--skip-speckit] [--with-caveman] [--agent NAME]
#
# Idempotent by design: every step checks before it acts, so re-running is safe and
# never clobbers your constitution, specs, or agent config.
#
#   1. uv                2. specify-cli        3. Spec Kit init (only if missing)
#   4. RTK               5. rtk init (agent)   6. pre-commit + commit hooks
#   7. Caveman (opt-in)  8. verification      9. summary
#
# Versions are pinned below; Dependabot does not see them, so bump them by hand.
#
set -uo pipefail

SPECKIT_VERSION="1.1.1"
RTK_VERSION="v0.51.0"
CAVEMAN_VERSION="v3.1.0"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SKIP_RTK=0; WITH_CAVEMAN=0; SKIP_SPECKIT=0; AGENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-rtk)     SKIP_RTK=1 ;;
    --with-caveman) WITH_CAVEMAN=1 ;;
    --skip-speckit) SKIP_SPECKIT=1 ;;
    --agent)        AGENT="${2:-}"; shift ;;
    -h|--help)      sed -n '2,20p' "$0" | sed 's/^#\s\?//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# ── output helpers ────────────────────────────────────────────────────────────
if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'
else B=""; G=""; Y=""; R=""; D=""; N=""; fi
step() { printf '\n%s▸ %s%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
skip() { printf '  %s•%s %s %s(skipped)%s\n' "$D" "$N" "$1" "$D" "$N"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; }
fail() { printf '  %s✗%s %s\n' "$R" "$N" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

WARNINGS=0
note_warn() { WARNINGS=$((WARNINGS + 1)); warn "$1"; }

# Tools installed by uv/cargo/npm land here; make them visible to this script run.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

printf '%s╭──────────────────────────────────────────────╮%s\n' "$B" "$N"
printf '%s│  sdd-vibecoding-template — setup             │%s\n' "$B" "$N"
printf '%s╰──────────────────────────────────────────────╯%s\n' "$B" "$N"
printf '%s  %s%s\n' "$D" "$REPO_ROOT" "$N"

# ── 1. uv ─────────────────────────────────────────────────────────────────────
step "1/9  uv (Python toolchain manager)"
if have uv; then
  ok "uv already installed ($(uv --version 2>/dev/null))"
else
  echo "  installing uv…"
  if curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; then
    export PATH="$HOME/.local/bin:$PATH"
    have uv && ok "uv installed ($(uv --version 2>/dev/null))" || fail "uv installed but not on PATH"
  else
    fail "uv install failed — see https://docs.astral.sh/uv/getting-started/installation/"
  fi
fi

# ── 2. specify-cli ────────────────────────────────────────────────────────────
step "2/9  Spec Kit CLI (specify)"
if [ "$SKIP_SPECKIT" = 1 ]; then
  skip "specify-cli"
elif ! have uv; then
  note_warn "uv unavailable — cannot install specify-cli"
else
  # `uv tool install --force` both installs and upgrades: idempotent either way.
  if uv tool install "specify-cli==$SPECKIT_VERSION" --force >/dev/null 2>&1; then
    ok "specify-cli ready ($(specify --version 2>/dev/null | tail -1))"
  else
    fail "specify-cli install failed — retry: uv tool install specify-cli==$SPECKIT_VERSION --force"
  fi
fi

# ── 3. Spec Kit project init ──────────────────────────────────────────────────
step "3/9  Spec Kit project structure"
if [ "$SKIP_SPECKIT" = 1 ]; then
  skip "specify init"
elif [ -f .specify/memory/constitution.md ]; then
  # Already initialized. Never re-run init here: it would overwrite the constitution.
  ok ".specify/ already initialized — left untouched"
elif ! have specify; then
  note_warn "specify not on PATH — run manually: specify init . --integration claude"
else
  if specify init . --integration claude --script sh --ignore-agent-tools --force >/dev/null 2>&1; then
    ok "Spec Kit initialized (claude integration)"
  else
    fail "specify init failed — run it manually to see the error"
  fi
fi

# ── 4. RTK ────────────────────────────────────────────────────────────────────
step "4/9  RTK (token-efficient CLI proxy)"
if [ "$SKIP_RTK" = 1 ]; then
  skip "RTK"
elif have rtk; then
  ok "rtk already installed ($(rtk --version 2>/dev/null | head -1))"
else
  echo "  installing rtk…"
  if have brew && brew install rtk >/dev/null 2>&1; then
    ok "rtk installed via Homebrew"
  elif curl -fsSL "https://raw.githubusercontent.com/rtk-ai/rtk/$RTK_VERSION/install.sh" | RTK_VERSION="$RTK_VERSION" sh >/dev/null 2>&1; then
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    ok "rtk installed via install.sh ($RTK_VERSION)"
  elif have cargo && cargo install --git https://github.com/rtk-ai/rtk --tag "$RTK_VERSION" >/dev/null 2>&1; then
    ok "rtk installed via cargo"
  else
    note_warn "rtk install failed — see https://github.com/rtk-ai/rtk (agents fall back to raw commands)"
  fi
fi

# ── 5. rtk init for the detected agent ────────────────────────────────────────
step "5/9  rtk init (agent integration)"
if [ "$SKIP_RTK" = 1 ] || ! have rtk; then
  skip "rtk init"
else
  # Explicit --agent wins; otherwise detect from what's present in the repo/machine.
  if [ -z "$AGENT" ]; then
    if   [ -d .claude ]   || have claude;       then AGENT="claude"
    elif [ -d .cursor ]   || have cursor-agent; then AGENT="cursor"
    elif [ -d .clinerules ];                    then AGENT="cline"
    elif have gemini;                           then AGENT="gemini"
    elif have codex;                            then AGENT="codex"
    else                                             AGENT="claude"
    fi
  fi
  ok "detected agent: $AGENT"
  # -g = global config; --auto-patch = non-interactive. Re-running is a no-op patch.
  case "$AGENT" in
    claude)         RTK_ARGS=(-g --auto-patch) ;;
    copilot)        RTK_ARGS=(-g --copilot --auto-patch) ;;
    gemini)         RTK_ARGS=(-g --gemini --auto-patch) ;;
    codex)          RTK_ARGS=(-g --codex --auto-patch) ;;
    cline|kilocode|antigravity|kimi|hermes)
                    RTK_ARGS=(--agent "$AGENT" --auto-patch) ;;
    *)              RTK_ARGS=(-g --agent "$AGENT" --auto-patch) ;;
  esac
  if rtk init "${RTK_ARGS[@]}" >/dev/null 2>&1; then
    ok "rtk init done (rtk init ${RTK_ARGS[*]})"
  else
    note_warn "rtk init failed — run manually: rtk init ${RTK_ARGS[*]}"
  fi
fi

# ── 6. pre-commit + commit hooks ──────────────────────────────────────────────
step "6/9  pre-commit (Betterleaks secret scan on every commit)"
if ! have pre-commit; then
  if have uv && uv tool install pre-commit >/dev/null 2>&1; then
    ok "pre-commit installed ($(pre-commit --version 2>/dev/null))"
  else
    note_warn "pre-commit install failed — run: uv tool install pre-commit"
  fi
else
  ok "pre-commit already installed ($(pre-commit --version 2>/dev/null))"
fi
if have pre-commit && git rev-parse --git-dir >/dev/null 2>&1; then
  # --install-hooks fetches Betterleaks now, so the first commit isn't the slow one.
  if pre-commit install --install-hooks >/dev/null 2>&1; then
    ok "commit hooks installed (.git/hooks/pre-commit)"
  else
    note_warn "pre-commit install failed — run: pre-commit install --install-hooks"
  fi
fi

# ── 7. Caveman (opt-in) ───────────────────────────────────────────────────────
# Opt-in since v3: its own evals on current models show ~3% fewer output tokens than
# a plain "be concise" (ultracave: ~35%) for ~1k extra input tokens per call, and the
# CLI/hooks send usage telemetry by default. DO_NOT_TRACK=1 keeps that off.
step "7/9  Caveman (opt-in prose compression)"
if [ "$WITH_CAVEMAN" != 1 ]; then
  skip "Caveman (pass --with-caveman to install)"
elif ! have node; then
  note_warn "Node ≥18 required by Caveman and not found — skipping"
else
  if curl -fsSL "https://raw.githubusercontent.com/JuliusBrussee/caveman/$CAVEMAN_VERSION/install.sh" | DO_NOT_TRACK=1 bash >/dev/null 2>&1; then
    ok "Caveman $CAVEMAN_VERSION installed — set DO_NOT_TRACK=1 in your shell profile or run 'caveman telemetry off'"
  else
    note_warn "Caveman install failed — see https://github.com/JuliusBrussee/caveman"
  fi
fi

# ── 8. Verification ───────────────────────────────────────────────────────────
step "8/9  Verification"
check() { # name, condition-command
  if eval "$2" >/dev/null 2>&1; then ok "$1"; else note_warn "$1 — MISSING"; fi
}
check "uv"                          "have uv"
check "specify CLI"                 "have specify"
check ".specify/memory/constitution.md" "[ -f .specify/memory/constitution.md ]"
check ".specify/templates/"         "[ -d .specify/templates ]"
check "Claude skills (.claude/skills)"   "[ -d .claude/skills ]"
check "verify skill (.claude/skills/verify)" "[ -f .claude/skills/verify/SKILL.md ]"
check "scripts/verify.sh"           "[ -x scripts/verify.sh ]"
check "Cursor rules (.cursor/rules)"     "[ -f .cursor/rules/karpathy.mdc ]"
check "Cline rules (.clinerules)"        "[ -f .clinerules/00-agents.md ]"
check "AGENTS.md"                   "[ -f AGENTS.md ]"
check "CLAUDE.md"                   "[ -f CLAUDE.md ]"
check "pre-commit"                  "have pre-commit"
[ "$SKIP_RTK" = 1 ]     || check "rtk"     "have rtk"
[ "$WITH_CAVEMAN" = 1 ] && check "node ≥18 (Caveman)" "have node"

# ── 9. Summary ────────────────────────────────────────────────────────────────
step "9/9  Summary"
if [ "$WARNINGS" -eq 0 ]; then
  printf '  %sEverything is ready.%s\n' "$G" "$N"
else
  printf '  %s%d item(s) need attention — see the ! lines above.%s\n' "$Y" "$WARNINGS" "$N"
fi
cat <<EOF

  ${B}Next steps${N}
    1. Open the repo in your agent (Claude Code, Cursor, Cline…).
    2. ${B}/kickoff <what you want to build>${N} — fills AGENTS.md §1 and scripts/verify.sh
    3. ${B}/speckit-specify${N} → ${B}/speckit-clarify${N} → ${B}/speckit-plan${N} → ${B}/speckit-tasks${N}
       → ${B}/speckit-analyze${N} → ${B}/speckit-implement${N} ⇄ ${B}/speckit-converge${N}

  ${B}Token savings${N}
    rtk gain          token savings report
    rtk discover      commands still run the expensive way

  ${D}If PATH complains, add: export PATH="\$HOME/.local/bin:\$PATH"${N}

EOF
exit 0
