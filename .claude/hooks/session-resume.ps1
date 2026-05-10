# session-resume.ps1
# Hook: SessionStart[resume]
# Inyecta contexto de sesión previa cuando el usuario retoma con /clear o reanuda

$output = @{}

# Raíz del proyecto
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sessionFile = Join-Path $projectRoot ".agent\memory\current-session.json"

if (Test-Path $sessionFile) {
    try {
        $session = Get-Content $sessionFile -Raw | ConvertFrom-Json
        $output.resuming = $true
        $output.last_session = @{
            focus          = $session.focus
            next_step      = $session.next_step
            branch         = $session.branch
            pending        = $session.pending
            required_reads = $session.required_reads
            last_updated   = $session.last_updated
        }
    } catch {
        $output.resuming = $false
        $output.session_error = "No se pudo leer current-session.json"
    }
} else {
    $output.resuming = $false
    $output.last_session = $null
}

# Git: rama, últimos commits, cambios, diff stat
try {
    $branch = git branch --show-current 2>$null
    $output.branch = if ($branch) { $branch.Trim() } else { "unknown" }

    $recentCommits = git log --oneline -3 2>$null
    $output.recent_commits = if ($recentCommits) { $recentCommits -join "`n" } else { "" }

    $statusLines = git status --short 2>$null
    $output.uncommitted_files = if ($statusLines) { @($statusLines).Count } else { 0 }

    $diffStat = git diff --stat 2>$null
    $output.diff_stat = if ($diffStat) { ($diffStat | Select-Object -Last 1).Trim() } else { "sin cambios" }
} catch {
    $output.git_error = $_.Exception.Message
}

# Ramas mergeadas en develop (para que el agente sepa si hay limpieza pendiente)
try {
    $output.merged_branches = @(git branch --merged develop 2>$null |
        Where-Object { $_ -notmatch "^\*|main|develop" } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" })
} catch {
    $output.merged_branches = @()
}

$output | ConvertTo-Json -Depth 5
