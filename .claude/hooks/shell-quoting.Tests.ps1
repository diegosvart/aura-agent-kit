# shell-quoting.Tests.ps1 — Pester 3.4.0
#
# Suite propia de la libreria compartida por gh-account-guard.ps1 y pr-base-guard.ps1 (Issue #368).

. (Join-Path $PSScriptRoot 'shell-quoting.ps1')

Describe 'Split-ShellSegments' {

    It 'devuelve un solo segmento sin separadores' {
        $s = @(Split-ShellSegments -Command 'git status')
        $s.Count | Should Be 1
        $s[0] | Should Be 'git status'
    }

    It 'divide por &&' {
        $s = @(Split-ShellSegments -Command 'a && b')
        $s.Count | Should Be 2
        $s[1].Trim() | Should Be 'b'
    }

    It 'divide por ||' {
        $s = @(Split-ShellSegments -Command 'a || b')
        $s.Count | Should Be 2
    }

    It 'divide por ;' {
        $s = @(Split-ShellSegments -Command 'a; b')
        $s.Count | Should Be 2
    }

    It 'divide por |' {
        $s = @(Split-ShellSegments -Command 'a | b')
        $s.Count | Should Be 2
    }

    It 'divide por & simple' {
        $s = @(Split-ShellSegments -Command 'a & b')
        $s.Count | Should Be 2
    }

    It 'divide por salto de linea' {
        $s = @(Split-ShellSegments -Command "a`nb")
        $s.Count | Should Be 2
    }

    It 'no divide separadores dentro de comillas dobles' {
        $s = @(Split-ShellSegments -Command 'echo "a && b; c | d"')
        $s.Count | Should Be 1
    }

    It 'no divide separadores dentro de comillas simples' {
        $s = @(Split-ShellSegments -Command "echo 'a && b; c | d'")
        $s.Count | Should Be 1
    }
}

Describe 'Remove-QuotedContent - flags de texto libre' {

    It 'vacia --body con comillas dobles' {
        Remove-QuotedContent 'gh pr create --body "gh pr create --base main"' | Should Be 'gh pr create --body ""'
    }

    It 'vacia --title=valor con comillas simples' {
        Remove-QuotedContent "gh issue create --title='x y'" | Should Be 'gh issue create --title=""'
    }

    It 'vacia -m en git' {
        Remove-QuotedContent 'git commit -m "gh pr create --base main"' | Should Be 'git commit -m ""'
    }

    It 'vacia -am en git' {
        Remove-QuotedContent 'git commit -am "texto"' | Should Be 'git commit -am ""'
    }

    It 'vacia -b y -t en gh' {
        Remove-QuotedContent 'gh pr create -b "x" -t "y"' | Should Be 'gh pr create -b "" -t ""'
    }

    It 'NO vacia -m si el segmento no es git/gh' {
        Remove-QuotedContent 'bash -m "payload"' | Should Be 'bash -m "payload"'
    }

    It 'NO vacia -b con sudo sobre un comando no git/gh' {
        Remove-QuotedContent 'sudo -b "payload"' | Should Be 'sudo -b "payload"'
    }

    It 'conserva comillas con $() aunque sea flag de texto' {
        $c = 'git commit -m "$(gh pr create --base main)"'
        Remove-QuotedContent $c | Should Be $c
    }

    It 'conserva comillas con backticks' {
        $c = 'git commit -m "`gh pr create`"'
        Remove-QuotedContent $c | Should Be $c
    }
}

Describe 'Remove-QuotedContent - echo/printf' {

    It 'vacia todos los literales tras echo' {
        Remove-QuotedContent 'echo -e "a" "b"' | Should Be 'echo -e "" ""'
    }

    It 'vacia argumentos de printf' {
        Remove-QuotedContent 'printf "%s" "gh pr create"' | Should Be 'printf "" ""'
    }

    It 'conserva $() dentro de echo' {
        $c = 'echo "$(gh pr create)"'
        Remove-QuotedContent $c | Should Be $c
    }
}

Describe 'Remove-QuotedContent - prefijos de entorno (Issue #368)' {

    It 'reconoce FOO=a git (sin espacios)' {
        Remove-QuotedContent 'FOO=a git commit -m "x"' | Should Be 'FOO=a git commit -m ""'
    }

    It 'reconoce FOO="a b" git (comillas dobles con espacios)' {
        Remove-QuotedContent 'FOO="a b" git commit -m "x"' | Should Be 'FOO="a b" git commit -m ""'
    }

    It "reconoce FOO='a b' gh (comillas simples con espacios)" {
        Remove-QuotedContent "FOO='a b' gh pr create -t 'x'" | Should Be 'FOO=''a b'' gh pr create -t ""'
    }

    It 'reconoce prefijos encadenados con espacios y sudo' {
        Remove-QuotedContent 'A="x y" B=z sudo git commit -m "x"' | Should Be 'A="x y" B=z sudo git commit -m ""'
    }

    It 'NO vacia la carga de bash -c con prefijo entrecomillado' {
        $c = 'FOO="a b" bash -c "gh pr create --base main"'
        Remove-QuotedContent $c | Should Be $c
    }

    It 'NO vacia sudo -b con prefijo entrecomillado' {
        $c = 'FOO="a b" sudo -b "gh pr create --base main"'
        Remove-QuotedContent $c | Should Be $c
    }

    It 'NO vacia sudo -b cuando el valor del prefijo contiene "sudo git"' {
        $c = 'FOO="sudo git" sudo -b "gh pr create --base main"'
        Remove-QuotedContent $c | Should Be $c
    }

    It 'NO vacia sudo -t cuando el valor del prefijo termina en git' {
        $c = "FOO='a git' sudo -t ""gh pr create --base main"""
        Remove-QuotedContent $c | Should Be $c
    }

    It 'NO vacia sudo -b cuando el valor mezcla texto y comilla (FOO=x"a git")' {
        $c = 'FOO=x"a git" sudo -b "gh pr create --base main"'
        Remove-QuotedContent $c | Should Be $c
    }

    It "NO vacia sudo -b con valor mixto de comilla simple (FOO=x'a git')" {
        $c = "FOO=x'a git' sudo -b ""gh pr create --base main"""
        Remove-QuotedContent $c | Should Be $c
    }

    It 'NO vacia sudo -t con prefijos encadenados y valor mixto' {
        $c = 'A=1 FOO=x"a gh" env sudo -t "gh pr create --base main"'
        Remove-QuotedContent $c | Should Be $c
    }

    It 'reconoce git con valor mixto legitimo (VAR=x"y z" git commit -m)' {
        Remove-QuotedContent 'VAR=x"y z" git commit -m "texto"' | Should Be 'VAR=x"y z" git commit -m ""'
    }
}
