# repo-classification.Tests.ps1 — Pester 3.4.0
#
# Issue #347: Get-RepoClassification vive en un unico modulo dot-source compartido por
# gh-account-guard.ps1 y sensitive-data-guard.ps1. Estos tests usan archivos reales en un
# directorio temporal (sin mocks) para fijar el contrato: devuelve $null ante ausencia,
# corrupcion o raiz nula, y acepta tanto -RepoRoot como -ProjectRoot (nombre historico de
# gh-account-guard.ps1).

. (Join-Path $PSScriptRoot 'repo-classification.ps1')

function New-TempRepo {
    param($ClassificationJson)
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

Describe 'Get-RepoClassificationStatus (validacion compartida de repo_type, Issue #379)' {

    foreach ($tipo in @('harness', 'personal', 'cliente')) {
        It "status ok para repo_type $tipo, con classified_at/by" {
            $root = New-TempRepo ('{"repo_type":"' + $tipo + '","classified_at":"2026-01-01","classified_by":"manual"}')
            try {
                $s = Get-RepoClassificationStatus -RepoRoot $root
                $s.status | Should Be 'ok'
                $s.repo_type | Should Be $tipo
                $s.classified_at | Should Be '2026-01-01'
                $s.classified_by | Should Be 'manual'
            } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'status missing cuando el archivo no existe' {
        $root = New-TempRepo $null
        try {
            $s = Get-RepoClassificationStatus -RepoRoot $root
            $s.status | Should Be 'missing'
            $s.repo_type | Should BeNullOrEmpty
            $s.error | Should Not BeNullOrEmpty
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'status corrupt cuando el JSON no parsea, con mensaje de error' {
        $root = New-TempRepo '{ esto no es json'
        try {
            $s = Get-RepoClassificationStatus -RepoRoot $root
            $s.status | Should Be 'corrupt'
            $s.repo_type | Should BeNullOrEmpty
            $s.error | Should Not BeNullOrEmpty
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'status invalid para archivo vacio' {
        $root = New-TempRepo ''
        try {
            (Get-RepoClassificationStatus -RepoRoot $root).status | Should Be 'invalid'
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'status invalid para archivo con solo espacios' {
        $root = New-TempRepo "   `n  "
        try {
            (Get-RepoClassificationStatus -RepoRoot $root).status | Should Be 'invalid'
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'status ok con BOM UTF-8 al inicio (fija comportamiento de Get-Content -Raw)' {
        $root = New-TempRepo $null
        try {
            $bytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes('{"repo_type":"harness"}')
            [System.IO.File]::WriteAllBytes((Join-Path $root '.agent/memory/repo-classification.json'), $bytes)
            $s = Get-RepoClassificationStatus -RepoRoot $root
            $s.status | Should Be 'ok'
            $s.repo_type | Should Be 'harness'
        } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    foreach ($caso in @(
        @{ n = 'tipo no reconocido'; j = '{"repo_type":"otro"}' },
        @{ n = 'typo clientee'; j = '{"repo_type":"clientee"}' },
        @{ n = 'mayuscula Cliente (case-sensitive)'; j = '{"repo_type":"Cliente"}' },
        @{ n = 'repo_type faltante'; j = '{"classified_by":"manual"}' },
        @{ n = 'repo_type vacio'; j = '{"repo_type":""}' },
        @{ n = 'repo_type numerico'; j = '{"repo_type":1}' },
        @{ n = 'repo_type objeto'; j = '{"repo_type":{"a":"cliente"}}' },
        @{ n = 'repo_type arreglo'; j = '{"repo_type":["cliente"]}' }
    )) {
        It "status invalid para $($caso.n)" {
            $root = New-TempRepo $caso.j
            try {
                $s = Get-RepoClassificationStatus -RepoRoot $root
                $s.status | Should Be 'invalid'
                $s.repo_type | Should BeNullOrEmpty
            } finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'status missing cuando RepoRoot es nulo o vacio' {
        (Get-RepoClassificationStatus -RepoRoot $null).status | Should Be 'missing'
        (Get-RepoClassificationStatus -RepoRoot '').status | Should Be 'missing'
    }
}
