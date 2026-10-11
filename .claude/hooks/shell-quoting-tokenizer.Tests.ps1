# shell-quoting-tokenizer.Tests.ps1 — Pester 3.4.0
#
# Bateria de la palabra-comando por tokenizador (Issue #370). Convencion: "vaciado" = el payload
# PAYX desaparece del resultado de Remove-QuotedContent; "identidad" = el resultado es igual a la
# entrada (fail-closed: el guard sigue viendo el texto).

. (Join-Path $PSScriptRoot 'shell-quoting.ps1')
. (Join-Path $PSScriptRoot 'shell-quoting.TestData.ps1')

Describe 'A. reconocimiento legitimo (vaciado)' {
    $cases = @(
        'git commit -m "PAYX"',
        'FOO=a git commit -m "PAYX"',
        'FOO="a b" git commit -m "PAYX"',
        "FOO='a b' git commit -m ""PAYX""",
        'A="x y" B=z git commit -m "PAYX"',
        'VAR=x"y z" git commit -m "PAYX"',
        'FOO= git commit -m "PAYX"',
        'FOO="" git commit -m "PAYX"',
        "FOO=a`tgit commit -m ""PAYX""",
        'FOO=a\ b git commit -m "PAYX"',
        'FOO="a=b;c" git commit -m "PAYX"',
        "FOO='`$(x)' git commit -m ""PAYX""",
        'A=1 B="x y" env git commit -m "PAYX"',
        'time env command sudo git commit -m "PAYX"',
        'git commit -am "PAYX"',
        'gh pr create -t "PAYX" -b "PAYX"',
        'GIT commit -m "PAYX"',
        'git commit --message "PAYX"',
        'gh issue create --body "PAYX"',
        'gh issue create --title="PAYX"'
    )
    foreach ($c in $cases) {
        It "vacia: $c" {
            (Remove-QuotedContent $c) | Should Not Match 'PAYX'
        }
    }
}

Describe 'B/C. taint y corpus historico (identidad)' {
    $cases = @(
        'FOO=$(echo git) sudo -b "PAYX"',
        'FOO=$(echo a b) sudo -b "PAYX"',
        'FOO=`echo git` sudo -b "PAYX"',
        'FOO=${X:-git} sudo -b "PAYX"',
        'FOO=$((1+1)) sudo -b "PAYX"',
        'FOO="$(echo git)" sudo -b "PAYX"',
        'FOO=x$(echo git) sudo -b "PAYX"',
        'FOO=${ cmd; } sudo -b "PAYX"',
        'FOO="a $(b) c" watch -t "PAYX"',
        'FOO=$(echo git ) sudo -t "PAYX"',
        'FOO="a b sudo -b "PAYX"',
        'FOO=$(echo 1) git commit -m "PAYX"',
        'FOO="sudo git" sudo -b "PAYX"',
        "FOO='a git' sudo -t ""PAYX""",
        'FOO="a git" sudo -t "PAYX"',
        'FOO=x"a git" sudo -b "PAYX"',
        "FOO=x'a git' sudo -b ""PAYX""",
        'FOO=-"a git" sudo -b "PAYX"',
        'FOO=x"a gh" sudo -b "PAYX"',
        'A=1 FOO=x"a git" sudo -b "PAYX"',
        'FOO=x"a git" env sudo -b "PAYX"',
        'FOO=~"a git" sudo -t "PAYX"',
        'FOO=\"a git\" sudo -b "PAYX"',
        "FOO=`$'a git' sudo -b ""PAYX""",
        'FOO=$"a git" sudo -b "PAYX"',
        'FOO="a"git sudo -b "PAYX"',
        'FOO=a"b git" sudo -b "PAYX"',
        'FOO=x=y"a git" sudo -b "PAYX"',
        'watch -t "PAYX"',
        'bash -xt "PAYX"',
        'sudo -m "PAYX"',
        'bash -c "PAYX"',
        "sh -c 'PAYX'",
        'pwsh -Command "PAYX"',
        'FOO="a b" bash -c "PAYX"',
        '1A=x git commit -m "PAYX"',
        'gh-wrapper pr create -t "PAYX"',
        'git-foo commit -m "PAYX"',
        '/usr/bin/git commit -m "PAYX"',
        '>f git commit -m "PAYX"',
        '2>&1 sudo -b "PAYX"',
        '{ git commit -m "PAYX"',
        'g"i"t commit -m "PAYX"',
        'sudo -b"PAYX"',
        'A+=x sudo -b "PAYX"'
    )
    foreach ($c in $cases) {
        It "identidad: $c" {
            (Remove-QuotedContent $c) | Should BeExactly $c
        }
    }
}

Describe 'D. echo/printf solo como palabra-comando' {
    It 'vacia varios literales tras echo' {
        (Remove-QuotedContent 'echo "PAYX" "PAYX"') | Should Be 'echo "" ""'
    }
    It 'vacia echo con prefijo de variable' {
        (Remove-QuotedContent 'FOO=1 echo "PAYX"') | Should Be 'FOO=1 echo ""'
    }
    It 'vacia printf' {
        (Remove-QuotedContent 'printf "%s" "PAYX"') | Should Be 'printf "" ""'
    }
    It 'vacia echo -e' {
        (Remove-QuotedContent 'echo -e "PAYX"') | Should Be 'echo -e ""'
    }
    It 'echo como argumento de otro comando no activa el vaciado' {
        $c = 'FOO=$(echo 1) sudo -b "PAYX"'
        (Remove-QuotedContent $c) | Should BeExactly $c
    }
    It 'echo dentro de un literal previo no activa el vaciado para sudo' {
        $c = 'sudo -b "echo hi" "PAYX"'
        (Remove-QuotedContent $c) | Should BeExactly $c
    }
    It 'echo dentro de bash -c no activa el vaciado' {
        $c = 'bash -c "echo x" "PAYX"'
        (Remove-QuotedContent $c) | Should BeExactly $c
    }
    It 'conserva $() ejecutable dentro de echo' {
        $c = 'echo "$(gh pr create)"'
        (Remove-QuotedContent $c) | Should BeExactly $c
    }
    It 'echo como valor de -m en git no activa la rama echo para el resto' {
        (Remove-QuotedContent 'git commit -m "echo" -F "PAYX"') | Should Match 'PAYX'
    }
}

Describe 'E. Split-ShellSegments con escapes' {
    It 'comilla escapada dentro de comillas dobles no cierra la comilla' {
        @(Split-ShellSegments -Command 'git commit -m "it\"s" && sudo -b "PAYX"').Count | Should Be 2
    }
    It 'separador escapado no separa' {
        @(Split-ShellSegments -Command 'echo a\;b').Count | Should Be 1
    }
    It 'comilla escapada fuera de comillas no abre comilla' {
        @(Split-ShellSegments -Command 'echo \"a && b').Count | Should Be 2
    }
    It 'en comillas simples la barra es literal' {
        @(Split-ShellSegments -Command "echo 'a\' && b").Count | Should Be 2
    }
    It 'barra doble antes de cierre de comilla doble' {
        @(Split-ShellSegments -Command 'echo "a\\" && b').Count | Should Be 2
    }
    It 'barra final no lanza' {
        { Split-ShellSegments -Command 'echo a\' } | Should Not Throw
    }
    It 'CRLF separa' {
        @(Split-ShellSegments -Command "a`r`nb").Count | Should BeGreaterThan 1
    }
    It 'separadores pegados' {
        @(Split-ShellSegments -Command 'a &&b').Count | Should Be 2
        @(Split-ShellSegments -Command 'a&& b').Count | Should Be 2
    }
}

Describe 'F. Test-QuotedIsExecutable' {
    It 'sustitucion de comando' { Test-QuotedIsExecutable -Quoted '"$(x)"' | Should Be $true }
    It 'backtick' { Test-QuotedIsExecutable -Quoted '"`x`"' | Should Be $true }
    It 'funsub con espacio' { Test-QuotedIsExecutable -Quoted '"${ cmd; }"' | Should Be $true }
    It 'funsub con pipe' { Test-QuotedIsExecutable -Quoted '"${|cmd;}"' | Should Be $true }
    It 'expansion de variable no es ejecutable' { Test-QuotedIsExecutable -Quoted '"${VAR}"' | Should Be $false }
    It 'texto plano no es ejecutable' { Test-QuotedIsExecutable -Quoted '"texto"' | Should Be $false }
}

Describe 'G. robustez' {
    It 'cadena vacia y espacios no lanzan' {
        { Remove-QuotedContent '' } | Should Not Throw
        { Remove-QuotedContent '   ' } | Should Not Throw
        { Get-SegmentCommandInfo -Segment '' } | Should Not Throw
    }
    It 'comillas desbalanceadas no lanzan y quedan en identidad' {
        foreach ($c in @('git commit -m "abc', "git commit -m 'abc", 'FOO="a git commit -m "x"', '"', "'")) {
            { Remove-QuotedContent $c } | Should Not Throw
            (Remove-QuotedContent $c) | Should BeExactly $c
        }
    }
    It '4000 prefijos de variable en menos de 2 s' {
        $c = ('A=1 ' * 4000) + 'git commit -m "x"'
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $null = Remove-QuotedContent $c
        $sw.Stop()
        $sw.Elapsed.TotalSeconds | Should BeLessThan 2
    }
    It 'valor de 40000 caracteres en menos de 2 s' {
        $c = 'FOO=' + ('a' * 40000) + ' git commit -m "x"'
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $null = Remove-QuotedContent $c
        $sw.Stop()
        $sw.Elapsed.TotalSeconds | Should BeLessThan 2
    }
    It 'tokens sin palabra-comando valida no lanzan' {
        foreach ($c in @('=x git', '=', 'FOO')) {
            { Remove-QuotedContent $c } | Should Not Throw
        }
    }
}

Describe 'Get-SegmentCommandInfo' {
    It 'devuelve git como palabra-comando tras prefijos y wrappers' {
        $i = Get-SegmentCommandInfo -Segment 'A="x y" B=z sudo git commit -m "x"'
        $i.Command | Should Be 'git'
        $i.Tainted | Should Be $false
    }
    It 'devuelve tokens sin comillas ni escapes' {
        $i = Get-SegmentCommandInfo -Segment 'gh pr "create" --b\ase "x y"'
        ($i.Tokens -join '|') | Should Be 'gh|pr|create|--base|x y'
    }
    It 'marca taint ante sustitucion en el prefijo' {
        (Get-SegmentCommandInfo -Segment 'FOO=$(echo git) sudo -b x').Tainted | Should Be $true
    }
    It 'no marca taint por una sustitucion posterior a la palabra-comando' {
        (Get-SegmentCommandInfo -Segment 'git commit -m "$(date)"').Tainted | Should Be $false
    }
    It 'palabra-comando con comillas es desconocida' {
        (Get-SegmentCommandInfo -Segment 'g"i"t commit').Command | Should BeNullOrEmpty
    }
}

Describe 'J. dequoting de la palabra detectada (Find-SegmentInvocation)' {
    $ghCreate = @('gh', 'pr', 'create')
    $cases = @(
        'gh pr "create" --base main',
        'gh "pr" create --base main',
        "gh pr cr'eate' --base main",
        'gh pr crea\te --base main',
        'g"h" pr create --base main',
        '"gh" pr create --base main',
        'GH PR CREATE --base main',
        'FOO=1 sudo gh pr "create" --base main',
        'gh pr create --base main',
        'FOO=$(echo a) gh pr "create" --base main'
    )
    foreach ($c in $cases) {
        It "detecta gh pr create: $c" {
            (Test-SegmentInvokes -Segment $c -Words $ghCreate) | Should Be $true
        }
    }
    It 'detecta git push con comillas' {
        (Test-SegmentInvokes -Segment 'git "push" origin main' -Words @('git', 'push')) | Should Be $true
        (Test-SegmentInvokes -Segment 'git pu\sh origin main' -Words @('git', 'push')) | Should Be $true
        (Test-SegmentInvokes -Segment "g'i't push" -Words @('git', 'push')) | Should Be $true
    }
    It 'no detecta texto vaciado ni otro comando' {
        (Test-SegmentInvokes -Segment 'git commit -m "gh pr create"' -Words $ghCreate) | Should Be $false
        (Test-SegmentInvokes -Segment 'gh-wrapper pr create' -Words $ghCreate) | Should Be $false
        (Test-SegmentInvokes -Segment 'echo "gh pr create"' -Words $ghCreate) | Should Be $false
    }
    It 'devuelve las palabras que matchearon para alternativas' {
        $m = Find-SegmentInvocation -Segment 'gh pr "merge" 12' -Words @('gh', 'pr', 'create|edit|merge')
        $m[2] | Should Be 'merge'
    }
}

Describe 'K. flags largos solo con git/gh' {
    $cases = @(
        'sudo --body "PAYX"',
        'sudo -b "x --body ''PAYX''"',
        'bash -c "x --title ''PAYX''"',
        'xargs -I{} sh -c "--notes ''PAYX''"',
        'sudo --body="PAYX"',
        'watch --message "PAYX"'
    )
    foreach ($c in $cases) {
        It "identidad: $c" {
            (Remove-QuotedContent $c) | Should BeExactly $c
        }
    }
}

Describe 'H. matriz prefijo x wrapper x cola con oraculo declarativo' {
    $cases = @(Get-MatrixCases -Payload 'PAYX')

    It 'hay al menos 1000 combinaciones' {
        $cases.Count | Should BeGreaterThan 999
    }
    It 'vaciado solo si la cola es git/gh y el prefijo es reconocible' {
        $bad = @()
        foreach ($c in $cases) {
            $r = Remove-QuotedContent $c.Command
            $emptied = ($r -notmatch 'PAYX')
            if ($c.ExpectEmptied) {
                if (-not $emptied) { $bad += "DEBIA VACIAR: $($c.Command)" }
            } else {
                if ($r -cne $c.Command) { $bad += "DEBIA QUEDAR IDENTICO: $($c.Command)" }
            }
        }
        ($bad -join "`n") | Should BeNullOrEmpty
    }
}
