. (Join-Path $PSScriptRoot 'gh-account-guard.ps1')
. (Join-Path $PSScriptRoot 'pr-base-guard.ps1')

$script:NL = "`n"

$script:PrBaseBypass = @(
    'gh pr >/dev/null create --base main'
    'gh >/dev/null pr create --base main'
    'gh pr 2>/dev/null create --base main'
    'gh pr 1>&2 create --base main'
    'gh pr &>/dev/null create --base main'
    'gh pr > /dev/null create --base main'
    ('gh pr \' + $script:NL + 'create --base main')
    'gh pr${IFS}create --base main'
    'gh${IFS}pr create --base main'
    ('git commit -m "$\' + $script:NL + '(gh pr create --base main)"')
)

$script:GhAccountBypass = @(
    'git >/dev/null push origin x'
    'git 2>/dev/null push origin x'
    'git 1>&2 push origin x'
    'git > /dev/null push origin x'
    ('git \' + $script:NL + 'push origin x')
    'git ${IFS}push origin x'
    'git${IFS}push origin x'
    ('git commit -m "$\' + $script:NL + '(git push origin x)"')
)

Describe 'Test-PrBaseGuard - palabras no adyacentes y continuacion de linea (review #370, B1/B2)' {
    foreach ($c in $script:PrBaseBypass) {
        It "bloquea: $($c -replace "`n", '<NL>')" {
            Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
            (Test-PrBaseGuard -Command $c).decision | Should Be 'block'
        }
    }
    It 'sigue permitiendo gh pr create --base develop con redirecciones' {
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        Test-PrBaseGuard -Command 'gh pr create --base develop >/dev/null 2>&1' | Should Be $null
        Test-PrBaseGuard -Command 'gh pr create --base develop 2>&1 | cat' | Should Be $null
        Test-PrBaseGuard -Command 'gh pr view 1 &>/dev/null' | Should Be $null
    }
}

Describe 'Test-GhAccountGuard - palabras no adyacentes y continuacion de linea (review #370, B1/B2)' {
    foreach ($c in $script:GhAccountBypass) {
        It "bloquea con cuenta distinta: $($c -replace "`n", '<NL>')" {
            Mock Get-ExpectedGhAccount { 'diegosvart' }
            Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
            (Test-GhAccountGuard -Command $c).decision | Should Be 'block'
        }
    }
    It 'no bloquea comandos git inocuos con redirecciones' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        Test-GhAccountGuard -Command 'git status 2>&1' | Should Be $null
        Test-GhAccountGuard -Command 'git log --oneline > /dev/null' | Should Be $null
    }
}

function Measure-Scaling {
    param([scriptblock]$Build, [int]$N, [scriptblock]$Run)
    $best = @{}
    foreach ($size in @($N, (2 * $N))) {
        $cmd = & $Build $size
        $times = 1..2 | ForEach-Object { (Measure-Command { & $Run $cmd | Out-Null }).TotalSeconds }
        $best[$size] = ($times | Measure-Object -Minimum).Minimum
    }
    $best[2 * $N] / $best[$N]
}

Describe 'Rendimiento de los guards con comandos largos (review #370, B3; Issue #378)' {
    It 'account guard escala sub-cuadraticamente: t(1200 lineas)/t(600 lineas) < 3.0' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'diegosvart' }
        $build = { param($n) (1..$n | ForEach-Object { "echo `"linea $_ con texto de relleno para alargar el comando`" >> salida.log" }) -join "`n" }
        $run = { param($c) Test-GhAccountGuard -Command $c }
        Test-GhAccountGuard -Command (& $build 100) | Out-Null
        $ratio = Measure-Scaling -Build $build -N 600 -Run $run
        $ratio | Should BeLessThan 3.0
    }
    It 'pr-base guard evalua 600 lineas por debajo del techo de cordura de 30 s' {
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $cmd = (1..600 | ForEach-Object { "echo `"linea $_ con texto de relleno para alargar el comando`" >> salida.log" }) -join "`n"
        (Measure-Command { Test-PrBaseGuard -Command $cmd | Out-Null }).TotalSeconds | Should BeLessThan 30
    }
    It '1500 segmentos encadenados con && se evaluan por debajo del techo de cordura de 30 s por guard' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'diegosvart' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $cmd = (1..1500 | ForEach-Object { "ls dir$_" }) -join ' && '
        (Measure-Command { Test-GhAccountGuard -Command $cmd | Out-Null }).TotalSeconds | Should BeLessThan 30
        (Measure-Command { Test-PrBaseGuard -Command $cmd | Out-Null }).TotalSeconds | Should BeLessThan 30
    }
}

$script:CR = "`r"

Describe 'Ronda 2 del review #370 - redireccion que consume --base, CRLF y subcomando en variable' {
    $prBase = @(
        'gh pr create --title x 2> --base develop'
        'gh pr create --title x > --base develop'
        'gh pr create 2> --base develop --head develop'
        ('gh pr \' + $script:CR + $script:NL + 'create --base main --title x')
        'C=create ; gh pr $C --title x'
        'S=pr ; gh $S create --base main'
        'G=gh ; $G pr create --base main'
    )
    foreach ($c in $prBase) {
        It "pr-base bloquea: $(($c -replace "`r", '<CR>') -replace "`n", '<NL>')" {
            Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
            (Test-PrBaseGuard -Command $c).decision | Should Be 'block'
        }
    }
    $acct = @(
        ('git \' + $script:CR + $script:NL + 'push origin x')
        'P=push ; git $P origin x'
        'G=git ; $G push origin x'
    )
    foreach ($c in $acct) {
        It "gh-account bloquea: $(($c -replace "`r", '<CR>') -replace "`n", '<NL>')" {
            Mock Get-ExpectedGhAccount { 'diegosvart' }
            Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
            (Test-GhAccountGuard -Command $c).decision | Should Be 'block'
        }
    }
    It 'no sobre-bloquea usos legitimos con variables' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        Test-GhAccountGuard -Command 'git -C $dir status' | Should Be $null
        Test-GhAccountGuard -Command 'git commit -m "$msg"' | Should Be $null
        Test-GhAccountGuard -Command '$EDITOR file.txt' | Should Be $null
        Test-PrBaseGuard -Command 'gh pr view $n' | Should Be $null
        Test-PrBaseGuard -Command 'gh pr list --state $s' | Should Be $null
    }
}
