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

Describe 'Test-MemorySaveGuard - mem_save (Issue #303 Paso 4, nuevo)' {

    It 'no aplica a otras tools MCP (solo intercepta mem_save)' {
        $result = Test-MemorySaveGuard -ToolName 'mcp__plugin_engram_engram__mem_search' -ToolInput @{ query = 'password=hunter2' }
        $result | Should Be $null
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
}

Write-Host ""
Write-Host "Suite completo — ver resumen de Pester arriba (Tests: N, Passed: N, Failed: N)."
