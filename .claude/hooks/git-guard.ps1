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

$input_json = $null
try {
    $raw = [Console]::In.ReadToEnd()
    $input_json = $raw | ConvertFrom-Json
} catch {
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
