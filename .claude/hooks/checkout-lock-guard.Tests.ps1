# checkout-lock-guard.Tests.ps1 — Pester 3.4.0 (unica version disponible en este entorno)
#
# Cubre Test-CheckoutLockGuard (Issue #217): enforcement duro del lock de checkout de
# agentic-dev-loop. Dot-sourcea el hook y mockea Get-LockOwnerLine para no depender de un
# .git/aura-checkout.lock real.

$hookPath = Join-Path $PSScriptRoot 'checkout-lock-guard.ps1'
. $hookPath

Describe 'Test-CheckoutLockGuard - sin lock activo (no-op)' {

    It 'no bloquea git checkout cuando no hay lock' {
        Mock Get-LockOwnerLine { $null }
        $result = Test-CheckoutLockGuard -Command 'git checkout -b feature/x' -SessionId 'session-a'
        $result | Should Be $null
    }

    It 'no bloquea git commit cuando no hay lock' {
        Mock Get-LockOwnerLine { $null }
        $result = Test-CheckoutLockGuard -Command 'git commit -m "x"' -SessionId 'session-a'
        $result | Should Be $null
    }
}

Describe 'Test-CheckoutLockGuard - comandos no relacionados con git (fuera de alcance)' {

    It 'no bloquea un comando que no es checkout/switch/commit/push, aunque haya lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-session-a' }
        $result = Test-CheckoutLockGuard -Command 'git status --short' -SessionId 'session-b'
        $result | Should Be $null
    }
}

Describe 'Test-CheckoutLockGuard - lock activo, misma sesion (dueño)' {

    It 'permite git checkout cuando el session_id coincide con el dueño del lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git checkout -b feature/x' -SessionId 'abc123'
        $result | Should Be $null
    }

    It 'permite git push cuando el session_id coincide con el dueño del lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git push origin feature/x' -SessionId 'abc123'
        $result | Should Be $null
    }
}

Describe 'Test-CheckoutLockGuard - lock activo, otra sesion (Issue #217, caso real)' {

    It 'bloquea git checkout de una sesion distinta a la dueña del lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git checkout develop' -SessionId 'xyz789'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git switch de una sesion distinta a la dueña del lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git switch develop' -SessionId 'xyz789'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git commit de una sesion distinta a la dueña del lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git commit -m "x"' -SessionId 'xyz789'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push de una sesion distinta a la dueña del lock' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git push origin develop' -SessionId 'xyz789'
        $result.decision | Should Be 'block'
    }

    It 'bloquea (fail-safe) cuando no se puede determinar el session_id actual' {
        Mock Get-LockOwnerLine { '2026-09-08T00:00:00-03:00 issue-217 agent-a session-abc123' }
        $result = Test-CheckoutLockGuard -Command 'git checkout develop' -SessionId ''
        $result.decision | Should Be 'block'
    }
}

Describe 'checkout-lock-guard.ps1 - entry point (fail-open)' {

    It 'input no parseable como JSON: no bloquea y queda logueado' {
        $logPath = Join-Path $PSScriptRoot 'checkout-lock-guard.log'
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
