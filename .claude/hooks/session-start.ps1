# session-start.ps1
# Hook: SessionStart[startup]
# Inyecta contexto de estado del repositorio para que el agente ejecute session_start.md

$output = @{}

# Raíz del proyecto (2 niveles arriba de .claude/hooks/)
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Git info básica
try {
    $branch = git branch --show-current 2>$null
    $output.branch = if ($branch) { $branch.Trim() } else { "unknown" }

    $statusLines = git status --short 2>$null
    $output.uncommitted_files = if ($statusLines) { @($statusLines).Count } else { 0 }

    $diffStat = git diff --stat 2>$null
    $output.diff_stat = if ($diffStat) { ($diffStat | Select-Object -Last 1).Trim() } else { "sin cambios" }

    $lastCommit = git log --oneline -1 2>$null
    $output.last_commit = if ($lastCommit) { $lastCommit.Trim() } else { "sin commits" }

    $recentCommits = git log --oneline -3 2>$null
    $output.recent_commits = if ($recentCommits) { $recentCommits -join "`n" } else { "" }
} catch {
    $output.git_error = $_.Exception.Message
}

# gh auth check
try {
    $null = gh auth status 2>&1
    $output.gh_authenticated = ($LASTEXITCODE -eq 0)
} catch {
    $output.gh_authenticated = $false
}

# current-session.json
$sessionFile = Join-Path $projectRoot ".agent\memory\current-session.json"
if (Test-Path $sessionFile) {
    try {
        $session = Get-Content $sessionFile -Raw | ConvertFrom-Json
        $output.last_session = @{
            focus     = $session.focus
            next_step = $session.next_step
            branch    = $session.branch
            pending   = $session.pending
        }
    } catch {
        $output.last_session = $null
    }
} else {
    $output.last_session = $null
}

# Stash
try {
    $stash = git stash list 2>$null
    $output.stash_count = if ($stash) { @($stash).Count } else { 0 }
} catch {
    $output.stash_count = 0
}

# Salud de ramas
try {
    $output.merged_branches = @(git branch --merged develop 2>$null |
        Where-Object { $_ -notmatch "^\*|main|develop" } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" })

    $output.gone_branches = @(git branch -vv 2>$null |
        Where-Object { $_ -match ": gone\]" } |
        ForEach-Object { ($_ -split "\s+")[1] })
} catch {
    $output.merged_branches = @()
    $output.gone_branches = @()
}

# Issues con label ready (si gh autenticado)
$issuesList = [System.Collections.Generic.List[object]]::new()
if ($output.gh_authenticated) {
    try {
        $issuesJson = gh issue list --label ready --state open --json number,title --limit 10 2>$null
        if ($issuesJson) {
            $parsed = $issuesJson | ConvertFrom-Json
            if ($parsed) { foreach ($i in $parsed) { $issuesList.Add($i) | Out-Null } }
        }
    } catch { }
}
$output.issues_ready = $issuesList

# Detección de stack tecnológico
$detectedStack = $null
Push-Location $projectRoot
try {
    if (Test-Path "pyproject.toml") { $detectedStack = "Python" }
    elseif (Test-Path "package.json") { $detectedStack = "Node.js/TypeScript" }
    elseif (Test-Path "Cargo.toml")   { $detectedStack = "Rust" }
    elseif (Test-Path "go.mod")       { $detectedStack = "Go" }
} finally {
    Pop-Location
}
$output.detected_stack = $detectedStack

# Leer session-stack.json si ya fue confirmado previamente
$stackFile = Join-Path $projectRoot ".agent\memory\session-stack.json"
$output.session_stack = $null
if (Test-Path $stackFile) {
    try {
        $output.session_stack = Get-Content $stackFile -Raw | ConvertFrom-Json
    } catch { }
}

# Candidatos para repo integrity check
# Ramas con commits que dicen "Closes/Fixes/Resolves #N" pero pueden estar stranded
$output.integrity_candidates = @()
try {
    $aheadBranches = git branch --no-merged develop 2>$null |
        Where-Object { $_ -notmatch "^\*|main|develop" } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Select-Object -First 10

    foreach ($b in $aheadBranches) {
        $commits = git log "develop..$b" --oneline 2>$null
        if ($commits) {
            $closingCommits = @($commits) | Where-Object { $_ -imatch "(Closes|Fixes|Resolves)\s+#\d+" }
            if ($closingCommits) {
                $output.integrity_candidates += @{
                    branch  = $b
                    commits = ($closingCommits -join "; ")
                }
            }
        }
    }
} catch { }

# Output como JSON para que Claude lo use como contexto
$output | ConvertTo-Json -Depth 5
