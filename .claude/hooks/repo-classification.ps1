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

# Fuente unica de los tipos de repo validos (Issue #379): session-start.ps1 (reporta) y
# sensitive-data-guard.ps1 (bloquea) la consumen via Get-RepoClassificationStatus, en vez de
# duplicar la lista.
$script:ValidRepoTypes = @('harness', 'personal', 'cliente')

# Estado explicito de la clasificacion: status = ok | missing | corrupt | invalid. A diferencia
# de Get-RepoClassification (que devuelve $null para ausente y corrupto, y no valida el tipo),
# distingue cada caso. Tampoco decide la politica: el llamador reporta o bloquea. La comparacion
# del tipo es case-sensitive (-cnotin) para que "Cliente" o "clientee" sean invalid, nunca ok.
function Get-RepoClassificationStatus {
    param([Alias('ProjectRoot')][string]$RepoRoot)
    $missing = @{ status = 'missing'; repo_type = $null; error = 'repo-classification.json no existe' }
    if (-not $RepoRoot) { return $missing }
    $path = Join-Path $RepoRoot ".agent/memory/repo-classification.json"
    if (-not (Test-Path $path)) { return $missing }
    try {
        $classification = Get-Content -Path $path -Raw | ConvertFrom-Json
    } catch {
        return @{ status = 'corrupt'; repo_type = $null; error = $_.Exception.Message }
    }
    $repoType = $classification.repo_type
    if ($repoType -isnot [string] -or $repoType -cnotin $script:ValidRepoTypes) {
        return @{ status = 'invalid'; repo_type = $null; error = 'repo_type ausente o fuera de harness/personal/cliente' }
    }
    return @{
        status        = 'ok'
        repo_type     = $repoType
        classified_at = $classification.classified_at
        classified_by = $classification.classified_by
    }
}
