# session-start.Tests.ps1 — Pester 3.4.0
#
# Cubre el item 17 de session-start.ps1 (Issue #308): la clasificacion de repo
# (.agent/memory/repo-classification.json) debe viajar en el JSON del hook, y una
# clasificacion ausente/corrupta/invalida debe reportarse explicita (fail-closed), nunca
# silenciarse ni inventarse un valor. El hook se ejecuta como proceso real dentro de un repo
# git temporal (su raiz se resuelve con git rev-parse --show-toplevel).

$hookPath = Join-Path $PSScriptRoot 'session-start.ps1'

function New-TempRepo {
    $dir = Join-Path $env:TEMP "session-start-tests-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path (Join-Path $dir '.agent\memory') -Force | Out-Null
    Push-Location $dir
    try { git init -q 2>$null | Out-Null } finally { Pop-Location }
    return $dir
}

function Invoke-SessionStartHook {
    param([string]$RepoDir)
    Push-Location $RepoDir
    try {
        $raw = & pwsh -NoProfile -File $hookPath 2>$null
        return (($raw -join "`n") | ConvertFrom-Json)
    } finally {
        Pop-Location
    }
}

Describe 'session-start.ps1 - item 17: repo_classification' {

    It 'emite status ok y repo_type cuando el archivo es valido' {
        $dir = New-TempRepo
        @{ repo_type = 'cliente'; classified_by = 'manual' } | ConvertTo-Json |
            Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Encoding utf8
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'ok'
        $out.repo_classification.repo_type | Should Be 'cliente'
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reporta status missing explicito si el archivo no existe' {
        $dir = New-TempRepo
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'missing'
        $out.repo_classification.repo_type | Should Be $null
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reporta status corrupt si el JSON no parsea' {
        $dir = New-TempRepo
        Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Value '{ no es json' -Encoding utf8
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'corrupt'
        $out.repo_classification.repo_type | Should Be $null
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reporta status invalid si repo_type no es harness/personal/cliente' {
        $dir = New-TempRepo
        @{ repo_type = 'otro' } | ConvertTo-Json |
            Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Encoding utf8
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'invalid'
        $out.repo_classification.repo_type | Should Be $null
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reporta status invalid si repo_type falta en un JSON valido' {
        $dir = New-TempRepo
        @{ classified_by = 'manual' } | ConvertTo-Json |
            Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Encoding utf8
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'invalid'
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reporta status invalid para repo_type con distinta capitalizacion (Cliente)' {
        $dir = New-TempRepo
        Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Value '{"repo_type":"Cliente"}' -Encoding utf8
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'invalid'
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'reporta status invalid para archivo vacio' {
        $dir = New-TempRepo
        Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Value '' -Encoding utf8
        $out = Invoke-SessionStartHook -RepoDir $dir
        $out.repo_classification.status | Should Be 'invalid'
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'degrada a status corrupt sin romper el JSON si falta repo-classification.ps1' {
        $dir = New-TempRepo
        $hookDir = Join-Path $env:TEMP "session-start-hook-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
        Copy-Item $hookPath (Join-Path $hookDir 'session-start.ps1')
        @{ repo_type = 'harness' } | ConvertTo-Json |
            Set-Content -Path (Join-Path $dir '.agent\memory\repo-classification.json') -Encoding utf8
        Push-Location $dir
        try {
            $raw = & pwsh -NoProfile -File (Join-Path $hookDir 'session-start.ps1') 2>$null
            $out = (($raw -join "`n") | ConvertFrom-Json)
        } finally { Pop-Location }
        $out.repo_classification.status | Should Be 'corrupt'
        $out.repo_classification.repo_type | Should Be $null
        $out.repo_classification.error | Should Not BeNullOrEmpty
        Remove-Item $dir, $hookDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
