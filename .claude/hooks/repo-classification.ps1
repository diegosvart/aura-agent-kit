# repo-classification.ps1 — modulo dot-source compartido (Issue #347)
#
# Fuente unica de Get-RepoClassification para gh-account-guard.ps1 y sensitive-data-guard.ps1
# (antes duplicada en ambos). Se carga con `. (Join-Path $PSScriptRoot 'repo-classification.ps1')`
# igual que shell-quoting.ps1; los hooks se invocan como scripts independientes (-File), asi que
# $PSScriptRoot del hook apunta a este mismo directorio.
#
# Devuelve $null ante raiz nula, archivo ausente o JSON corrupto. NO decide fail-open/fail-closed:
# esa politica la aplica cada llamador (sensitive-data-guard bloquea ante $null; gh-account-guard
# lo trata como "cuenta esperada no declarada"). -ProjectRoot es alias historico de
# gh-account-guard.ps1.

function Get-RepoClassification {
    param([Alias('ProjectRoot')][string]$RepoRoot)
    if (-not $RepoRoot) { return $null }
    $path = Join-Path $RepoRoot ".agent/memory/repo-classification.json"
    if (-not (Test-Path $path)) { return $null }
    try {
        return (Get-Content -Path $path -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}
