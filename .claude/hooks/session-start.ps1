# session-start.ps1
# Hook: SessionStart[startup]
# Inyecta contexto de estado del repositorio para que el agente ejecute session_start.md

$output = @{}

# Git info
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
    $ghAuth = gh auth status 2>&1
    $output.gh_authenticated = $ghAuth -notmatch "not logged"
} catch {
    $output.gh_authenticated = $false
}

# current-session.json
$sessionFile = Join-Path $PSScriptRoot "..\..\. agent\memory\current-session.json"
$sessionFile = Join-Path (Split-Path $PSScriptRoot -Parent) "..\agent\memory\current-session.json"
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
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

# Output como JSON para que Claude lo use como contexto
$output | ConvertTo-Json -Depth 5
