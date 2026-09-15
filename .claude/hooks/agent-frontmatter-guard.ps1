# agent-frontmatter-guard.ps1 — PreToolUse hook
#
# Intercepta Edit/Write antes de aplicarse. Si el archivo destino matchea agents/*.md,
# simula el contenido resultante (Write: tool_input.content completo; Edit: old_string ->
# new_string aplicado sobre el contenido actual en disco) y lo valida contra
# skills/repo-integrity/scripts/check-agent-frontmatter.sh antes de dejar pasar la edicion.
#
# Por que existe: check-agent-frontmatter.sh (Issue #231) nunca quedo conectado a ningun
# hook ni CI (Issue #286, bug #7 de Issue #285) -- 8 archivos agents/*.md llegaron a develop
# sin frontmatter valido antes de que una auditoria manual lo detectara. Mismo patron de
# enforcement duro que git-guard.ps1/sensitive-data-guard.ps1/pr-base-guard.ps1/
# checkout-lock-guard.ps1: una regla en markdown depende de que el agente se acuerde de
# aplicarla, un hook no. Ver docs/aura/experiments/2026-09-15-agent-frontmatter-guard-hook.md
# (hipotesis P4, gitignored/local).
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Edit", "tool_input": { "file_path": "...", "old_string": "...", "new_string": "...", "replace_all": false } }
#   { "tool_name": "Write", "tool_input": { "file_path": "...", "content": "..." } }

function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "agent-frontmatter-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] FAIL-OPEN: $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada mas que hacer -- no debe bloquear el flujo.
    }
}

function Test-IsAgentMarkdownPath {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    $normalized = $FilePath -replace '\\', '/'
    return [bool]($normalized -match '(^|/)agents/[^/]+\.md$')
}

function Get-GitBashPath {
    $gitCmd = (Get-Command git -ErrorAction SilentlyContinue).Source
    if (-not $gitCmd) { return $null }
    $gitRoot = Split-Path (Split-Path $gitCmd -Parent) -Parent
    $candidate = Join-Path $gitRoot "bin\bash.exe"
    if (Test-Path $candidate) { return $candidate }
    return $null
}

# Construye el contenido resultante de la edicion sin tocar el archivo real en disco.
function Get-ResultingContent {
    param($ToolName, $ToolInput)

    if ($ToolName -eq 'Write') {
        return $ToolInput.content
    }

    if ($ToolName -eq 'Edit') {
        $filePath = $ToolInput.file_path
        if (-not (Test-Path $filePath)) { return $null }
        $current = Get-Content -Path $filePath -Raw -ErrorAction SilentlyContinue
        if ($null -eq $current) { return $null }

        $oldStr = $ToolInput.old_string
        $newStr = $ToolInput.new_string
        if (-not $oldStr) { return $current }

        if ($ToolInput.replace_all) {
            return $current.Replace($oldStr, $newStr)
        }

        $idx = $current.IndexOf($oldStr)
        if ($idx -lt 0) { return $current }
        return $current.Substring(0, $idx) + $newStr + $current.Substring($idx + $oldStr.Length)
    }

    return $null
}

function Test-AgentFrontmatterGuard {
    param($ToolName, $ToolInput, [string]$RepoRoot, [string]$GitBashPath)

    if ($ToolName -notin @('Edit', 'Write')) { return $null }

    $filePath = $ToolInput.file_path
    if (-not (Test-IsAgentMarkdownPath -FilePath $filePath)) { return $null }

    if (-not $GitBashPath) {
        Write-GuardLog "gitBash no resuelto -- '$filePath' no evaluado."
        return $null
    }

    $content = Get-ResultingContent -ToolName $ToolName -ToolInput $ToolInput
    if ($null -eq $content) {
        Write-GuardLog "No se pudo reconstruir el contenido resultante de '$filePath' -- no evaluado."
        return $null
    }

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tempFile -Value $content -NoNewline -Encoding utf8

        $checkScript = Join-Path $RepoRoot "skills\repo-integrity\scripts\check-agent-frontmatter.sh"
        if (-not (Test-Path $checkScript)) {
            Write-GuardLog "check-agent-frontmatter.sh no encontrado en '$checkScript' -- '$filePath' no evaluado."
            return $null
        }

        $output = & $GitBashPath $checkScript $tempFile 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $displayOutput = ($output -join " | ") -replace [regex]::Escape($tempFile), $filePath
            $reason = "agent-frontmatter-guard: frontmatter invalido en '$filePath' -- $displayOutput. Ver agents/github.md como referencia de formato (name/description/tools, description con 'use proactively' o 'use after')."
            return @{ decision = "block"; reason = $reason }
        }
    } finally {
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
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
        Write-GuardLog "No se pudo parsear stdin como JSON ($($_.Exception.Message)) -- hook no evaluo el comando."
        exit 0
    }

    $toolName = $input_json.tool_name
    $toolInput = $input_json.tool_input
    if (-not $toolName -or -not $toolInput) { exit 0 }

    $repoRoot = (git rev-parse --show-toplevel 2>$null)
    if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
    $gitBashPath = Get-GitBashPath

    $result = Test-AgentFrontmatterGuard -ToolName $toolName -ToolInput $toolInput -RepoRoot $repoRoot -GitBashPath $gitBashPath
    if ($result) {
        $response = @{ decision = $result.decision; reason = $result.reason } | ConvertTo-Json -Compress
        Write-Output $response
        exit 2
    }

    exit 0
}
