# gh-account-guard.ps1 — PreToolUse hook
#
# Intercepta comandos Bash y PowerShell antes de ejecutarse.
# Bloquea `git push`, `gh pr create`, y `gh repo edit` cuando la cuenta activa de `gh auth status --active`
# no coincide con la cuenta esperada declarada en `.agent/memory/repo-classification.json`.
#
# Por qué existe: Issue #323 — incidente real donde la cuenta gh cambió de `diegosvart` a `ServiciosTIebi`
# en medio de una sesión, sin bloqueo de operaciones de escritura remota. El cambio de cuenta implica
# cambio de permisos (admin:enterprise, admin:org, delete_repo) — no detectar esto es un riesgo de seguridad.
#
# Si `expected_gh_account` no está declarado en repo-classification.json: fail-open con advertencia,
# no fail-closed (a diferencia de sensitive-data-guard.ps1 que es fail-closed por ausencia total de
# clasificación). Repos clasificados antes de este cambio deben poder seguir operando hasta que se complete
# el campo nuevo.
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "git push ..." } }
#
# Estructura: funciones testeables (gh-account-guard.Tests.ps1 las dot-sourcea y mockea
# Get-ExpectedGhAccount/Get-ActiveGhAccount) + un punto de entrada al final que solo corre
# cuando el script se invoca directamente, no al dot-source.

function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "gh-account-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada más que hacer — no debe bloquear el flujo.
    }
}

function Get-ProjectRoot {
    try {
        return (git rev-parse --show-toplevel 2>$null).Trim()
    } catch {
        return $null
    }
}

function Get-RepoClassification {
    param([string]$ProjectRoot)
    $classificationPath = Join-Path $ProjectRoot ".agent/memory/repo-classification.json"
    if (-not (Test-Path $classificationPath)) {
        return $null
    }
    try {
        $content = Get-Content -Path $classificationPath -Raw
        return $content | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-ExpectedGhAccount {
    param([string]$ProjectRoot)
    $classification = Get-RepoClassification -ProjectRoot $ProjectRoot
    if ($classification -and $classification.expected_gh_account) {
        return $classification.expected_gh_account
    }
    return $null
}

function Get-ActiveGhAccount {
    try {
        $output = & gh auth status --active 2>$null
        # Formato típico: "Logged in to github.com account diegosvart (keyring)"
        if ($output -match 'account\s+([a-zA-Z0-9\-._]+)') {
            return $Matches[1]
        }
        # Fallback: si no coincide el patrón, intenta extraer de gh api user
        $userInfo = & gh api user --jq '.login' 2>$null
        if ($userInfo) {
            return $userInfo.Trim()
        }
    } catch {
        # Si no se puede determinar la cuenta activa, tratar como no determinable
    }
    return $null
}

function Test-GhAccountGuard {
    param([string]$Command)

    # Determinar si el comando es una operación de escritura remota
    $isWriteOperation = $false
    if ($Command -match '\bgit\s+push\b') { $isWriteOperation = $true }
    if ($Command -match '\bgh\s+pr\s+create\b') { $isWriteOperation = $true }
    if ($Command -match '\bgh\s+repo\s+edit\b') { $isWriteOperation = $true }

    if (-not $isWriteOperation) {
        return $null
    }

    # Obtener raíz del proyecto y cuenta esperada
    $projectRoot = Get-ProjectRoot
    if (-not $projectRoot) {
        # Sin proyecto determinable, fail-open
        Write-GuardLog "FAIL-OPEN: no se puede determinar proyecto root"
        return $null
    }

    $expectedAccount = Get-ExpectedGhAccount -ProjectRoot $projectRoot

    # Si no hay cuenta esperada declarada: fail-open con advertencia
    if (-not $expectedAccount) {
        Write-GuardLog "WARN: expected_gh_account no declarado en repo-classification.json, permitiendo operación"
        Write-Warning "⚠️ expected_gh_account no está configurado en repo-classification.json. Se recomienda agregarlo para enforcement de cuenta."
        return $null
    }

    # Obtener cuenta activa
    $activeAccount = Get-ActiveGhAccount
    if (-not $activeAccount) {
        # No se pudo determinar la cuenta activa, fail-open (gh auth status falló)
        Write-GuardLog "FAIL-OPEN: no se puede determinar cuenta activa de gh"
        return $null
    }

    # Comparar cuentas
    if ($activeAccount -ne $expectedAccount) {
        $reason = "Account mismatch: expected '$expectedAccount' but gh is logged in as '$activeAccount'. Block write operation (git push / gh pr create / gh repo edit)."
        Write-GuardLog "BLOCK: $reason"
        return @{
            decision = 'block'
            reason = $reason
        }
    }

    # Cuentas coinciden, permitir
    return $null
}

# ============================================================================
# Entry point: solo corre cuando el script se invoca directamente, no al dot-source
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $input_json = [System.Console]::In.ReadToEnd()
        $input = $input_json | ConvertFrom-Json

        $command = $input.tool_input.command
        $result = Test-GhAccountGuard -Command $command

        if ($result -and $result.decision -eq 'block') {
            Write-GuardLog "BLOCK: $($result.reason)"
            Write-Error $result.reason
            exit 1
        }

        exit 0
    } catch {
        Write-GuardLog "FAIL-OPEN: $_"
        exit 0
    }
}
