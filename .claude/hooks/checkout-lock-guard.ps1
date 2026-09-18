# checkout-lock-guard.ps1 — PreToolUse hook (Issue #217)
#
# Enforcement duro del lock de checkout de agentic-dev-loop (skills/agentic-dev-loop/scripts/
# with-checkout-lock.sh). Sin este hook, el lock queda como una convencion que el dev-runner
# debe "acordarse" de respetar -- mismo patron de riesgo que ya motivo git-guard.ps1/
# pr-base-guard.ps1 (regla en texto ignorada hasta que se convirtio en hook).
#
# Diseño (deliberado, ver notas abajo): este hook SOLO actua cuando hay un lock activo
# (.git/aura-checkout.lock existe). Si nadie adquirio el lock, el hook es un no-op -- no
# interfiere con el trabajo manual normal de una sesion que nunca usa with-checkout-lock.sh
# (el caso de la gran mayoria de sesiones interactivas de este harness). Cuando el lock SI
# esta activo, cualquier operacion de git que cambie de rama o persista cambios (checkout,
# switch, commit, push) proveniente de una sesion DISTINTA a la que sostiene el lock queda
# bloqueada -- el session_id que Claude Code inyecta en cada evento PreToolUse (campo
# `session_id`, confirmado en la referencia oficial de hooks) es el identificador real de
# "agente/sesion actual" que with-checkout-lock.sh escribe en el archivo owner.
#
# Nota de alcance: no distingue "la propia sesion corriendo otro comando legitimo" de
# "la propia sesion tratando de saltarse el flujo del lock desde otro Bash" -- ambos casos
# comparten session_id y quedan permitidos por diseño, porque el proceso dueño del lock es
# justamente esa sesion. El escenario que este hook previene es el de Issue #217 (evidencia
# real): OTRA sesion/agente concurrente ejecutando git checkout sobre el mismo checkout
# fisico mientras el dueño del lock trabaja.

function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "checkout-lock-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada mas que hacer -- no debe bloquear el flujo.
    }
}

function Get-LockOwnerLine {
    $ownerPath = ".git/aura-checkout.lock/owner"
    if (-not (Test-Path $ownerPath)) { return $null }
    try {
        return (Get-Content $ownerPath -Raw).Trim()
    } catch {
        return $null
    }
}

function Test-CheckoutLockGuard {
    param([string]$Command, [string]$SessionId)

    $mutatesGit = $Command -match '\bgit\s+(checkout|switch|commit|push)\b'
    if (-not $mutatesGit) { return $null }

    $ownerLine = Get-LockOwnerLine
    if (-not $ownerLine) { return $null }  # sin lock activo -- fuera de alcance de este hook

    $ownerToken = "session-$SessionId"
    if (-not $SessionId -or $ownerLine -notmatch [regex]::Escape($ownerToken)) {
        $reason = "checkout-lock-guard: lock de checkout activo por otro agente/sesion ($ownerLine). Esperar a que libere el lock antes de correr operaciones de git que cambien de rama o persistan cambios."
        return @{ decision = "block"; reason = $reason }
    }

    return $null
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

    $sessionId = ""
    if ($input_json.session_id) {
        $sessionId = $input_json.session_id
    }

    $result = Test-CheckoutLockGuard -Command $command -SessionId $sessionId
    if ($result) {
        $response = @{ decision = $result.decision; reason = $result.reason } | ConvertTo-Json -Compress
        Write-Output $response
        Write-GuardLog "BLOCK: $($result.reason)"
        exit 2
    }

    exit 0
}
