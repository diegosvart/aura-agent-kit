# git-guard.Tests.ps1 — Pester 3.4.0 (unica version disponible en este entorno)
#
# Cubre el bug de Issue #253: git-guard.ps1 bloqueaba cualquier `git push` mientras la rama
# local activa era develop/main, sin mirar a que repositorio apuntaba el push -- un mirror
# push hacia un repo distinto (ej. aura-agent-kit-sandbox) quedaba bloqueado igual. Dot-sourcea
# el hook para invocar Test-GitGuard directamente y mockear Get-OriginRepoSlug/Get-RemoteUrl/
# Get-CurrentBranch sin depender de un checkout git real.

$hookPath = Join-Path $PSScriptRoot 'git-guard.ps1'
. $hookPath

Describe 'Test-GitGuard - git commit' {

    It 'bloquea commit en develop' {
        Mock Get-CurrentBranch { 'develop' }
        $result = Test-GitGuard -Command 'git commit -m "algo"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea commit en main' {
        Mock Get-CurrentBranch { 'main' }
        $result = Test-GitGuard -Command 'git commit -m "algo"'
        $result.decision | Should Be 'block'
    }

    It 'permite commit en feature branch' {
        Mock Get-CurrentBranch { 'feature/issue-1-x' }
        $result = Test-GitGuard -Command 'git commit -m "algo"'
        $result | Should Be $null
    }
}

Describe 'Test-GitGuard - git push, mismo repo (comportamiento existente, sin regresion)' {

    It 'bloquea push sin argumentos en develop' {
        Mock Get-CurrentBranch { 'develop' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $result = Test-GitGuard -Command 'git push'
        $result.decision | Should Be 'block'
    }

    It 'bloquea "git push origin develop" en develop' {
        Mock Get-CurrentBranch { 'develop' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        Mock Get-RemoteUrl { 'https://github.com/diegosvart/aura-agent-kit.git' }
        $result = Test-GitGuard -Command 'git push origin develop'
        $result.decision | Should Be 'block'
    }

    It 'permite push en feature branch' {
        Mock Get-CurrentBranch { 'feature/issue-1-x' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $result = Test-GitGuard -Command 'git push'
        $result | Should Be $null
    }
}

Describe 'Test-GitGuard - git push cross-repo (Issue #253, bug real)' {

    It 'NO bloquea mirror push a URL de un repo distinto, aunque la rama local sea develop' {
        Mock Get-CurrentBranch { 'develop' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        $result = Test-GitGuard -Command 'git push --mirror https://github.com/diegosvart/aura-agent-kit-sandbox.git'
        $result | Should Be $null
    }

    It 'NO bloquea push a un remote nombrado que resuelve a un repo distinto' {
        Mock Get-CurrentBranch { 'develop' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        Mock Get-RemoteUrl {
            param($Name)
            if ($Name -eq 'sandbox') { return 'https://github.com/diegosvart/aura-agent-kit-sandbox.git' }
            return 'https://github.com/diegosvart/aura-agent-kit.git'
        }
        $result = Test-GitGuard -Command 'git push sandbox develop'
        $result | Should Be $null
    }

    It 'SI bloquea cuando el remote nombrado resuelve al mismo repo que origin' {
        Mock Get-CurrentBranch { 'develop' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        Mock Get-RemoteUrl { 'https://github.com/diegosvart/aura-agent-kit.git' }
        $result = Test-GitGuard -Command 'git push origin develop'
        $result.decision | Should Be 'block'
    }

    It 'SI bloquea (fail-safe) cuando el destino no se puede resolver' {
        Mock Get-CurrentBranch { 'develop' }
        Mock Get-OriginRepoSlug { 'diegosvart/aura-agent-kit' }
        Mock Get-RemoteUrl { $null }
        $result = Test-GitGuard -Command 'git push remoto-inexistente develop'
        $result.decision | Should Be 'block'
    }
}

Describe 'git-guard.ps1 - entry point (fail-open)' {

    It 'input no parseable como JSON: no bloquea y queda logueado' {
        $logPath = Join-Path $PSScriptRoot 'git-guard.log'
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
