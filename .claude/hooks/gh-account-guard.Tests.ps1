# gh-account-guard.Tests.ps1 — Pester 3.4.0
#
# Cubre Issue #323: enforcement duro de cuenta git/gh por repo.
# El incidente real: cambio de cuenta gh de `diegosvart` a `ServiciosTIebi` en medio de sesion,
# sin bloqueo de operaciones de escritura remota (git push, gh pr create, gh repo edit).
#
# Dot-sourcea el hook para invocar Test-GhAccountGuard directamente, mockeando
# Get-ExpectedGhAccount / Get-ActiveGhAccount para no depender de un checkout git real
# ni de archivos reales.

$hookPath = Join-Path $PSScriptRoot 'gh-account-guard.ps1'
. $hookPath

Describe 'Test-GhAccountGuard - cambio de cuenta en medio de sesion (Issue #323, incidente real)' {

    It 'bloquea git push cuando la cuenta activa no coincide con expected_gh_account' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git push origin develop'
        $result.decision | Should Be 'block'
        $result.reason | Should Match 'diegosvart'
        $result.reason | Should Match 'ServiciosTIebi'
    }

    It 'bloquea gh pr create cuando la cuenta activa no coincide con expected_gh_account' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'gh pr create --base develop'
        $result.decision | Should Be 'block'
        $result.reason | Should Match 'account mismatch'
    }

    It 'bloquea gh repo edit cuando la cuenta activa no coincide con expected_gh_account' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'gh repo edit --private'
        $result.decision | Should Be 'block'
    }

    It 'permite git push cuando la cuenta activa coincide con expected_gh_account' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'diegosvart' }
        $result = Test-GhAccountGuard -Command 'git push origin develop'
        $result | Should Be $null
    }

    It 'permite gh pr create cuando la cuenta activa coincide con expected_gh_account' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'diegosvart' }
        $result = Test-GhAccountGuard -Command 'gh pr create --base develop'
        $result | Should Be $null
    }

    It 'permite operacion cuando expected_gh_account no esta declarado (fail-open con advertencia)' {
        Mock Get-ExpectedGhAccount { $null }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git push origin develop'
        $result | Should Be $null
    }

    It 'ignora comandos que no son operaciones de escritura remota' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git status'
        $result | Should Be $null
        $result2 = Test-GhAccountGuard -Command 'gh issue list'
        $result2 | Should Be $null
    }
}

Describe 'gh-account-guard.ps1 - entry point (fail-open)' {

    It 'input no parseable como JSON: exit code 0 (fail-open)' {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'pwsh'
        $psi.Arguments = "-NonInteractive -File `"$hookPath`""
        $psi.RedirectStandardInput = $true
        $psi.UseShellExecute = $false

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Write('esto no es json')
        $proc.StandardInput.Close()
        $proc.WaitForExit()

        # Fail-open: exit code 0 cuando el JSON no se puede parsear
        $proc.ExitCode | Should Be 0
    }
}
