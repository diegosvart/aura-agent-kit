# pr-base-guard.Tests.ps1 — Pester 3.4.0 (unica version disponible en este entorno)
#
# Cubre los 9 casos de la tabla DoD del Issue #230. Dot-sourcea el hook para poder
# invocar Test-PrBaseGuard directamente y mockear Get-OriginRepoSlug/Resolve-PrBaseHead
# sin depender de un checkout git real ni de llamadas reales a `gh`.

$hookPath = Join-Path $PSScriptRoot 'pr-base-guard.ps1'
. $hookPath

Describe 'Test-PrBaseGuard - gh pr create' {

    It 'bloquea cuando falta --base' {
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $result = Test-PrBaseGuard -Command 'gh pr create --title x --body y'
        $result.decision | Should Be 'block'
    }

    It 'permite --base develop' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base develop --title x'
        $result | Should Be $null
    }

    It 'bloquea --base main sin --head develop' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base main --title x'
        $result.decision | Should Be 'block'
    }

    It 'permite --base main con --head develop (release promote)' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base main --head develop --title x'
        $result | Should Be $null
    }

    It 'bloquea --base staging (otro valor cualquiera)' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base staging --title x'
        $result.decision | Should Be 'block'
    }

    It 'no bloquea cuando --repo difiere del origin del checkout' {
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $result = Test-PrBaseGuard -Command 'gh pr create --repo otheruser/otro-repo --base staging --title x'
        $result | Should Be $null
    }
}

Describe 'Test-PrBaseGuard - gh pr edit' {

    It 'no aplica cuando --base no esta presente (edit no toca la base)' {
        $result = Test-PrBaseGuard -Command 'gh pr edit 123 --title "nuevo titulo"'
        $result | Should Be $null
    }

    It 'bloquea --base fuera de develop cuando si se especifica' {
        $result = Test-PrBaseGuard -Command 'gh pr edit 123 --base staging'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-PrBaseGuard - gh pr merge' {

    It 'permite cuando baseRefName resuelto via gh pr view es develop' {
        Mock Resolve-PrBaseHead { [pscustomobject]@{ baseRefName = 'develop'; headRefName = 'fix/algo' } }
        $result = Test-PrBaseGuard -Command 'gh pr merge 123'
        $result | Should Be $null
    }

    It 'bloquea cuando baseRefName resuelto via gh pr view es incorrecto' {
        Mock Resolve-PrBaseHead { [pscustomobject]@{ baseRefName = 'staging'; headRefName = 'fix/algo' } }
        $result = Test-PrBaseGuard -Command 'gh pr merge 123'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-PrBaseGuard - comandos encadenados (code-review PR #233, hallazgo 1)' {

    It 'bloquea el segundo gh pr create de un comando encadenado con &&, aunque el primero sea --base develop' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base develop --title a && gh pr create --base main --title b'
        $result.decision | Should Be 'block'
    }

    It 'bloquea el segundo gh pr create de un comando encadenado con ; ' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base develop --title a ; gh pr create --base staging --title b'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-PrBaseGuard - gh pr merge con flag antes del target (code-review PR #233, hallazgo 2)' {

    It 'resuelve el PR 123 (no la rama actual) cuando hay un flag booleano antes del target' {
        Mock Resolve-PrBaseHead {
            param($Target, $RepoSlug)
            if ($Target -eq '123') { return [pscustomobject]@{ baseRefName = 'staging'; headRefName = 'x' } }
            return [pscustomobject]@{ baseRefName = 'develop'; headRefName = 'x' }
        }
        $result = Test-PrBaseGuard -Command 'gh pr merge --squash 123'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-PrBaseGuard - texto entre comillas que es dato (Issue #361)' {

    It 'no bloquea --body que menciona el comando de crear PR' {
        $result = Test-PrBaseGuard -Command 'gh issue create --title x --body "ejecutar gh pr create sin base"'
        $result | Should Be $null
    }

    It 'no bloquea --comment que menciona el comando de crear PR' {
        $result = Test-PrBaseGuard -Command "gh issue comment 5 --comment 'usar gh pr create --base main'"
        $result | Should Be $null
    }

    It 'no bloquea git commit -m que menciona el comando de crear PR' {
        $result = Test-PrBaseGuard -Command 'git commit -m "docs: explica gh pr create sin base"'
        $result | Should Be $null
    }

    It 'no bloquea echo con el comando de crear PR como texto' {
        $result = Test-PrBaseGuard -Command 'echo "gh pr create --base main"'
        $result | Should Be $null
    }

    It 'bloquea bash -c con el comando real' {
        $result = Test-PrBaseGuard -Command 'bash -c "gh pr create --base main --title x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea sh -c con el comando real' {
        $result = Test-PrBaseGuard -Command "sh -c 'gh pr create --title x'"
        $result.decision | Should Be 'block'
    }

    It 'bloquea pwsh -Command con el comando real' {
        $result = Test-PrBaseGuard -Command 'pwsh -Command "gh pr create --base staging"'
        $result.decision | Should Be 'block'
    }

    It 'sigue bloqueando el comando real con --body que menciona --base develop' {
        $result = Test-PrBaseGuard -Command 'gh pr create --base main --body "usar --base develop"'
        $result.decision | Should Be 'block'
    }

    It 'no toma --base develop del texto de --body como base real' {
        $result = Test-PrBaseGuard -Command 'gh pr create --body "--base develop" --title x'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-PrBaseGuard - comillas con sustitucion ejecutable (review PR #363)' {

    It 'bloquea git commit -m con $(...) que ejecuta el comando real' {
        $result = Test-PrBaseGuard -Command 'git commit -m "$(gh pr create --base main --title x)"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git commit -m con backticks que ejecutan el comando real' {
        $result = Test-PrBaseGuard -Command 'git commit -m "`gh pr create --base main --title x`"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea --body con $(...) que ejecuta el comando real' {
        $result = Test-PrBaseGuard -Command 'gh issue create --title x --body "$(gh pr create --base main)"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea echo con $(...) que ejecuta el comando real' {
        $result = Test-PrBaseGuard -Command 'echo "$(gh pr create --base main)"'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-PrBaseGuard - flags cortos de terceros no vacian payload (review PR #363)' {

    It 'bloquea sudo -b con el comando real' {
        $result = Test-PrBaseGuard -Command 'sudo -b "gh pr create --base main --title x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea watch -t con el comando real' {
        $result = Test-PrBaseGuard -Command 'watch -t "gh pr create --base main --title x"'
        $result.decision | Should Be 'block'
    }

    It 'sigue sin bloquear git commit -am con el comando como texto' {
        $result = Test-PrBaseGuard -Command 'git commit -am "docs: explica gh pr create sin base"'
        $result | Should Be $null
    }

    It 'sigue sin bloquear gh issue create -b con el comando como texto' {
        $result = Test-PrBaseGuard -Command 'gh issue create -t x -b "usar gh pr create --base main"'
        $result | Should Be $null
    }
}

Describe 'Test-PrBaseGuard - echo/printf con flags y varios argumentos (review PR #363)' {

    It 'no bloquea echo -e con el comando de crear PR como texto' {
        $result = Test-PrBaseGuard -Command 'echo -e "gh pr create --base main\n"'
        $result | Should Be $null
    }

    It 'no bloquea printf con formato y argumento posterior' {
        $result = Test-PrBaseGuard -Command 'printf "%s\n" "gh pr create --base main"'
        $result | Should Be $null
    }
}

Describe 'pr-base-guard.ps1 - entry point (fail-open)' {

    It 'input no parseable como JSON: no bloquea y queda logueado' {
        $logPath = Join-Path $PSScriptRoot 'pr-base-guard.log'
        if (Test-Path $logPath) { Remove-Item $logPath -Force }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'pwsh'
        $psi.Arguments = "-NonInteractive -File `"$hookPath`""
        $psi.RedirectStandardInput = $true
        $psi.UseShellExecute = $false

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Write('esto no es json')
        $proc.StandardInput.Close()
        $proc.WaitForExit()

        $proc.ExitCode | Should Be 0
        Test-Path $logPath | Should Be $true
        (Get-Content $logPath -Raw) | Should Match 'FAIL-OPEN'
    }
}
