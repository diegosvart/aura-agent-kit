# sensitive-data-guard.ps1 — PreToolUse hook
#
# Intercepta comandos Bash y PowerShell antes de ejecutarse.
# Bloquea `git commit` si el contenido a commitear matchea una denylist local o un patrón
# genérico de dato sensible (RUT chileno, IP privada, credenciales).
#
# Por qué existe: `.claude/rules/sensitive-data-safety.md` documentaba el barrido como juicio
# 100% del agente — incidentes reales (crawler-mcp-diagram, gestion-documental) mostraron que
# una regla en markdown depende de que el agente la recuerde aplicar en cada commit. Mismo
# patrón que git-guard.ps1: enforcement duro a nivel de hook, no solo texto.
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }
#
# Bug conocido y corregido (gestion-documental, commit 8162e41): el hook corre ANTES de que el
# comando se ejecute, así que un comando compuesto tipo
#   echo "cliente real" > file && git add file && git commit -m x
# deja `git diff --cached` ciego al contenido recién agregado en el mismo comando (el `git add`
# todavía no corrió cuando el hook evalúa). Fix: sumar el texto crudo del comando al contenido
# inspeccionado, no confiar solo en `git diff --cached`.
function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "sensitive-data-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada más que hacer — no debe bloquear el flujo.
    }
}

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

if (-not $command) {
    exit 0
}

if ($command -notmatch '\bgit\s+commit\b') {
    exit 0
}

# Contenido a inspeccionar: staged diff + texto crudo del comando (cubre comandos compuestos)
$stagedDiff = ""
try {
    $stagedDiff = (git diff --cached 2>$null) -join "`n"
} catch {
    Write-GuardLog "FAIL-OPEN: No se pudo obtener 'git diff --cached' ($($_.Exception.Message))."
    exit 0
}

$content = "$stagedDiff`n$command"

# 1. Denylist local exacta (gitignored, un término por línea, ignora vacías y comentarios #)
$denylistPath = Join-Path (git rev-parse --show-toplevel 2>$null) ".claude/sensitive-terms.local.txt"
if (Test-Path $denylistPath) {
    $terms = Get-Content $denylistPath | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }
    foreach ($term in $terms) {
        if ($content.Contains($term.Trim())) {
            $response = @{
                decision = "block"
                reason   = "sensitive-data-guard: contenido bloqueado — coincide con un término de la denylist local (.claude/sensitive-terms.local.txt). Revisar sensitive-data-safety.md antes de continuar."
            } | ConvertTo-Json -Compress
            Write-Output $response
            Write-GuardLog "BLOCK: match en denylist local."
            exit 2
        }
    }
}

# 2. Patrones genéricos siempre activos
$patterns = @(
    @{ Name = "RUT chileno"; Regex = '\b\d{1,2}\.?\d{3}\.?\d{3}-[\dkK]\b' },
    @{ Name = "IP privada"; Regex = '\b(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b' },
    @{ Name = "credenciales"; Regex = '(?i)(password|pwd)\s*=\s*\S+' }
)

foreach ($p in $patterns) {
    if ($content -match $p.Regex) {
        $response = @{
            decision = "block"
            reason   = "sensitive-data-guard: contenido bloqueado — patrón detectado: $($p.Name). Revisar sensitive-data-safety.md antes de continuar."
        } | ConvertTo-Json -Compress
        Write-Output $response
        Write-GuardLog "BLOCK: match en patrón genérico ($($p.Name))."
        exit 2
    }
}

exit 0
