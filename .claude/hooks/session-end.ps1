# session-end.ps1
# Hook: SessionEnd
# Crea backup de current-session.json y emite contexto de cierre para el agente

$output = @{}

$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sessionFile = Join-Path $projectRoot ".agent\memory\current-session.json"
$backupDir   = Join-Path $projectRoot ".agent\memory\backups"

# Backup de current-session.json
$output.backup_created = $false
$output.backup_path = $null

if (Test-Path $sessionFile) {
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $backupFile = Join-Path $backupDir "session-$timestamp.json"

    Copy-Item -Path $sessionFile -Destination $backupFile -Force
    $output.backup_created = $true
    $output.backup_path = ".agent/memory/backups/session-$timestamp.json"

    # Mantener solo los últimos 10 backups
    Get-ChildItem -Path $backupDir -Filter "session-*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 10 |
        Remove-Item -Force
}

# gh auth check
try {
    $null = gh auth status 2>&1
    $ghAuthenticated = ($LASTEXITCODE -eq 0)
} catch {
    $ghAuthenticated = $false
}
$output.gh_authenticated = $ghAuthenticated

# Detección de cambios sin commit
try {
    $statusLines = git status --short 2>$null
    $output.uncommitted_files = if ($statusLines) { @($statusLines).Count } else { 0 }
} catch {
    $output.uncommitted_files = 0
}

# Commits adelante de develop sin PR
try {
    $branch = git branch --show-current 2>$null
    $output.branch = if ($branch) { $branch.Trim() } else { "unknown" }

    $commitsAhead = git log "origin/develop..HEAD" --oneline 2>$null
    $output.commits_ahead_develop = if ($commitsAhead) { @($commitsAhead).Count } else { 0 }
} catch {
    $output.commits_ahead_develop = 0
}

# PRs abiertas para esta rama (si gh autenticado)
$output.open_prs = 0
if ($ghAuthenticated -and $output.branch -ne "unknown") {
    try {
        $prJson = gh pr list --head $output.branch --state open --json number 2>$null
        if ($prJson) {
            $output.open_prs = ($prJson | ConvertFrom-Json).Count
        }
    } catch { }
}

# PRs mergeadas recientemente — fast-path para Paso 3 de session_end
$output.recently_merged_prs = @()
if ($ghAuthenticated) {
    try {
        $mergedJson = gh pr list --state merged --limit 5 --json number,title,mergedAt 2>$null
        if ($mergedJson) { $output.recently_merged_prs = ($mergedJson | ConvertFrom-Json) }
    } catch { }
}

# Issues cerrados recientemente — fast-path para Paso 3 de session_end
$output.recently_closed_issues = @()
if ($ghAuthenticated) {
    try {
        $closedJson = gh issue list --state closed --limit 5 --json number,title,closedAt 2>$null
        if ($closedJson) { $output.recently_closed_issues = ($closedJson | ConvertFrom-Json) }
    } catch { }
}

# Output JSON para que el agente ejecute el protocolo session_end.md con contexto
$output | ConvertTo-Json -Depth 5
