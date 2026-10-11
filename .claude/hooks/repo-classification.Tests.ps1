# repo-classification.Tests.ps1 — Pester 3.4.0
#
# Issue #347: Get-RepoClassification vive en un unico modulo dot-source compartido por
# gh-account-guard.ps1 y sensitive-data-guard.ps1. Estos tests usan archivos reales en un
# directorio temporal (sin mocks) para fijar el contrato: devuelve $null ante ausencia,
# corrupcion o raiz nula, y acepta tanto -RepoRoot como -ProjectRoot (nombre historico de
# gh-account-guard.ps1).

. (Join-Path $PSScriptRoot 'repo-classification.ps1')

function New-TempRepo {
    param([string]$ClassificationJson)
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("repoclass-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $root '.agent/memory') -Force | Out-Null
    if ($null -ne $ClassificationJson) {
        Set-Content -Path (Join-Path $root '.agent/memory/repo-classification.json') -Value $ClassificationJson
    }
    return $root
}

Describe 'Get-RepoClassification (modulo compartido, Issue #347)' {

    It 'devuelve el objeto parseado cuando el JSON es valido' {
        $root = New-TempRepo '{"repo_type":"cliente","expected_gh_account":"acme"}'
        try {
            $c = Get-RepoClassification -RepoRoot $root
            $c.repo_type | Should Be 'cliente'
            $c.expected_gh_account | Should Be 'acme'
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'acepta -ProjectRoot como alias de -RepoRoot' {
        $root = New-TempRepo '{"repo_type":"harness"}'
        try {
            (Get-RepoClassification -ProjectRoot $root).repo_type | Should Be 'harness'
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'devuelve $null cuando el archivo no existe' {
        $root = New-TempRepo $null
        try {
            Get-RepoClassification -RepoRoot $root | Should BeNullOrEmpty
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'devuelve $null cuando el JSON esta corrupto' {
        $root = New-TempRepo '{ esto no es json'
        try {
            Get-RepoClassification -RepoRoot $root | Should BeNullOrEmpty
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'devuelve $null cuando la raiz es nula o vacia' {
        Get-RepoClassification -RepoRoot $null | Should BeNullOrEmpty
        Get-RepoClassification -RepoRoot '' | Should BeNullOrEmpty
    }
}
