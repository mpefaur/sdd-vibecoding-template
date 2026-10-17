<#
.SYNOPSIS
    sdd-vibecoding-template — one-shot toolchain bootstrap (Windows, PowerShell 5.1+).

.DESCRIPTION
    Idempotent by design: every step checks before it acts, so re-running is safe and
    never clobbers your constitution, specs, or agent config.

      1. uv                2. specify-cli        3. Spec Kit init (only if missing)
      4. RTK               5. rtk init (agent)   6. pre-commit + commit hooks
      7. Caveman (opt-in)  8. verification       9. summary

    Versions are pinned below; Dependabot does not see them, so bump them by hand.

.EXAMPLE
    .\scripts\setup.ps1
    .\scripts\setup.ps1 -SkipRtk -Agent cursor
    .\scripts\setup.ps1 -WithCaveman
#>
[CmdletBinding()]
param(
    [switch]$SkipRtk,
    [switch]$WithCaveman,
    [switch]$SkipSpeckit,
    [string]$Agent = ''
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'   # much faster Invoke-WebRequest

$SpeckitVersion = '1.1.1'
$RtkVersion     = 'v0.51.0'
$CavemanVersion = 'v3.1.0'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# ── output helpers ────────────────────────────────────────────────────────────
$script:Warnings = 0
function Step($m) { Write-Host "`n> $m" -ForegroundColor White }
function Ok($m)   { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Skip($m) { Write-Host "  [--]   $m (skipped)" -ForegroundColor DarkGray }
function Warn($m) { $script:Warnings++; Write-Host "  [warn] $m" -ForegroundColor Yellow }
function Fail($m) { $script:Warnings++; Write-Host "  [fail] $m" -ForegroundColor Red }
function Have($c) { $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }

# Tools installed by uv/cargo land here; make them visible for this session.
$env:PATH = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:PATH"

Write-Host "+----------------------------------------------+" -ForegroundColor White
Write-Host "|  sdd-vibecoding-template - setup             |" -ForegroundColor White
Write-Host "+----------------------------------------------+" -ForegroundColor White
Write-Host "  $RepoRoot" -ForegroundColor DarkGray

# ── 1. uv ─────────────────────────────────────────────────────────────────────
Step '1/9  uv (Python toolchain manager)'
if (Have 'uv') {
    Ok "uv already installed ($(uv --version 2>$null))"
} else {
    Write-Host '  installing uv...'
    try {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression | Out-Null
        $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
        if (Have 'uv') { Ok "uv installed ($(uv --version 2>$null))" }
        else { Fail 'uv installed but not on PATH' }
    } catch {
        Fail 'uv install failed - see https://docs.astral.sh/uv/getting-started/installation/'
    }
}

# ── 2. specify-cli ────────────────────────────────────────────────────────────
Step '2/9  Spec Kit CLI (specify)'
if ($SkipSpeckit) {
    Skip 'specify-cli'
} elseif (-not (Have 'uv')) {
    Warn 'uv unavailable - cannot install specify-cli'
} else {
    # `uv tool install --force` both installs and upgrades: idempotent either way.
    uv tool install "specify-cli==$SpeckitVersion" --force *> $null
    if (Have 'specify') { Ok "specify-cli ready ($SpeckitVersion)" }
    else { Fail "specify-cli install failed - retry: uv tool install specify-cli==$SpeckitVersion --force" }
}

# ── 3. Spec Kit project init ──────────────────────────────────────────────────
Step '3/9  Spec Kit project structure'
if ($SkipSpeckit) {
    Skip 'specify init'
} elseif (Test-Path '.specify/memory/constitution.md') {
    # Already initialized. Never re-run init here: it would overwrite the constitution.
    Ok '.specify/ already initialized - left untouched'
} elseif (-not (Have 'specify')) {
    Warn 'specify not on PATH - run manually: specify init . --integration claude'
} else {
    specify init . --integration claude --script ps --ignore-agent-tools --force *> $null
    if (Test-Path '.specify/memory/constitution.md') { Ok 'Spec Kit initialized (claude integration)' }
    else { Fail 'specify init failed - run it manually to see the error' }
}

# ── 4. RTK ────────────────────────────────────────────────────────────────────
Step '4/9  RTK (token-efficient CLI proxy)'
if ($SkipRtk) {
    Skip 'RTK'
} elseif (Have 'rtk') {
    Ok 'rtk already installed'
} else {
    Write-Host '  installing rtk...'
    $installed = $false
    if (Have 'winget') {
        winget install --id rtk-ai.rtk --accept-source-agreements --accept-package-agreements *> $null
        $installed = Have 'rtk'
    }
    if (-not $installed -and (Have 'cargo')) {
        cargo install --git https://github.com/rtk-ai/rtk --tag $RtkVersion *> $null
        $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
        $installed = Have 'rtk'
    }
    if ($installed) { Ok 'rtk installed' }
    else { Warn 'rtk not installed - grab a Windows binary from https://github.com/rtk-ai/rtk/releases (agents fall back to raw commands)' }
}

# ── 5. rtk init for the detected agent ────────────────────────────────────────
Step '5/9  rtk init (agent integration)'
if ($SkipRtk -or -not (Have 'rtk')) {
    Skip 'rtk init'
} else {
    # Explicit -Agent wins; otherwise detect from what's present in the repo/machine.
    if (-not $Agent) {
        if     ((Test-Path '.claude')     -or (Have 'claude'))       { $Agent = 'claude' }
        elseif ((Test-Path '.cursor')     -or (Have 'cursor-agent')) { $Agent = 'cursor' }
        elseif (Test-Path '.clinerules')                             { $Agent = 'cline'  }
        elseif (Have 'gemini')                                       { $Agent = 'gemini' }
        elseif (Have 'codex')                                        { $Agent = 'codex'  }
        else                                                         { $Agent = 'claude' }
    }
    Ok "detected agent: $Agent"
    # -g = global config; --auto-patch = non-interactive. Re-running is a no-op patch.
    switch ($Agent) {
        'claude'                                                  { $rtkArgs = @('-g','--auto-patch') }
        'copilot'                                                 { $rtkArgs = @('-g','--copilot','--auto-patch') }
        'gemini'                                                  { $rtkArgs = @('-g','--gemini','--auto-patch') }
        'codex'                                                   { $rtkArgs = @('-g','--codex','--auto-patch') }
        { $_ -in 'cline','kilocode','antigravity','kimi','hermes' } { $rtkArgs = @('--agent',$Agent,'--auto-patch') }
        default                                                   { $rtkArgs = @('-g','--agent',$Agent,'--auto-patch') }
    }
    rtk init @rtkArgs *> $null
    if ($LASTEXITCODE -eq 0) { Ok "rtk init done (rtk init $($rtkArgs -join ' '))" }
    else { Warn "rtk init failed - run manually: rtk init $($rtkArgs -join ' ')" }
}

# ── 6. pre-commit + commit hooks ──────────────────────────────────────────────
Step '6/9  pre-commit (Betterleaks secret scan on every commit)'
if (-not (Have 'pre-commit') -and (Have 'uv')) { uv tool install pre-commit *> $null }
if (Have 'pre-commit') {
    Ok 'pre-commit ready'
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -eq 0) {
        # --install-hooks fetches Betterleaks now, so the first commit isn't the slow one.
        pre-commit install --install-hooks *> $null
        if ($LASTEXITCODE -eq 0) { Ok 'commit hooks installed (.git/hooks/pre-commit)' }
        else { Warn 'pre-commit install failed - run: pre-commit install --install-hooks' }
    }
} else {
    Warn 'pre-commit not installed - run: uv tool install pre-commit'
}

# ── 7. Caveman (opt-in) ───────────────────────────────────────────────────────
# Opt-in since v3: its own evals on current models show ~3% fewer output tokens than
# a plain "be concise" (ultracave: ~35%) for ~1k extra input tokens per call, and the
# CLI/hooks send usage telemetry by default. DO_NOT_TRACK=1 keeps that off.
Step '7/9  Caveman (opt-in prose compression)'
if (-not $WithCaveman) {
    Skip 'Caveman (pass -WithCaveman to install)'
} elseif (-not (Have 'node')) {
    Warn 'Node >= 18 required by Caveman and not found - skipping'
} else {
    try {
        $env:DO_NOT_TRACK = '1'
        Invoke-RestMethod "https://raw.githubusercontent.com/JuliusBrussee/caveman/$CavemanVersion/install.ps1" |
            Invoke-Expression | Out-Null
        Ok "Caveman $CavemanVersion installed - set DO_NOT_TRACK=1 permanently or run 'caveman telemetry off'"
    } catch {
        Warn 'Caveman install failed - see https://github.com/JuliusBrussee/caveman'
    }
}

# ── 8. Verification ───────────────────────────────────────────────────────────
Step '8/9  Verification'
function Check($name, [scriptblock]$cond) {
    if (& $cond) { Ok $name } else { Warn "$name - MISSING" }
}
Check 'uv'                                   { Have 'uv' }
Check 'specify CLI'                          { Have 'specify' }
Check '.specify/memory/constitution.md'      { Test-Path '.specify/memory/constitution.md' }
Check '.specify/templates/'                  { Test-Path '.specify/templates' }
Check 'Claude skills (.claude/skills)'       { Test-Path '.claude/skills' }
Check 'verify skill (.claude/skills/verify)' { Test-Path '.claude/skills/verify/SKILL.md' }
Check 'scripts/verify.sh'                    { Test-Path 'scripts/verify.sh' }
Check 'Cursor rules (.cursor/rules)'         { Test-Path '.cursor/rules/karpathy.mdc' }
Check 'Cline rules (.clinerules)'            { Test-Path '.clinerules/00-agents.md' }
Check 'AGENTS.md'                            { Test-Path 'AGENTS.md' }
Check 'CLAUDE.md'                            { Test-Path 'CLAUDE.md' }
Check 'pre-commit'                           { Have 'pre-commit' }
if (-not $SkipRtk)     { Check 'rtk'                  { Have 'rtk' } }
if ($WithCaveman)      { Check 'node >= 18 (Caveman)' { Have 'node' } }

# ── 9. Summary ────────────────────────────────────────────────────────────────
Step '9/9  Summary'
if ($script:Warnings -eq 0) {
    Write-Host '  Everything is ready.' -ForegroundColor Green
} else {
    Write-Host "  $($script:Warnings) item(s) need attention - see the [warn]/[fail] lines above." -ForegroundColor Yellow
}
Write-Host @'

  Next steps
    1. Open the repo in your agent (Claude Code, Cursor, Cline...).
    2. /kickoff <what you want to build> - fills AGENTS.md section 1 and scripts/verify.sh
    3. /speckit-specify -> /speckit-clarify -> /speckit-plan -> /speckit-tasks
       -> /speckit-analyze -> /speckit-implement <-> /speckit-converge

  Token savings
    rtk gain          token savings report
    rtk discover      commands still run the expensive way

'@
exit 0
