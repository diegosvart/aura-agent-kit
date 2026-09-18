# sensitive-data-guard.ps1 — PreToolUse hook
#
# Intercepta:
# 1. Comandos Bash y PowerShell antes de ejecutarse — bloquea `git commit` si el contenido a
#    commitear matchea una denylist local o un patron generico de dato sensible (RUT chileno,
#    IP privada, credenciales).
# 2. Las tools MCP de Engram que ESCRIBEN contenido persistente — mem_save, mem_save_prompt,
#    mem_capture_passive, mem_update, mem_session_summary (Issue #303 Paso 4, D4 "Enforcement
#    hibrido" de docs/aura/specs/2026-09-17-memoria-clasificacion-repos-design.md; lista
#    ampliada en el code-review de PR #307, que encontro que solo mem_save estaba cubierta) —
#    bloquea el guardado en un repo clasificado `cliente` (.agent/memory/repo-classification.json)
#    si CUALQUIER campo del tool_input (serializado completo, no una lista fija) matchea la
#    denylist/patrones. Fail-closed: clasificacion ausente, corrupta, o repo_type con un valor
#    no reconocido (typo, etc.) se bloquea igual — nunca se asume "harness"/"personal".
#
# Por que existe: `.claude/rules/sensitive-data-safety.md` documentaba el barrido como juicio
# 100% del agente — incidentes reales (crawler-mcp-diagram, gestion-documental) mostraron que
# una regla en markdown depende de que el agente la recuerde aplicar en cada commit. Mismo
# patron que git-guard.ps1: enforcement duro a nivel de hook, no solo texto. La extension a
# `mem_save` reusa el mismo matching en vez de duplicar infraestructura (denylist +
# patrones genericos), consistente con `.aura/rules/memory-classification.md` (Paso 3,
# enforcement capa 1 — instruccion) del mismo plan.
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }
#   { "tool_name": "mcp__plugin_engram_engram__mem_save", "tool_input": { "title": "...", "content": "...", ... } }
#
# Bug conocido y corregido (gestion-documental, commit 8162e41): el hook corre ANTES de que el
# comando se ejecute, asi que un comando compuesto tipo
#   echo "cliente real" > file && git add file && git commit -m x
# deja `git diff --cached` ciego al contenido recien agregado en el mismo comando (el `git add`
# todavia no corrio cuando el hook evalua). Fix: sumar el texto crudo del comando al contenido
# inspeccionado, no confiar solo en `git diff --cached`.

function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "sensitive-data-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada mas que hacer — no debe bloquear el flujo.
    }
}

function Get-RepoRoot {
    try {
        $root = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return $root
    } catch {
        return $null
    }
}

function Get-StagedDiff {
    try {
        return ((git diff --cached 2>$null) -join "`n")
    } catch {
        return ""
    }
}

function Get-DenylistPath {
    param([string]$RepoRoot)
    if (-not $RepoRoot) { return $null }
    return (Join-Path $RepoRoot ".claude/sensitive-terms.local.txt")
}

function Get-RepoClassification {
    param([string]$RepoRoot)
    if (-not $RepoRoot) { return $null }
    $path = Join-Path $RepoRoot ".agent/memory/repo-classification.json"
    if (-not (Test-Path $path)) { return $null }
    try {
        return (Get-Content $path -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

# Chequeo de contenido compartido entre el path de `git commit` y el de `mem_save` — misma
# denylist, mismos patrones genericos, nunca duplicados.
function Test-ContentAgainstSensitivePatterns {
    param(
        [string]$Content,
        [string]$DenylistPath
    )

    if ($DenylistPath -and (Test-Path $DenylistPath)) {
        $terms = Get-Content $DenylistPath | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }
        foreach ($term in $terms) {
            if ($Content.Contains($term.Trim())) {
                return @{
                    decision = "block"
                    reason   = "sensitive-data-guard: contenido bloqueado — coincide con un termino de la denylist local (.claude/sensitive-terms.local.txt). Revisar sensitive-data-safety.md antes de continuar."
                }
            }
        }
    }

    $patterns = @(
        @{ Name = "RUT chileno"; Regex = '\b\d{1,2}\.?\d{3}\.?\d{3}-[\dkK]\b' },
        @{ Name = "IP privada"; Regex = '\b(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b' },
        @{ Name = "credenciales"; Regex = '(?i)(password|pwd)\s*=\s*\S+' }
    )

    foreach ($p in $patterns) {
        if ($Content -match $p.Regex) {
            return @{
                decision = "block"
                reason   = "sensitive-data-guard: contenido bloqueado — patron detectado: $($p.Name). Revisar sensitive-data-safety.md antes de continuar."
            }
        }
    }

    return $null
}

function Test-SensitiveDataGuard {
    param([string]$Command)

    if ($Command -notmatch '\bgit\s+commit\b') { return $null }

    $stagedDiff = Get-StagedDiff
    $content = "$stagedDiff`n$Command"
    $repoRoot = Get-RepoRoot
    $denylistPath = Get-DenylistPath -RepoRoot $repoRoot

    return Test-ContentAgainstSensitivePatterns -Content $content -DenylistPath $denylistPath
}

# Tools MCP de Engram que ESCRIBEN contenido libre de forma persistente (no las de lectura
# como mem_search/mem_context/mem_get_observation) — todas caen bajo el mismo enforcement,
# no solo mem_save (hallazgo code-review PR #307: mem_save_prompt/mem_capture_passive/
# mem_update quedaban sin cubrir pese a persistir el mismo tipo de dato; hallazgo reviewer
# post-merge PR #307, Issue #309: mem_session_end/mem_judge quedaban afuera pese a persistir
# texto libre — summary/reason/evidence respectivamente).
$script:EngramWriteTools = @(
    'mem_save',
    'mem_save_prompt',
    'mem_capture_passive',
    'mem_update',
    'mem_session_summary',
    'mem_session_end',
    'mem_judge'
)

# Issue #303 Paso 4 (D4, capa hook duro): intercepta las tools de escritura de Engram de arriba
# cuando repo_type == "cliente". Fail-closed (Edge Cases de la spec): si repo-classification.json
# no existe, no parsea, o repo_type no es exactamente "harness"/"personal", se bloquea igual —
# nunca se asume "harness"/"personal" por defecto ante la duda, tampoco ante un valor invalido
# tipo typo (hallazgo code-review PR #307: "clientee" caia antes en el path permisivo).
function Test-MemorySaveGuard {
    param(
        [string]$ToolName,
        [object]$ToolInput
    )

    $shortName = $ToolName -replace '^mcp__plugin_engram_engram__', ''
    if ($script:EngramWriteTools -notcontains $shortName) { return $null }

    $repoRoot = Get-RepoRoot
    $classification = Get-RepoClassification -RepoRoot $repoRoot
    $repoType = $null
    if ($classification) { $repoType = $classification.repo_type }

    if ($repoType -eq "harness" -or $repoType -eq "personal") {
        return $null
    }

    if ($repoType -ne "cliente") {
        # Ausente, corrupto, o cualquier valor no reconocido (typo como "clientee", etc.) se
        # trata igual: fail-closed, bloqueado incondicionalmente sin evaluar contenido —
        # nunca se asume el path permisivo de "cliente" ante un valor invalido (hallazgo
        # code-review PR #307: un typo caia antes en el path que SI evalua contenido).
        return @{
            decision = "block"
            reason   = "sensitive-data-guard: $shortName bloqueado — no se pudo determinar repo_type valido (.agent/memory/repo-classification.json ausente, corrupto, o con un valor no reconocido). Fail-closed por seguridad (Issue #303 D4). Clasificar el repo (Gate de Clasificacion de Repo en protocols/session_start.md) antes de guardar en Engram."
        }
    }

    # repo_type "cliente": evaluar el contenido a guardar contra la misma denylist/patrones
    # que ya usa `git commit`. Se serializa TODO el ToolInput (no una lista fija de campos)
    # para no dejar afuera campos como observation/topic_key/session_id (hallazgo code-review
    # PR #307) ni ningun campo futuro que el schema de Engram agregue.
    $content = ""
    try {
        $content = ($ToolInput | ConvertTo-Json -Depth 10 -Compress)
    } catch {
        $content = [string]$ToolInput
    }

    $denylistPath = Get-DenylistPath -RepoRoot $repoRoot
    return Test-ContentAgainstSensitivePatterns -Content $content -DenylistPath $denylistPath
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

    $toolName = ""
    if ($input_json.tool_name) { $toolName = $input_json.tool_name }

    $result = $null
    $shortToolName = $toolName -replace '^mcp__plugin_engram_engram__', ''

    if ($script:EngramWriteTools -contains $shortToolName) {
        $result = Test-MemorySaveGuard -ToolName $toolName -ToolInput $input_json.tool_input
    } elseif ($input_json.tool_input.command) {
        $result = Test-SensitiveDataGuard -Command $input_json.tool_input.command
    }

    if ($result) {
        $response = @{
            decision = $result.decision
            reason   = $result.reason
        } | ConvertTo-Json -Compress
        Write-Output $response
        Write-GuardLog "BLOCK: $($result.reason)"
        exit 2
    }

    exit 0
}
