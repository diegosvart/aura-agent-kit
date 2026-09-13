# session-end-gather.ps1 (Issue #259)
#
# NO es un hook registrado en .claude/settings.json -- no hay evento SessionEnd util para este
# caso (dispara despues de que la conversacion ya cerro, ver spec
# docs/aura/specs/2026-09-12-session-end-script-consolidation-design.md). El agente lo invoca
# manualmente via Bash/PowerShell tool al detectar el trigger textual de cierre de sesion
# ("terminamos", "cerramos", ...), reemplazando ~7 tool-calls dispersas (linter, tests, chequeo
# de rama, 4 llamadas gh) por una sola invocacion.
#
# Mismo estilo/convenciones que session-start.ps1: fail-open por bloque (un chequeo que falla no
# tira abajo el resto), gh_authenticated como unica senal valida para "sin arrays de GitHub" (no
# inferir de arrays vacios sin chequear el flag primero).

function Get-StackInfo {
    param(
        [string]$StackFilePath,
        [string]$ProjectRoot
    )

    if ($StackFilePath -and (Test-Path $StackFilePath)) {
        try {
            $raw = Get-Content $StackFilePath -Raw | ConvertFrom-Json
            $profileName = if ($raw.profile_name) { $raw.profile_name } elseif ($raw.stack) { $raw.stack } else { "custom" }
            $lint = if ($raw.linter) { $raw.linter } elseif ($raw.lint) { $raw.lint } else { $null }
            $test = if ($raw.test_runner) { $raw.test_runner } elseif ($raw.test) { $raw.test } else { $null }
            if ([string]::IsNullOrWhiteSpace($lint)) { $lint = $null }
            if ([string]::IsNullOrWhiteSpace($test)) { $test = $null }
            return @{ profile = $profileName; lint = $lint; test = $test; source = "session-stack.json" }
        } catch {
            # Archivo presente pero no parseable -- cae a deteccion, igual que "no existe".
        }
    }

    # No hay session-stack.json (o no se pudo leer): detectar UNA VEZ para esta corrida, sin
    # escribirlo -- escribir session-stack.json es responsabilidad exclusiva de session_start.md.
    $detected = $null
    Push-Location $ProjectRoot
    try {
        if (Test-Path "pyproject.toml") { $detected = "Python" }
        elseif (Test-Path "requirements.txt") { $detected = "Python" }
        elseif (Test-Path "package.json") { $detected = "Node.js/TypeScript" }
        elseif (Test-Path "Cargo.toml") { $detected = "Rust" }
        elseif (Test-Path "go.mod") { $detected = "Go" }
    } finally {
        Pop-Location
    }

    switch ($detected) {
        "Python" { return @{ profile = "Python"; lint = "python -m ruff check ."; test = "pytest -q"; source = "detected" } }
        "Node.js/TypeScript" { return @{ profile = "Node.js/TypeScript"; lint = "npm run lint"; test = "npm test"; source = "detected" } }
        "Rust" { return @{ profile = "Rust"; lint = "cargo clippy"; test = "cargo test"; source = "detected" } }
        "Go" { return @{ profile = "Go"; lint = "golangci-lint run"; test = "go test ./..."; source = "detected" } }
        default { return @{ profile = "none"; lint = $null; test = $null; source = "none" } }
    }
}

function Invoke-CheckCommand {
    param(
        [string]$Command,
        [string]$ProjectRoot
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return @{ ran = $false; command = $null; exit_code = $null; output_tail = $null }
    }

    Push-Location $ProjectRoot
    try {
        $comspec = if ($env:ComSpec) { $env:ComSpec } else { "cmd.exe" }
        $output = & $comspec /c $Command 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    } finally {
        Pop-Location
    }

    $lines = @($output | ForEach-Object { $_.ToString() })
    $tail = ($lines | Select-Object -Last 20) -join "`n"

    return @{ ran = $true; command = $Command; exit_code = $exitCode; output_tail = $tail }
}

function Get-CurrentBranchName {
    try {
        $b = git branch --show-current 2>$null
        if ($b) { return $b.Trim() }
    } catch { }
    return "unknown"
}

function Get-GhAuthenticated {
    try {
        $null = gh auth status 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-RecentlyMergedPrs {
    try {
        $json = gh pr list --state merged --limit 10 --json number,title,mergedAt,headRefName 2>$null
        if ($json) {
            $parsed = $json | ConvertFrom-Json
            if ($parsed) { return @($parsed) }
        }
    } catch { }
    return @()
}

function Get-RecentlyClosedIssues {
    try {
        $json = gh issue list --state closed --limit 10 --json number,title,closedAt 2>$null
        if ($json) {
            $parsed = $json | ConvertFrom-Json
            if ($parsed) { return @($parsed) }
        }
    } catch { }
    return @()
}

function Get-OpenPrs {
    try {
        $json = gh pr list --state open --limit 20 --json number,title,headRefName 2>$null
        if ($json) {
            $parsed = $json | ConvertFrom-Json
            if ($parsed) { return @($parsed) }
        }
    } catch { }
    return @()
}

function Get-ReadyIssues {
    try {
        $json = gh issue list --label ready --state open --json number,title --limit 10 2>$null
        if ($json) {
            $parsed = $json | ConvertFrom-Json
            if ($parsed) { return @($parsed) }
        }
    } catch { }
    return @()
}

function Invoke-GitFetchDevelop {
    try {
        git fetch origin develop --quiet 2>$null
    } catch {
        # Fail-open -- si el fetch falla (sin red, etc.), el conteo sigue con lo que haya local.
    }
}

function Get-GitLogAheadCount {
    try {
        $log = git log origin/develop..HEAD --oneline 2>$null
        if ($log) { return @($log).Count }
        return 0
    } catch {
        return 0
    }
}

function Get-CommitsAheadOfDevelop {
    param([string]$ProjectRoot)

    Push-Location $ProjectRoot
    try {
        # Issue #214: actualizar develop antes de contar, mismo patron que session-start.ps1 --
        # sin este fetch el conteo puede desincronizarse del estado real de GitHub.
        Invoke-GitFetchDevelop
        return Get-GitLogAheadCount
    } finally {
        Pop-Location
    }
}

function Get-PrForCurrentBranch {
    param($OpenPrs, [string]$Branch)

    $match = @($OpenPrs) | Where-Object { $_.headRefName -eq $Branch } | Select-Object -First 1
    if ($match) { return $match }
    return $null
}

function Get-SessionEndGatherResult {
    param(
        [string]$ProjectRoot = (Get-Location).Path,
        [string]$StackFilePath = (Join-Path (Get-Location).Path ".agent\memory\session-stack.json")
    )

    $stack = Get-StackInfo -StackFilePath $StackFilePath -ProjectRoot $ProjectRoot
    $lintResult = Invoke-CheckCommand -Command $stack.lint -ProjectRoot $ProjectRoot
    $testResult = Invoke-CheckCommand -Command $stack.test -ProjectRoot $ProjectRoot

    $branch = Get-CurrentBranchName
    $branchProtected = @("develop", "main") -contains $branch

    $ghAuthenticated = Get-GhAuthenticated

    $recentlyMergedPrs = @()
    $recentlyClosedIssues = @()
    $openPrs = @()
    $readyIssues = @()

    if ($ghAuthenticated) {
        $recentlyMergedPrs = @(Get-RecentlyMergedPrs)
        $recentlyClosedIssues = @(Get-RecentlyClosedIssues)
        $openPrs = @(Get-OpenPrs)
        $readyIssues = @(Get-ReadyIssues)
    }

    $commitsAhead = Get-CommitsAheadOfDevelop -ProjectRoot $ProjectRoot
    $prForBranch = Get-PrForCurrentBranch -OpenPrs $openPrs -Branch $branch

    return @{
        stack                     = $stack
        lint_result               = $lintResult
        test_result               = $testResult
        branch                    = $branch
        branch_protected          = $branchProtected
        gh_authenticated          = $ghAuthenticated
        recently_merged_prs       = $recentlyMergedPrs
        recently_closed_issues    = $recentlyClosedIssues
        open_prs                  = $openPrs
        ready_issues              = $readyIssues
        commits_ahead_of_develop  = $commitsAhead
        pr_for_current_branch     = $prForBranch
    }
}

# --- Punto de entrada (solo al ejecutar directamente, no al dot-source para tests) ---
if ($MyInvocation.InvocationName -ne '.') {
    # Raiz del proyecto (2 niveles arriba de .claude/hooks/), mismo patron que session-start.ps1
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $stackFilePath = Join-Path $projectRoot ".agent\memory\session-stack.json"

    $result = Get-SessionEndGatherResult -ProjectRoot $projectRoot -StackFilePath $stackFilePath
    $result | ConvertTo-Json -Depth 6
}
