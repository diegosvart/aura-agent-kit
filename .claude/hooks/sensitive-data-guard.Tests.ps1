# sensitive-data-guard.Tests.ps1 — Pester 3.4.0 (unica version disponible en este entorno)
#
# Primer test file para este hook (Issue #303 Paso 4). Cubre:
# - El comportamiento YA existente para `git commit` (nunca tenia test propio antes de esto).
# - El comportamiento NUEVO para la tool MCP `mem_save` de Engram, condicionado a
#   .agent/memory/repo-classification.json (D4 de
#   docs/aura/specs/2026-09-17-memoria-clasificacion-repos-design.md).
#
# Dot-sourcea el hook para invocar Test-SensitiveDataGuard / Test-MemorySaveGuard /
# Test-ContentAgainstSensitivePatterns directamente, mockeando Get-RepoRoot / Get-StagedDiff /
# Get-DenylistPath / Get-RepoClassification para no depender de un checkout git real ni de
# archivos gitignored (.claude/sensitive-terms.local.txt, .agent/memory/repo-classification.json).

$hookPath = Join-Path $PSScriptRoot 'sensitive-data-guard.ps1'
. $hookPath

Describe 'Test-ContentAgainstSensitivePatterns - patrones genericos (comportamiento base)' {

    It 'bloquea RUT chileno' {
        $result = Test-ContentAgainstSensitivePatterns -Content 'el RUT del cliente es 12.345.678-9' -DenylistPath $null
        $result.decision | Should Be 'block'
    }

    It 'bloquea IP privada' {
        $result = Test-ContentAgainstSensitivePatterns -Content 'servidor en 192.168.1.10' -DenylistPath $null
        $result.decision | Should Be 'block'
    }

    It 'bloquea credenciales (password=)' {
        $result = Test-ContentAgainstSensitivePatterns -Content 'usar password=hunter2 para conectar' -DenylistPath $null
        $result.decision | Should Be 'block'
    }

    It 'permite contenido limpio' {
        $result = Test-ContentAgainstSensitivePatterns -Content 'decision tecnica sin datos sensibles' -DenylistPath $null
        $result | Should Be $null
    }

    It 'bloquea por denylist local cuando el archivo existe y matchea' {
        $tmpDenylist = Join-Path $env:TEMP "sensitive-data-guard-test-denylist-$PID.txt"
        Set-Content -Path $tmpDenylist -Value "ACME Corp`n# comentario ignorado"
        try {
            $result = Test-ContentAgainstSensitivePatterns -Content 'trabajando con ACME Corp esta semana' -DenylistPath $tmpDenylist
            $result.decision | Should Be 'block'
        } finally {
            Remove-Item $tmpDenylist -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-SensitiveDataGuard - git commit (comportamiento existente, sin regresion)' {

    It 'no aplica si el comando no es git commit' {
        $result = Test-SensitiveDataGuard -Command 'git status'
        $result | Should Be $null
    }

    It 'bloquea git commit si el staged diff tiene un patron sensible' {
        Mock Get-StagedDiff { 'password=hunter2' }
        Mock Get-RepoRoot { $null }
        $result = Test-SensitiveDataGuard -Command 'git commit -m "wip"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git commit si el patron sensible viene en el propio comando (comando compuesto, Issue gestion-documental)' {
        Mock Get-StagedDiff { '' }
        Mock Get-RepoRoot { $null }
        $result = Test-SensitiveDataGuard -Command 'echo "password=hunter2" > f && git add f && git commit -m x'
        $result.decision | Should Be 'block'
    }

    It 'permite git commit con contenido limpio' {
        Mock Get-StagedDiff { 'contenido normal sin datos sensibles' }
        Mock Get-RepoRoot { $null }
        $result = Test-SensitiveDataGuard -Command 'git commit -m "feat: algo"'
        $result | Should Be $null
    }
}

Describe 'Test-MemorySaveGuard - tools de escritura de Engram (Issue #303 Paso 4 + code-review PR #307)' {

    It 'no aplica a tools de LECTURA de Engram (mem_search, mem_context)' {
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_search' -ToolInput @{ query = 'password=hunter2' }
        $result | Should Be $null
        $result2 = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_context' -ToolInput @{ project = 'x' }
        $result2 | Should Be $null
    }

    It 'repo_type cliente + contenido sensible (RUT) -> bloqueado' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'Fix bug'; content = 'RUT del admin: 12.345.678-9' }
        $result.decision | Should Be 'block'
    }

    It 'repo_type cliente + contenido limpio -> permitido' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'Fix bug'; content = 'decision tecnica, placeholder generico' }
        $result | Should Be $null
    }

    It 'repo_type harness -> permitido sin evaluar contenido (aunque tenga un patron sensible)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'harness' } }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'password=hunter2' }
        $result | Should Be $null
    }

    It 'repo_type personal -> permitido sin evaluar contenido' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'personal' } }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'password=hunter2' }
        $result | Should Be $null
    }

    It 'repo-classification.json ausente -> fail-closed, bloqueado incondicionalmente' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'contenido totalmente limpio' }
        $result.decision | Should Be 'block'
        $result.reason | Should Match 'repo_type'
    }

    It 'repo-classification.json corrupto (repo_type vacio) -> fail-closed, bloqueado' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = '' } }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'contenido limpio' }
        $result.decision | Should Be 'block'
    }

    It 'repo_type con typo/valor no reconocido -> fail-closed, bloqueado igual que clasificacion ausente (hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'clientee' } }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'contenido totalmente limpio' }
        $result.decision | Should Be 'block'
    }

    It 'intercepta mem_save_prompt en repo cliente con contenido sensible (hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save_prompt' -ToolInput @{ content = 'el RUT del cliente es 12.345.678-9' }
        $result.decision | Should Be 'block'
    }

    It 'intercepta mem_capture_passive en repo cliente con contenido sensible (hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_capture_passive' -ToolInput @{ content = 'password=hunter2' }
        $result.decision | Should Be 'block'
    }

    It 'intercepta mem_update en repo cliente con contenido sensible (hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_update' -ToolInput @{ id = 42; content = '192.168.1.10' }
        $result.decision | Should Be 'block'
    }

    It 'intercepta mem_session_summary en repo cliente con contenido sensible (mismo criterio: escribe contenido libre a Engram)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_session_summary' -ToolInput @{ content = 'password=hunter2' }
        $result.decision | Should Be 'block'
    }

    It 'escanea el campo observation (alias retrocompatible de content, hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; observation = 'RUT del cliente: 12.345.678-9' }
        $result.decision | Should Be 'block'
    }

    It 'escanea el campo topic_key (hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'limpio'; topic_key = 'cliente/ACME-project-192.168.1.10' }
        $result.decision | Should Be 'block'
    }

    It 'escanea el campo session_id (hallazgo code-review PR #307)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_save' -ToolInput @{ title = 'x'; content = 'limpio'; session_id = 'password=hunter2' }
        $result.decision | Should Be 'block'
    }

    It 'intercepta mem_session_end en repo cliente con contenido sensible (hallazgo reviewer post-merge PR #307, Issue #309)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_session_end' -ToolInput @{ summary = 'el RUT del cliente es 12.345.678-9' }
        $result.decision | Should Be 'block'
    }

    It 'permite mem_session_end en repo cliente con contenido limpio' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_session_end' -ToolInput @{ summary = 'decision tecnica sin datos sensibles' }
        $result | Should Be $null
    }

    It 'intercepta mem_judge en repo cliente con contenido sensible en reason (hallazgo reviewer post-merge PR #307, Issue #309)' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_judge' -ToolInput @{ judgment_id = 1; reason = 'password=hunter2' }
        $result.decision | Should Be 'block'
    }

    It 'intercepta mem_judge en repo cliente con contenido sensible en evidence' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_judge' -ToolInput @{ judgment_id = 1; evidence = '192.168.1.10' }
        $result.decision | Should Be 'block'
    }

    It 'permite mem_judge en repo cliente con contenido limpio' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'cliente' } }
        Mock Get-DenylistPath { $null }
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_judge' -ToolInput @{ judgment_id = 1; reason = 'related, no conflict' }
        $result | Should Be $null
    }

    It 'mem_session_end y mem_judge respetan fail-closed ante repo-classification.json ausente' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { $null }
        $result1 = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_session_end' -ToolInput @{ summary = 'contenido limpio' }
        $result1.decision | Should Be 'block'
        $result2 = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_judge' -ToolInput @{ reason = 'contenido limpio' }
        $result2.decision | Should Be 'block'
    }

    It 'mem_session_end y mem_judge permitidos sin evaluar contenido en repo harness/personal' {
        Mock Get-RepoRoot { $null }
        Mock Get-RepoClassification { [pscustomobject]@{ repo_type = 'harness' } }
        $result1 = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_session_end' -ToolInput @{ summary = 'password=hunter2' }
        $result1 | Should Be $null
        $result2 = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_judge' -ToolInput @{ reason = 'password=hunter2' }
        $result2 | Should Be $null
    }
}

# Issue #309: los Describe de arriba dot-sourcean el hook y llaman las funciones internas
# directamente — nunca ejercitan el bloque de entry-point real (lectura de stdin,
# ConvertFrom-Json, dispatch entre EngramWriteTools/tool_input.command, exit code). Estos
# tests invocan el script como proceso (mismo patron que git-guard.Tests.ps1) para cubrir eso.
Describe 'sensitive-data-guard.ps1 - entry point (stdin parse + dispatch)' {

    It 'input no parseable como JSON: no bloquea y queda logueado (fail-open)' {
        $logPath = Join-Path $PSScriptRoot 'sensitive-data-guard.log'
        if (Test-Path $logPath) { Remove-Item $logPath -Force }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'pwsh'
        $psi.Arguments = "-NonInteractive -File `"$hookPath`""
        $psi.RedirectStandardInput = $true
        $psi.UseShellExecute = $false

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Write('esto no es json')
        $proc.StandardInput.Close()
        $proc.WaitForExit()

        $proc.ExitCode | Should Be 0
        Test-Path $logPath | Should Be $true
        (Get-Content $logPath -Raw) | Should Match 'FAIL-OPEN'
    }

    It 'dispatch: tool_name mem_judge en repo cliente con contenido sensible -> bloqueado (exit 2)' {
        $tmpRepo = Join-Path $env:TEMP "sensitive-data-guard-entrypoint-test-$PID"
        New-Item -ItemType Directory -Path $tmpRepo -Force | Out-Null
        try {
            Push-Location $tmpRepo
            git init --quiet | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tmpRepo '.agent/memory') -Force | Out-Null
            Set-Content -Path (Join-Path $tmpRepo '.agent/memory/repo-classification.json') -Value '{"repo_type":"cliente"}'
            Pop-Location

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'pwsh'
            $psi.Arguments = "-NonInteractive -File `"$hookPath`""
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = $tmpRepo

            $proc = [System.Diagnostics.Process]::Start($psi)
            $inputJson = '{"tool_name":"mcp__plugin_engram_engram__mem_judge","tool_input":{"judgment_id":1,"reason":"password=hunter2"}}'
            $proc.StandardInput.Write($inputJson)
            $proc.StandardInput.Close()
            $stdout = $proc.StandardOutput.ReadToEnd()
            $proc.WaitForExit()

            $proc.ExitCode | Should Be 2
            $stdout | Should Match 'block'
        } finally {
            if (Test-Path $tmpRepo) { Remove-Item $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'dispatch: tool_name de solo lectura (mem_search) no entra al path de EngramWriteTools -> exit 0' {
        $tmpRepo = Join-Path $env:TEMP "sensitive-data-guard-entrypoint-test-ro-$PID"
        New-Item -ItemType Directory -Path $tmpRepo -Force | Out-Null
        try {
            Push-Location $tmpRepo
            git init --quiet | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tmpRepo '.agent/memory') -Force | Out-Null
            Set-Content -Path (Join-Path $tmpRepo '.agent/memory/repo-classification.json') -Value '{"repo_type":"cliente"}'
            Pop-Location

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'pwsh'
            $psi.Arguments = "-NonInteractive -File `"$hookPath`""
            $psi.RedirectStandardInput = $true
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = $tmpRepo

            $proc = [System.Diagnostics.Process]::Start($psi)
            $inputJson = '{"tool_name":"mcp__plugin_engram_engram__mem_search","tool_input":{"query":"password=hunter2"}}'
            $proc.StandardInput.Write($inputJson)
            $proc.StandardInput.Close()
            $proc.WaitForExit()

            $proc.ExitCode | Should Be 0
        } finally {
            if (Test-Path $tmpRepo) { Remove-Item $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Write-Host ""
Write-Host "Suite completo — ver resumen de Pester arriba (Tests: N, Passed: N, Failed: N)."
