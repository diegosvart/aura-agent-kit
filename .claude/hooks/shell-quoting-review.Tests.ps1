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

Describe 'Rendimiento de los guards con comandos largos (review #370, B3)' {
    It 'script de 600 lineas con redirecciones se evalua en menos de 4 s por guard' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'diegosvart' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $lines = 1..600 | ForEach-Object { "echo `"linea $_ con texto de relleno para alargar el comando`" >> salida.log" }
        $cmd = $lines -join "`n"
        $t1 = Measure-Command { Test-GhAccountGuard -Command $cmd | Out-Null }
        $t2 = Measure-Command { Test-PrBaseGuard -Command $cmd | Out-Null }
        $t1.TotalSeconds | Should BeLessThan 4
        $t2.TotalSeconds | Should BeLessThan 4
    }
    It '1500 segmentos encadenados con && se evaluan en menos de 6 s por guard' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'diegosvart' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $cmd = (1..1500 | ForEach-Object { "ls dir$_" }) -join ' && '
        $t1 = Measure-Command { Test-GhAccountGuard -Command $cmd | Out-Null }
        $t2 = Measure-Command { Test-PrBaseGuard -Command $cmd | Out-Null }
        $t1.TotalSeconds | Should BeLessThan 6
        $t2.TotalSeconds | Should BeLessThan 6
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
