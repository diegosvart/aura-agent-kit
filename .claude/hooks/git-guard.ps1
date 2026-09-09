# git-guard.ps1 — PreToolUse hook
#
# Intercepta comandos Bash y PowerShell antes de ejecutarse.
# Bloquea git commit y git push cuando la rama activa es develop o main.
#
# Por qué existe: las reglas en markdown (harness-core.md, AGENTS.md) son soft.
# Este hook es enforcement duro al nivel del harness — el modelo no puede ignorarlo.
#
# Claude Code inyecta el input del tool como JSON en stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }
#
# Issue #253: un `git push` hacia un repositorio DISTINTO al origin del checkout (ej. mirror
# push a un repo sandbox) no es "push directo a develop/main de este proyecto" — es una
# sincronización explícita a otro destino. El hook original bloqueaba igual porque solo
# miraba la rama local activa, sin resolver a qué repo apuntaba el push. Mismo patrón que
# pr-base-guard.ps1 ya usa para `--repo`: comparar el repo destino contra Get-OriginRepoSlug
# y salir sin bloquear si difieren.
#
# Estructura: funciones testeables (git-guard.Tests.ps1 las dot-sourcea y mockea
# Get-CurrentBranch/Get-OriginRepoSlug/Get-RemoteUrl) + un punto de entrada al final que
# solo corre cuando el script se invoca directamente, no al dot-source.

function Write-GuardLog {
    param([string]$Reason)
    try {
        $logPath = Join-Path $PSScriptRoot "git-guard.log"
        $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $logPath -Value "[$timestamp] FAIL-OPEN: $Reason" -ErrorAction SilentlyContinue
    } catch {
        # Si ni el log funciona, no hay nada más que hacer — no debe bloquear el flujo.
    }
}

function Get-CurrentBranch {
    try {
        return (git branch --show-current 2>$null).Trim()
    } catch {
        return $null
    }
}

function Get-RemoteUrl {
    param([string]$Name)
    try {
        return (git remote get-url $Name 2>$null)
    } catch {
        return $null
    }
}

function Get-RepoSlugFromUrl {
    param([string]$Url)
    if (-not $Url) { return $null }
    if ($Url -match '[:/]([^/:]+)/([^/]+?)(\.git)?$') {
        return "$($Matches[1])/$($Matches[2])"
    }
    return $null
}

function Get-OriginRepoSlug {
    return Get-RepoSlugFromUrl -Url (Get-RemoteUrl -Name 'origin')
}

# Extrae el primer token posicional despues de 'git push' (remote nombrado o URL explicita),
# saltando flags. Los flags de $valueFlags consumen el token siguiente; el resto (--mirror,
# --force, --all, --tags, --delete, --set-upstream, --dry-run, etc.) son booleanos.
function Get-PushTargetToken {
    param([string]$Command)
    if ($Command -notmatch '\bgit\s+push\b') { return $null }
    $rest = $Command.Substring($Command.IndexOf($Matches[0]) + $Matches[0].Length)
    $valueFlags = @('o', 'push-option')
    $tokenMatches = [regex]::Matches($rest, '"[^"]*"|''[^'']*''|\S+')
    $tokens = @($tokenMatches | ForEach-Object { $_.Value.Trim('"').Trim("'") })

    $i = 0
    while ($i -lt $tokens.Count) {
        $tok = $tokens[$i]
        if ($tok -match '^--?([A-Za-z-]+)') {
            if ($tok -notmatch '=' -and ($Matches[1] -in $valueFlags)) { $i += 2; continue }
            $i += 1
            continue
        }
        return $tok
    }
    return $null
}

# Resuelve a que repo (owner/repo) apunta el destino de un `git push`. Sin argumento
# explicito, git empuja al remote tracking (origin, por defecto) -- mismo repo. Con URL
# explicita, se extrae el slug directo. Con nombre de remote, se resuelve via
# `git remote get-url`. Si el remote no resuelve, se trata como "no determinable" (el
# llamador aplica fail-safe: mantener la proteccion activa).
function Get-PushDestinationRepoSlug {
    param([string]$Command)
    $target = Get-PushTargetToken -Command $Command
    if (-not $target) { return Get-OriginRepoSlug }
    if ($target -match '^(https?://|git@|ssh://)') {
        return Get-RepoSlugFromUrl -Url $target
    }
    $url = Get-RemoteUrl -Name $target
    if ($url) { return Get-RepoSlugFromUrl -Url $url }
    return $null
}

function Test-GitGuard {
    param([string]$Command)

    $is_commit = $Command -match '\bgit\s+commit\b'
    $is_push   = $Command -match '\bgit\s+push\b'

    if (-not ($is_commit -or $is_push)) { return $null }

    if ($is_push) {
        $originSlug = Get-OriginRepoSlug
        $destSlug = Get-PushDestinationRepoSlug -Command $Command
        if ($originSlug -and $destSlug -and ($destSlug -ne $originSlug)) {
            # Push a un repo distinto al del checkout actual -- fuera de alcance de esta regla.
            return $null
        }
    }

    $branch = Get-CurrentBranch
    if ($null -eq $branch) {
        Write-GuardLog "No se pudo resolver 'git branch --show-current' -- comando '$Command' no evaluado."
        return $null
    }
    $branch = $branch.Trim()

    $protected = @("develop", "main")

    if ($branch -in $protected) {
        $operation = if ($is_commit) { "commit" } else { "push" }
        $reason = "git-guard: 'git $operation' bloqueado en rama '$branch'. Crear una feature branch antes de commitear. Ejemplo: git checkout -b feature/issue-N-descripcion"
        return @{ decision = "block"; reason = $reason }
    }

    return $null
}

# --- Punto de entrada (solo al ejecutar directamente, no al dot-source para tests) ---
if ($MyInvocation.InvocationName -ne '.') {
    $input_json = $null
    try {
        $raw = [Console]::In.ReadToEnd()
        $input_json = $raw | ConvertFrom-Json
    } catch {
        Write-GuardLog "No se pudo parsear stdin como JSON ($($_.Exception.Message)) — hook no evaluó el comando."
        exit 0
    }

    $command = ""
    if ($input_json.tool_input.command) {
        $command = $input_json.tool_input.command
    }

    if (-not $command) { exit 0 }

    $result = Test-GitGuard -Command $command
    if ($result) {
        $response = @{ decision = $result.decision; reason = $result.reason } | ConvertTo-Json -Compress
        Write-Output $response
        exit 2
    }

    exit 0
}
