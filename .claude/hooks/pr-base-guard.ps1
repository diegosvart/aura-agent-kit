# pr-base-guard.ps1 — PreToolUse hook
#
# Intercepta comandos Bash y PowerShell antes de ejecutarse.
# Bloquea `gh pr create`, `gh pr edit --base` y `gh pr merge` cuando la rama base
# resultante no es `develop`, salvo la excepcion exacta base=main + head=develop
# (paso 'promote' de cut-release.sh, la unica forma legitima de apuntar a main).
#
# Por que existe: Issue #148 tuvo 3 incidentes reales de `gh pr create` sin --base
# explicito cayendo al default branch del repo (main), saltandose develop por completo.
# Ningun chequeo existente (informativo, post-hoc) lo bloqueaba antes del merge. Mismo
# patron que git-guard.ps1/sensitive-data-guard.ps1: enforcement duro a nivel de hook,
# no solo texto en agents/github.md. Ver docs/aura/specs/2026-09-06-flujo-respetado-orchestrator.md
# (Frente A) para el rationale completo.
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "gh pr create ..." } }
#
# Estructura: funciones testeables (pr-base-guard.Tests.ps1 las dot-sourcea y mockea
# Get-OriginRepoSlug/Resolve-PrBaseHead) + un punto de entrada al final que solo corre
# cuando el script se invoca directamente, no al dot-source.

function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "pr-base-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada mas que hacer -- no debe bloquear el flujo.
    }
}

function Get-CommandFlagValue {
    param([string]$Command, [string]$FlagName)
    if ($Command -match "--$FlagName(?:\s+|=)(""[^""]*""|'[^']*'|\S+)") {
        return $Matches[1].Trim('"').Trim("'")
    }
    return $null
}

function Get-OriginRepoSlug {
    try {
        $url = (git remote get-url origin 2>$null)
        if (-not $url) { return $null }
        if ($url -match '[:/]([^/:]+)/([^/]+?)(\.git)?$') {
            return "$($Matches[1])/$($Matches[2])"
        }
    } catch {
        # sin remoto resoluble -- tratado como "no se pudo determinar", ver Test-PrBaseGuard
    }
    return $null
}

function Resolve-PrBaseHead {
    param([string]$Target, [string]$RepoSlug)
    $ghArgs = @('pr', 'view')
    if ($Target) { $ghArgs += $Target }
    $ghArgs += @('--json', 'baseRefName,headRefName')
    if ($RepoSlug) { $ghArgs += @('--repo', $RepoSlug) }
    try {
        $json = & gh @ghArgs 2>$null
        if (-not $json) { return $null }
        return $json | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Test-PrBaseGuard {
    param([string]$Command)

    if ($Command -notmatch '\bgh\s+pr\s+(create|edit|merge)\b') { return $null }
    $subcommand = $Matches[1]

    $repoFlag = Get-CommandFlagValue -Command $Command -FlagName 'repo'
    $originRepo = Get-OriginRepoSlug
    if ($repoFlag -and $originRepo -and ($repoFlag -ne $originRepo)) {
        # --repo apunta a un repo distinto al del checkout actual -- fuera de alcance del hook.
        return $null
    }

    if ($subcommand -eq 'merge') {
        $target = $null
        if ($Command -match '\bgh\s+pr\s+merge\s+(?!--)(\S+)') {
            $target = $Matches[1]
        }
        $prInfo = Resolve-PrBaseHead -Target $target -RepoSlug $repoFlag
        if (-not $prInfo) {
            Write-GuardLog "FAIL-OPEN: no se pudo resolver base/head via 'gh pr view' para: $Command"
            return $null
        }
        $base = $prInfo.baseRefName
        $head = $prInfo.headRefName
    } else {
        $base = Get-CommandFlagValue -Command $Command -FlagName 'base'
        $head = Get-CommandFlagValue -Command $Command -FlagName 'head'
        if (-not $base) {
            if ($subcommand -eq 'create') {
                # gh pr create sin --base cae al default branch del repo (main) -- bloquear.
                $base = '__missing__'
            } else {
                # gh pr edit sin --base no toca la rama base -- fuera de alcance.
                return $null
            }
        }
    }

    if ($base -eq 'develop') { return $null }
    if ($base -eq 'main' -and $head -eq 'develop') { return $null }

    $reason = "pr-base-guard: 'gh pr $subcommand' bloqueado -- base '$base' fuera de develop (unica excepcion: base=main + head=develop, release promote). Ver agents/github.md."
    return @{ decision = 'block'; reason = $reason }
}

# --- Punto de entrada (solo al ejecutar directamente, no al dot-source para tests) ---
if ($MyInvocation.InvocationName -ne '.') {
    $input_json = $null
    try {
        $raw = [Console]::In.ReadToEnd()
        $input_json = $raw | ConvertFrom-Json
    } catch {
        Write-GuardLog "FAIL-OPEN: No se pudo parsear stdin como JSON ($($_.Exception.Message))."
        exit 0
    }

    $command = ""
    if ($input_json.tool_input.command) {
        $command = $input_json.tool_input.command
    }

    if (-not $command) { exit 0 }

    $result = Test-PrBaseGuard -Command $command
    if ($result) {
        $response = @{ decision = $result.decision; reason = $result.reason } | ConvertTo-Json -Compress
        Write-Output $response
        Write-GuardLog "BLOCK: $($result.reason)"
        exit 2
    }

    exit 0
}
