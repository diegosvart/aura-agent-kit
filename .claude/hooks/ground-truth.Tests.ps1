# ground-truth.Tests.ps1 — Pester 3.4.0 (Issue #370, Paso 1b: harness H0)
#
# Oraculo independiente de la implementacion: cada comando se ejecuta en un bash REAL con STUBS
# (git, gh, sudo, env, watch, xargs) en un PATH aislado. Los stubs solo registran su argv ya
# dequoteado por bash en un log y nunca ejecutan nada real. Del log se DERIVA si la invocacion
# guardada (gh pr create sin --base develop / git push) se ejecuto de verdad. Invariante: si se
# ejecuto, el guard sobre el comando ORIGINAL debe bloquear.
#
# Modelo de los stubs: sudo/env/watch/xargs, ademas de loguear, ejecutan con `bash -c` cada
# argumento que contenga espacios (modelan wrappers que interpretan un string como comando:
# `sudo -b "..."` de los tests historicos, `watch`, `xargs sh -c`). Es conservador y se acota con
# GT_DEPTH. `env` ademas ejecuta el comando que sigue a sus VAR=x.
#
# Se salta con aviso si no hay un bash tipo POSIX con cygpath (Git for Windows).

. (Join-Path $PSScriptRoot 'pr-base-guard.ps1')
. (Join-Path $PSScriptRoot 'gh-account-guard.ps1')

function Find-GroundTruthBash {
    $candidates = @(
        'C:\Program Files\Git\bin\bash.exe',
        'C:\Program Files (x86)\Git\bin\bash.exe'
    )
    foreach ($c in $candidates) {
        if ((Test-Path $c) -and (Test-Path (Join-Path (Split-Path (Split-Path $c) -Parent) 'usr\bin\cygpath.exe'))) { return $c }
    }
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -notmatch '\\system32\\') { return $cmd.Source }
    return $null
}

$script:GtBash = Find-GroundTruthBash

# Prefijos: A (legitimos), B (con expansion), C (adversariales historicos), J/K (palabra-comando).
$script:GtPrefixes = @(
    '',
    'FOO=a', 'FOO="a b"', "FOO='a b'", 'A="x y" B=z', 'VAR=x"y z"', 'FOO=', 'FOO=""', 'FOO=a\ b',
    'FOO=$(echo git)', 'FOO=$(echo a b)', 'FOO=`echo git`', 'FOO=${X:-git}', 'FOO=$((1+1))',
    'FOO="$(echo git)"', 'FOO=x$(echo git)', 'FOO=${ echo git; }', 'FOO="a $(true) c"', 'FOO=$(echo git )',
    'FOO="sudo git"', "FOO='a git'", 'FOO="a git"', 'FOO=x"a git"', "FOO=x'a git'", 'FOO=-"a git"',
    'FOO=x"a gh"', 'A=1 FOO=x"a git"', 'FOO=~"a git"', 'FOO=\"a git\"', "FOO=`$'a git'", 'FOO=$"a git"',
    'FOO="a"git', 'FOO=a"b git"', 'FOO=x=y"a git"'
)
$script:GtWrappers = @('', 'time env sudo ')
$script:GtTails = @(
    'git commit -m "{P}"',
    'sudo -b "{P}"',
    'bash -c "{P}"',
    'sudo -b "x --body ''{P}''"',
    '{P}'
)

function New-GtStubs {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('gt-stubs-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $stub = @'
#!/usr/bin/bash
n=${0##*/}
{ printf '%s' "$n"; for a in "$@"; do printf ' %s' "$a"; done; printf '\n'; } >> "$GT_LOG"
case "$n" in git|gh) exit 0;; esac
d=${GT_DEPTH:-0}
[ "$d" -ge 4 ] && exit 0
export GT_DEPTH=$((d+1))
while [ $# -gt 0 ]; do case "$1" in -*|*=*) shift ;; *) break ;; esac; done
if [ $# -eq 1 ]; then
  bash -c "$1" >/dev/null 2>&1 </dev/null
elif [ $# -gt 1 ]; then
  "$@" >/dev/null 2>&1 </dev/null
fi
exit 0
'@
    $stub = $stub -replace "`r`n", "`n"
    foreach ($n in 'git', 'gh', 'sudo', 'env', 'watch', 'xargs') {
        [IO.File]::WriteAllText((Join-Path $dir $n), $stub, (New-Object Text.UTF8Encoding($false)))
    }
    $driver = @'
#!/usr/bin/bash
export PATH="$GT_STUBS:/usr/bin:/bin"
n=$(wc -l < "$GT_CMDS")
jobs_n=${GT_JOBS:-12}
per=$(( (n + jobs_n - 1) / jobs_n ))
run_chunk() {
  local log="$GT_STUBS/log.$2" i=$2 line
  export GT_LOG="$log"
  while IFS= read -r line; do
    : > "$log"
    GT_DEPTH=0 bash -c "$line" >/dev/null 2>&1 </dev/null
    echo "### $i"
    cat "$log"
    i=$((i+1))
  done < "$1" > "$3"
}
split -d -a 3 -l "$per" "$GT_CMDS" "$GT_STUBS/chunk."
k=0
for f in "$GT_STUBS"/chunk.*; do
  run_chunk "$f" $((k*per)) "$f.out" &
  k=$((k+1))
done
wait
for f in "$GT_STUBS"/chunk.*.out; do cat "$f"; done
'@ -replace "`r`n", "`n"
    [IO.File]::WriteAllText((Join-Path $dir 'driver.sh'), $driver, (New-Object Text.UTF8Encoding($false)))
    return $dir
}

# Ejecuta cada comando en bash real; devuelve, por comando, las lineas de log de los stubs.
function Invoke-GroundTruth {
    param([string[]]$Commands, [string]$StubDir)
    $bash = $script:GtBash
    $cygpath = Join-Path (Split-Path (Split-Path $bash -Parent) -Parent) 'usr\bin\cygpath.exe'
    $toPosix = { param($p) (& $cygpath -u $p).Trim() }
    $cmdsFile = Join-Path $StubDir 'cmds.txt'
    [IO.File]::WriteAllText($cmdsFile, (($Commands -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
    $env:GT_STUBS = & $toPosix $StubDir
    $env:GT_LOG = (& $toPosix $StubDir) + '/log.txt'
    $env:GT_CMDS = & $toPosix $cmdsFile
    $out = & $bash -c ('chmod +x "$GT_STUBS"/* 2>/dev/null; exec /usr/bin/bash "$GT_STUBS/driver.sh"') 2>$null
    Remove-Item Env:GT_STUBS, Env:GT_LOG, Env:GT_CMDS -ErrorAction SilentlyContinue

    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($c in $Commands) { $results.Add((New-Object System.Collections.Generic.List[string])) }
    Write-Host ("  ground-truth: {0} comandos, salida bash: {1} lineas" -f $Commands.Count, @($out).Count)
    $idx = -1
    foreach ($line in $out) {
        if ($line -match '^### (\d+)$') { $idx = [int]$Matches[1]; continue }
        if ($idx -ge 0 -and $idx -lt $results.Count) { $results[$idx].Add($line) }
    }
    return $results
}

# La invocacion guardada se ejecuto de verdad si un stub git/gh recibio los args guardados.
function Test-GtExecutedPrCreate {
    param($LogLines)
    foreach ($l in $LogLines) {
        if ($l -match '^gh pr create\b' -and $l -notmatch '--base develop\b') { return $true }
    }
    return $false
}
function Test-GtExecutedGitPush {
    param($LogLines)
    foreach ($l in $LogLines) { if ($l -match '^git push\b') { return $true } }
    return $false
}

function Get-GtCombos {
    param([string]$Payload)
    $combos = New-Object System.Collections.Generic.List[string]
    foreach ($p in $script:GtPrefixes) {
        $pre = if ($p) { "$p " } else { '' }
        foreach ($w in $script:GtWrappers) {
            foreach ($t in $script:GtTails) {
                $combos.Add($pre + $w + $t.Replace('{P}', $Payload))
            }
        }
    }
    return $combos
}

# Casos explicitos J (dequoting de la palabra detectada, M-B) y K (flags largos x palabra-comando).
$script:GtJPrCreate = @(
    'gh pr "create" --base main', 'gh "pr" create --base main', "gh pr cr'eate' --base main",
    'gh pr crea\te --base main', 'g"h" pr create --base main', '"gh" pr create --base main',
    'GH PR CREATE --base main', 'FOO=1 sudo gh pr "create" --base main', 'gh pr create --b"ase" main'
)
$script:GtJGitPush = @('git "push" origin main', 'git pu\sh origin main', "g'i't push origin main")
$script:GtKPrCreate = @(
    'sudo --body "gh pr create --base main --title x"',
    'sudo -b "x --body ''gh pr create --base main --title x''"',
    'bash -c "x --title ''gh pr create --base main --title x''"',
    'xargs -I{} sh -c "--notes ''gh pr create --base main --title x''"',
    'sudo --body="gh pr create --base main --title x"',
    'watch --message "gh pr create --base main --title x"'
)

function Format-GtViolations {
    param($List)
    if ($List.Count -eq 0) { return '' }
    $shown = @($List | Select-Object -First 40)
    return ("$($List.Count) violaciones; primeras $($shown.Count):`n" + ($shown -join "`n"))
}

if (-not $script:GtBash) {
    Write-Host 'ground-truth.Tests.ps1: SALTADO -- no hay bash POSIX con cygpath (Git for Windows).'
    Describe 'ground-truth (bash real)' {
        It 'saltado: sin bash' { $true | Should Be $true }
    }
    return
}

$script:GtStubDir = New-GtStubs
$script:GtPrPayload = 'gh pr create --base main --title x'
$script:GtPushPayload = 'git push origin x'

# Una sola corrida de bash (en paralelo) para todos los comandos de la suite.
$script:GtPrCmds = @(Get-GtCombos -Payload $script:GtPrPayload)
$script:GtPushCmds = @(Get-GtCombos -Payload $script:GtPushPayload)
$script:GtJCmds = @($script:GtJPrCreate + $script:GtJGitPush)
$gtAll = @($script:GtPrCmds + $script:GtPushCmds + $script:GtJCmds)
$gtLogs = Invoke-GroundTruth -Commands $gtAll -StubDir $script:GtStubDir
$gtLogs = @($gtLogs)
$gtN1 = $script:GtPrCmds.Count
$gtN2 = $gtN1 + $script:GtPushCmds.Count
$script:GtPrLogs = $gtLogs[0..($gtN1 - 1)]
$script:GtPushLogs = $gtLogs[$gtN1..($gtN2 - 1)]
$script:GtJLogs = $gtLogs[$gtN2..($gtLogs.Count - 1)]

Describe 'Ground truth bash real - pr-base-guard (producto prefijo x wrapper x cola)' {
    Mock Write-GuardLog { }
    Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }

    $cmds = $script:GtPrCmds
    $logs = $script:GtPrLogs
    $executed = 0
    $violations = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $cmds.Count; $i++) {
        if (Test-GtExecutedPrCreate -LogLines $logs[$i]) {
            $executed++
            $r = Test-PrBaseGuard -Command $cmds[$i]
            if (-not ($r -and $r.decision -eq 'block')) { $violations.Add($cmds[$i]) }
        }
    }

    It 'el harness ejecuta de verdad la invocacion guardada en una parte de los comandos' {
        ($executed -gt 50) | Should Be $true
    }

    It 'si bash ejecuto gh pr create sin --base develop, el guard bloquea' {
        (Format-GtViolations $violations) | Should Be ''
    }
}

Describe 'Ground truth bash real - gh-account-guard (producto prefijo x wrapper x cola)' {
    Mock Write-GuardLog { }
    Mock Get-ExpectedGhAccount { 'diegosvart' }
    Mock Get-ActiveGhAccount { 'otra' }

    $cmds = $script:GtPushCmds
    $logs = $script:GtPushLogs
    $executed = 0
    $violations = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $cmds.Count; $i++) {
        if (Test-GtExecutedGitPush -LogLines $logs[$i]) {
            $executed++
            $r = Test-GhAccountGuard -Command $cmds[$i]
            if (-not ($r -and $r.decision -eq 'block')) { $violations.Add($cmds[$i]) }
        }
    }

    It 'el harness ejecuta de verdad git push en una parte de los comandos' {
        ($executed -gt 50) | Should Be $true
    }

    It 'si bash ejecuto git push, el guard bloquea' {
        (Format-GtViolations $violations) | Should Be ''
    }
}

Describe 'Ground truth bash real - casos explicitos J (dequoting de la palabra detectada)' {
    Mock Write-GuardLog { }
    Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
    Mock Get-ExpectedGhAccount { 'diegosvart' }
    Mock Get-ActiveGhAccount { 'otra' }

    $all = $script:GtJCmds
    $logs = $script:GtJLogs

    It 'bash confirma que cada caso J ejecuta la invocacion guardada (el oraculo es valido)' {
        $bad = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $all.Count; $i++) {
            $ok = (Test-GtExecutedPrCreate -LogLines $logs[$i]) -or (Test-GtExecutedGitPush -LogLines $logs[$i])
            if (-not $ok) { $bad.Add($all[$i]) }
        }
        (Format-GtViolations $bad) | Should Be ''
    }

    It 'pr-base-guard bloquea los J con gh pr create' {
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($c in $script:GtJPrCreate) {
            $r = Test-PrBaseGuard -Command $c
            if (-not ($r -and $r.decision -eq 'block')) { $bad.Add($c) }
        }
        (Format-GtViolations $bad) | Should Be ''
    }

    It 'gh-account-guard bloquea los J con gh pr create' {
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($c in $script:GtJPrCreate) {
            $r = Test-GhAccountGuard -Command $c
            if (-not ($r -and $r.decision -eq 'block')) { $bad.Add($c) }
        }
        (Format-GtViolations $bad) | Should Be ''
    }

    It 'gh-account-guard bloquea los J con git push' {
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($c in $script:GtJGitPush) {
            $r = Test-GhAccountGuard -Command $c
            if (-not ($r -and $r.decision -eq 'block')) { $bad.Add($c) }
        }
        (Format-GtViolations $bad) | Should Be ''
    }
}

Describe 'Ground truth bash real - casos explicitos K (flags largos x palabra-comando)' {
    Mock Write-GuardLog { }
    Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
    Mock Get-ExpectedGhAccount { 'diegosvart' }
    Mock Get-ActiveGhAccount { 'otra' }

    It 'pr-base-guard bloquea los K (el plan exige fail-closed aunque bash no los ejecute)' {
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($c in $script:GtKPrCreate) {
            $r = Test-PrBaseGuard -Command $c
            if (-not ($r -and $r.decision -eq 'block')) { $bad.Add($c) }
        }
        (Format-GtViolations $bad) | Should Be ''
    }

    It 'gh-account-guard bloquea los K' {
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($c in $script:GtKPrCreate) {
            $r = Test-GhAccountGuard -Command $c
            if (-not ($r -and $r.decision -eq 'block')) { $bad.Add($c) }
        }
        (Format-GtViolations $bad) | Should Be ''
    }

    It 'contraste: gh issue create --body y git commit --message con el comando como texto NO bloquean' {
        (Test-PrBaseGuard -Command 'gh issue create --body "gh pr create --base main"') | Should Be $null
        (Test-PrBaseGuard -Command 'git commit --message "gh pr create --base main"') | Should Be $null
        (Test-GhAccountGuard -Command 'gh issue create --body "git push origin x"') | Should Be $null
        (Test-GhAccountGuard -Command 'git commit --message "git push origin x"') | Should Be $null
    }
}

Remove-Item -Recurse -Force $script:GtStubDir -ErrorAction SilentlyContinue
