# git-guard.ps1 — PreToolUse hook
#
# Intercepta comandos Bash y PowerShell antes de ejecutarse.
# Bloquea git commit y git push cuando la rama activa es develop o main.
#
# Por qué existe: las reglas en markdown (harness-core.md, AGENTS.md) son soft.
# Este hook es enforcement duro al nivel del harness — el modelo no puede ignorarlo.
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }
#
# Hipotesis (P4): un commit directo a develop pasó sin bloqueo real en una sesión — se sospecha
# que uno de los dos catch de abajo (parseo de stdin, o resolución de `git`) falló en silencio
# (fail-open) sin dejar rastro. Mantenemos el fail-open (bloquear todo el flujo si el hook mismo
# falla sería peor que no bloquear ese commit puntual), pero ahora queda logueado para poder
# diagnosticarlo la próxima vez en vez de que el fallo sea invisible.
function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "git-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] FAIL-OPEN: $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada más que hacer — no debe bloquear el flujo.
    }
}

$input_json = $null
try {
    $raw = [Console]::In.ReadToEnd()
    $input_json = $raw | ConvertFrom-Json
} catch {
    Write-GuardLog "No se pudo parsear stdin como JSON ($($_.Exception.Message)) — hook no evaluó el comando."
    exit 0
}

# Extraer el comando según el tool
$command = ""
if ($input_json.tool_input.command) {
    $command = $input_json.tool_input.command
}

if (-not $command) {
    exit 0
}

# Verificar si el comando involucra git commit o git push
$is_commit = $command -match '\bgit\s+commit\b'
$is_push   = $command -match '\bgit\s+push\b'

if (-not ($is_commit -or $is_push)) {
    exit 0
}

# Obtener rama actual
$branch = ""
try {
    $branch = (git branch --show-current 2>$null).Trim()
} catch {
    Write-GuardLog "No se pudo resolver 'git branch --show-current' ($($_.Exception.Message)) — comando '$command' no evaluado."
    exit 0
}

$protected = @("develop", "main")

if ($branch -in $protected) {
    $operation = if ($is_commit) { "commit" } else { "push" }
    $response = @{
        decision = "block"
        reason   = "git-guard: 'git $operation' bloqueado en rama '$branch'. Crear una feature branch antes de commitear. Ejemplo: git checkout -b feature/issue-N-descripcion"
    } | ConvertTo-Json -Compress
    Write-Output $response
    exit 2
}

exit 0
