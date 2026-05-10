# session-end.ps1
# Hook: SessionEnd
# Crea un backup timestamped de current-session.json al cerrar la sesión

$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sessionFile = Join-Path $projectRoot ".agent\memory\current-session.json"
$backupDir   = Join-Path $projectRoot ".agent\memory\backups"

if (Test-Path $sessionFile) {
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $backupFile = Join-Path $backupDir "session-$timestamp.json"

    Copy-Item -Path $sessionFile -Destination $backupFile -Force

    # Mantener solo los últimos 10 backups
    Get-ChildItem -Path $backupDir -Filter "session-*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 10 |
        Remove-Item -Force
}

# Salir silenciosamente (exit 0 = no bloquear cierre)
exit 0
