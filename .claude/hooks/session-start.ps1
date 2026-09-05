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

# Auto-setup de git hooks nativos (.githooks/) — segunda capa de enforcement de "nunca
# push directo a develop/main", independiente de Claude Code. core.hooksPath es config local
# de Git: no se versiona ni se auto-aplica al clonar. Este bloque lo setea la primera vez que
# se abre una sesion de Claude Code en el repo (SessionStart si esta versionado y se auto-carga),
# eliminando el paso manual que antes bloqueaba adoptar hooks nativos. Fail-open, igual que
# git-guard.ps1 — si esto falla, no debe romper session-start.
try {
    $githooksDir = Join-Path $projectRoot ".githooks"
    if (Test-Path $githooksDir) {
        $currentHooksPath = (git config --get core.hooksPath 2>$null)
        if ($currentHooksPath -ne ".githooks") {
            git config core.hooksPath ".githooks" 2>$null
            $logPath = Join-Path $PSScriptRoot "session-start.log"
            $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
            Add-Content -Path $logPath -Value "[$timestamp] core.hooksPath configurado a .githooks (era: '$currentHooksPath')" -ErrorAction SilentlyContinue
            $output.githooks_configured = $true
        } else {
            $output.githooks_configured = $false
        }
    }
} catch {
    # Fail-open — sin rastro si ni el log funciona, no debe bloquear session-start
}

# Auto-init de .aura sin inicializar (Issue #200) — un worktree nuevo comparte .git pero no
# el checkout de submódulos; `.aura` puede existir como gitlink vacío sin que nada lo note. Se
# reutiliza el mismo patrón fail-open del bloque de arriba: detectar, actuar, exponer en el
# output para que session_start.md lo reporte, nunca bloquear si falla.
try {
    $auraPath = Join-Path $projectRoot ".aura"
    if (Test-Path $auraPath) {
        Push-Location $projectRoot
        try {
            $submoduleStatus = git submodule status .aura 2>$null
        } finally {
            Pop-Location
        }
        if ($submoduleStatus -and $submoduleStatus.TrimStart().StartsWith("-")) {
            Push-Location $projectRoot
            try {
                git submodule update --init .aura 2>$null
                $output.aura_submodule_initialized = ($LASTEXITCODE -eq 0)
            } finally {
                Pop-Location
            }
        } else {
            $output.aura_submodule_initialized = $false
        }
    }
} catch {
    # Fail-open — igual que el bloque de core.hooksPath
}

# gh auth check
try {
    $null = gh auth status 2>&1
    $output.gh_authenticated = ($LASTEXITCODE -eq 0)
} catch {
    $output.gh_authenticated = $false
}

# Nombre y topics del repo activo (Issue #201) — mismo costo que la consulta de visibility
# que ya corre en protocols/session_start.md Paso 3; se resuelve acá para no duplicar la
# llamada gh en dos lugares distintos.
if ($output.gh_authenticated) {
    try {
        $repoJson = gh repo view --json name,repositoryTopics 2>$null
        if ($repoJson) {
            $repoInfo = $repoJson | ConvertFrom-Json
            $output.repo_name = $repoInfo.name
            $output.repo_topics = @($repoInfo.repositoryTopics | ForEach-Object { $_.name })
        }
    } catch {
        # Fail-open — sin nombre/topics no debe bloquear session-start
    }
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

# Ideas backlog count
$ideasFile = Join-Path $projectRoot ".agent\memory\ideas.md"
try {
    if (Test-Path $ideasFile) {
        $ideasContent = Get-Content $ideasFile -Raw
        $output.ideas_count = ([regex]::Matches($ideasContent, "^## \[", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    } else {
        $output.ideas_count = 0
    }
} catch {
    $output.ideas_count = 0
}

# Detección de actualización disponible del harness (D2 — cacheado, silencioso si falla)
# Ver docs/aura/specs/2026-07-30-harness-self-update.md
try {
    $auraPath = Join-Path $projectRoot ".aura"
    $cacheFile = Join-Path $projectRoot ".agent\memory\harness-update-check.json"
    # TTL bajo a propósito: el chequeo corre fuera del contexto de Claude (subproceso bash del
    # hook), no consume tokens del agente — el único costo real es la latencia de red del
    # `git fetch --tags` (con timeout de 5s, fail-open). 30 min prioriza frescura de detección
    # sobre evitar ese fetch, sin llegar a 0 para no repetirlo en sesiones muy seguidas.
    $ttlHours = 0.5
    $cache = $null

    if (Test-Path $cacheFile) {
        try {
            $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
        } catch {
            $cache = $null
        }
    }

    $cacheIsFresh = $false
    if ($cache -and $cache.last_checked) {
        $lastChecked = Get-Date $cache.last_checked
        $cacheIsFresh = ((Get-Date).ToUniversalTime() - $lastChecked.ToUniversalTime()).TotalHours -lt $ttlHours
    }

    # Resolver bash de Git for Windows explícitamente — en máquinas con WSL instalado,
    # `Get-Command bash` puede resolver al relay de System32\bash.exe (WSL) en vez de
    # Git Bash, que falla si no hay distro configurada aunque "haya bash en PATH".
    $gitBash = $null
    $gitCmd = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($gitCmd) {
        $gitRoot = Split-Path (Split-Path $gitCmd -Parent) -Parent
        $candidate = Join-Path $gitRoot "bin\bash.exe"
        if (Test-Path $candidate) { $gitBash = $candidate }
    }

    if ($cacheIsFresh) {
        if ($cache.harness_update_available) {
            $output.harness_update_available = $true
            $output.harness_latest_version = $cache.harness_latest_version
            if ($cache.harness_update_channel) { $output.harness_update_channel = $cache.harness_update_channel }
            if ($cache.harness_update_plugin_id) { $output.harness_update_plugin_id = $cache.harness_update_plugin_id }
        }
    } elseif ((Test-Path (Join-Path $auraPath ".git")) -and $gitBash -and (Get-Command git -ErrorAction SilentlyContinue)) {
        # El script vive en .aura/ (submodule), no en la raíz del repo consumidor —
        # $projectRoot\skills\... solo existe en aura-agent-kit mismo (issue #96)
        $checkScript = Join-Path $auraPath "skills\harness-update\scripts\check-update.sh"
        $remoteTag = ""
        if (Test-Path $checkScript) {
            $remoteTag = (& $gitBash $checkScript $auraPath 2>$null | Select-Object -Last 1)
        }
        $localTag = (git -C $auraPath describe --tags --abbrev=0 2>$null)

        $updateAvailable = [bool]($remoteTag -and ($remoteTag -ne $localTag))

        $newCache = @{
            last_checked              = (Get-Date).ToUniversalTime().ToString("o")
            harness_update_available  = $updateAvailable
            harness_latest_version    = if ($updateAvailable) { $remoteTag } else { $null }
        }
        $newCache | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding utf8

        if ($updateAvailable) {
            $output.harness_update_available = $true
            $output.harness_latest_version = $remoteTag
        }
    } elseif ((Test-Path (Join-Path $auraPath ".git")) -and -not $gitBash) {
        # .aura/ es un checkout git real (se esperaba poder chequear) pero no se pudo resolver
        # bash de Git for Windows — a diferencia de "sin .aura/", esto sí es una falla real.
        $output.harness_update_check_error = "gitBash no resuelto (Git for Windows no encontrado)"
    } elseif (Test-Path $auraPath) {
        # .aura/ existe pero sin .git — no es submódulo (modelo legacy), y este chequeo no
        # tiene forma de evaluar la versión de un consumidor instalado vía plugin/marketplace
        # (Claude Code nativo). Antes esta rama quedaba muda (ni error, ni aviso), lo que hizo
        # indistinguible "no aplica" de "el chequeo nunca corrió" — mismo anti-patrón que
        # motivó harness_update_check_error (Issue #111), ahora aplicado a este caso. No se
        # expone en el resumen de sesión (ruidoso en cada sesión de un repo que ya no usa
        # submódulo) — queda en el JSON del hook para diagnóstico manual.
        $output.harness_update_not_applicable = "sin .git en .aura/ (no es submódulo) — ver Issue de seguimiento sobre chequeo de version para consumidores vía plugin"
    } else {
        # $auraPath no existe en absoluto -- consumidor probable via plugin de Claude Code
        # (marketplace), sin submodulo .aura/. Compara la version instalada del plugin "aura"
        # (claude plugin list --json) contra la version cacheada localmente por el marketplace
        # configurado (claude plugin marketplace list --json -> installLocation), sin depender
        # de tags ni de red propia -- el refresh de ese cache ya lo maneja Claude Code (Issue
        # #181). Mutuamente excluyente con el chequeo legacy de arriba por construccion: esta
        # rama solo corre cuando $auraPath no existe.
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            $installedJson = & claude plugin list --json 2>$null
            $installed = if ($installedJson) { $installedJson | ConvertFrom-Json } else { $null }
            $auraInstalled = @($installed) |
                Where-Object { $_.id -like "aura@*" } |
                Sort-Object -Property @{Expression = { $_.scope -eq "project" }; Descending = $true } |
                Select-Object -First 1

            if ($auraInstalled) {
                $marketplaceName = ($auraInstalled.id -split "@", 2)[1]
                $marketplacesJson = & claude plugin marketplace list --json 2>$null
                $marketplaces = if ($marketplacesJson) { $marketplacesJson | ConvertFrom-Json } else { $null }
                $marketplace = @($marketplaces) | Where-Object { $_.name -eq $marketplaceName } | Select-Object -First 1

                if ($marketplace -and $marketplace.installLocation) {
                    $cachedManifest = Join-Path $marketplace.installLocation ".claude-plugin\plugin.json"
                    if (Test-Path $cachedManifest) {
                        $cachedVersion = $null
                        try {
                            $cachedVersion = (Get-Content $cachedManifest -Raw | ConvertFrom-Json).version
                        } catch { }

                        if ($cachedVersion) {
                            $pluginUpdateAvailable = ($cachedVersion -ne $auraInstalled.version)

                            $newCache = @{
                                last_checked             = (Get-Date).ToUniversalTime().ToString("o")
                                harness_update_available  = $pluginUpdateAvailable
                                harness_latest_version    = if ($pluginUpdateAvailable) { $cachedVersion } else { $null }
                                harness_update_channel    = "plugin"
                                harness_update_plugin_id  = $auraInstalled.id
                            }
                            $newCache | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding utf8

                            if ($pluginUpdateAvailable) {
                                $output.harness_update_available = $true
                                $output.harness_latest_version = $cachedVersion
                                $output.harness_update_channel = "plugin"
                                $output.harness_update_plugin_id = $auraInstalled.id
                            }
                        }
                    }
                }
            }
        }
    }
} catch {
    # Mismo patrón que el bloque de git info básica (línea ~27): no tragarse el error, dejarlo
    # en el JSON que ya se lee cada sesión — evita que "no hay update" y "el chequeo no corrió"
    # sean indistinguibles (Issue #111).
    $output.harness_update_check_error = $_.Exception.Message
}

# Output como JSON para que Claude lo use como contexto
$output | ConvertTo-Json -Depth 5
