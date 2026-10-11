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

Describe 'Test-GhAccountGuard - segmentacion y texto entre comillas (Issue #346)' {

    It 'no bloquea cuando "git push" aparece solo como texto dentro de --body' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'gh issue create --title x --body "ejemplo: git push origin x"'
        $result | Should Be $null
    }

    It 'no bloquea cuando "gh pr create" aparece solo como texto entre comillas simples' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command "echo 'gh pr create' && ls"
        $result | Should Be $null
    }

    It 'sigue bloqueando un git push real encadenado tras otro comando' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'echo ok && git push origin x'
        $result.decision | Should Be 'block'
    }

    It 'sigue bloqueando un git push real aunque otro segmento tenga texto entre comillas' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'echo "hola" ; git push origin x'
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-GhAccountGuard - comandos entre comillas que si se ejecutan (Issue #346, hallazgo de review)' {

    It 'bloquea git push dentro de bash -c "..."' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'bash -c "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea gh pr create dentro de pwsh -Command "..."' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'pwsh -Command "gh pr create --fill"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de sh -c con comillas simples' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command "sh -c 'git push origin x'"
        $result.decision | Should Be 'block'
    }

    It 'no bloquea git commit -m con prefijo FOO="a b" y "git push" como texto (Issue #368)' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'FOO="a b" git commit -m "fix: no git push aqui"'
        $result | Should Be $null
    }

    It 'no bloquea git commit -am con "git push" como texto del mensaje' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git commit -am "fix: no git push aqui"'
        $result | Should Be $null
    }

    It 'no bloquea gh issue close --comment con "git push" como texto' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'gh issue close 5 --comment "ya hice git push"'
        $result | Should Be $null
    }

    It 'no bloquea git commit -m con "git push" como texto del mensaje' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git commit -m "docs: explica git push"'
        $result | Should Be $null
    }

    It 'bloquea git push dentro de pwsh -Comm "..." (abreviatura de -Command)' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'pwsh -Comm "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de pwsh -com "..." (abreviatura en minuscula)' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'pwsh -com "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de sudo -b "..." (flag corto no free-text)' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'sudo -b "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de $(...) en el mensaje de git commit -m' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git commit -m "$(git push origin x)"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de backticks en el mensaje de git commit -m' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git commit -m "`git push origin x`"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de bash -xt "..." (flag corto fuera de -m/-b/-t)' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'bash -xt "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea git push dentro de sudo -m "..." (-m de un comando que no es git/gh)' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'sudo -m "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'sigue sin bloquear git commit -am con git push como texto plano' {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
        $result = Test-GhAccountGuard -Command 'git commit -am "docs: git push"'
        $result | Should Be $null
    }
}

Describe 'Test-GhAccountGuard - prefijos y segmentos con comillas (review PR #366)' {

    BeforeEach {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
    }

    It 'no bloquea VAR=x git commit -m con git push como texto' {
        $result = Test-GhAccountGuard -Command 'GIT_AUTHOR_NAME=x git commit -m "docs: git push"'
        $result | Should Be $null
    }

    It 'no bloquea sudo git commit -m con git push como texto' {
        $result = Test-GhAccountGuard -Command 'sudo git commit -m "docs: git push"'
        $result | Should Be $null
    }

    It 'no bloquea env git commit -m con git push como texto' {
        $result = Test-GhAccountGuard -Command 'env git commit -m "docs: git push"'
        $result | Should Be $null
    }

    It 'no bloquea git commit -m con ; dentro de las comillas y git push como texto' {
        $result = Test-GhAccountGuard -Command 'git commit -m "a; b" -m "git push"'
        $result | Should Be $null
    }

    It 'bloquea un git push real tras un git commit con ; dentro de las comillas' {
        $result = Test-GhAccountGuard -Command 'git commit -m "a; b" && git push origin x'
        $result.decision | Should Be 'block'
    }

    It 'no bloquea git commit -m con git push como texto en un segundo segmento tras otro comando' {
        $result = Test-GhAccountGuard -Command 'ls && git commit -m "docs: git push"'
        $result | Should Be $null
    }

    It 'bloquea sudo -b con git push real aunque un segmento previo sea git' {
        $result = Test-GhAccountGuard -Command 'git status && sudo -b "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea sudo con ; dentro de comillas seguido de -b con git push real' {
        $result = Test-GhAccountGuard -Command "sudo 'a; git x' -b ""git push origin x"""
        $result.decision | Should Be 'block'
    }
}

Describe 'Test-GhAccountGuard - separadores & y salto de linea (review 2 PR #366)' {

    BeforeEach {
        Mock Get-ExpectedGhAccount { 'diegosvart' }
        Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
    }

    It 'bloquea sudo -b con git push real tras git status & (background)' {
        $result = Test-GhAccountGuard -Command 'git status & sudo -b "git push origin x"'
        $result.decision | Should Be 'block'
    }

    It 'bloquea sudo -b con git push real tras git status y salto de linea' {
        $result = Test-GhAccountGuard -Command ("git status`n" + 'sudo -b "git push origin x"')
        $result.decision | Should Be 'block'
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

Describe 'gh-account-guard.ps1 - entry point (block, Issue #327 bugfix)' {

    It 'bloquea git push con protocolo JSON stdout + exit code 2 cuando la cuenta no coincide' {
        $projectRoot = (git rev-parse --show-toplevel 2>$null).Trim()
        $classificationPath = Join-Path $projectRoot '.agent/memory/repo-classification.json'
        $backupPath = "$classificationPath.bak-test"

        $activeAccount = $null
        $ghStatus = (& gh auth status --active 2>&1) -join "`n"
        if ($ghStatus -match 'account\s+([a-zA-Z0-9\-._]+)') { $activeAccount = $Matches[1] }
        if (-not $activeAccount) {
            Set-TestInconclusive -Message 'No se pudo determinar la cuenta gh activa en este entorno'
            return
        }
        $mismatchedAccount = "$activeAccount-mismatch-test"

        $hadOriginal = Test-Path $classificationPath
        if ($hadOriginal) { Copy-Item $classificationPath $backupPath -Force }

        try {
            @{ repo_type = 'harness'; expected_gh_account = $mismatchedAccount } |
                ConvertTo-Json | Set-Content -Path $classificationPath -Encoding UTF8

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'pwsh'
            $psi.Arguments = "-NonInteractive -File `"$hookPath`""
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.WorkingDirectory = $projectRoot

            $proc = [System.Diagnostics.Process]::Start($psi)
            $proc.StandardInput.Write('{"tool_name":"Bash","tool_input":{"command":"git push origin develop"}}')
            $proc.StandardInput.Close()
            $stdout = $proc.StandardOutput.ReadToEnd()
            $proc.WaitForExit()

            $proc.ExitCode | Should Be 2

            $parsed = $stdout | ConvertFrom-Json
            $parsed.decision | Should Be 'block'
            $parsed.reason | Should Match ([regex]::Escape($mismatchedAccount))
            $parsed.reason | Should Match ([regex]::Escape($activeAccount))
        } finally {
            if ($hadOriginal) {
                Copy-Item $backupPath $classificationPath -Force
                Remove-Item $backupPath -Force
            } else {
                Remove-Item $classificationPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

. (Join-Path $PSScriptRoot 'shell-quoting.TestData.ps1')

Describe 'Test-GhAccountGuard - palabra-comando con comillas o escapes (Issue #370, grupo J)' {

    $cases = @(
        'git "push" origin main'
        'git pu\sh origin main'
        "g'i't push origin main"
        'gh pr "create" --base develop'
        'gh "pr" create --base develop'
        "gh pr cr'eate' --base develop"
        'g"h" pr create --base develop'
        '"gh" repo edit --private'
        'FOO=1 sudo git "push" origin main'
        'gh repo "edit" --private'
    )
    foreach ($c in $cases) {
        It "bloquea con cuenta distinta: $c" {
            Mock Get-ExpectedGhAccount { 'diegosvart' }
            Mock Get-ActiveGhAccount { 'ServiciosTIebi' }
            (Test-GhAccountGuard -Command $c).decision | Should Be 'block'
        }
    }
}

Describe 'Test-GhAccountGuard - matriz prefijo x wrapper x cola (Issue #370, grupo I)' {

    It 'vacia solo cuando la cola es git/gh y el prefijo es reconocible; en el resto bloquea' {
        function Get-ProjectRoot { 'C:proyecto' }
        function Get-ExpectedGhAccount { 'diegosvart' }
        function Get-ActiveGhAccount { 'ServiciosTIebi' }
        $violations = New-Object System.Collections.Generic.List[string]
        foreach ($case in (Get-MatrixCases -Payload 'git push origin main')) {
            $r = Test-GhAccountGuard -Command $case.Command
            $blocked = [bool]$r
            if ($blocked -eq $case.ExpectEmptied) { $violations.Add($case.Command) }
        }
        ($violations | Select-Object -First 10) -join "`n" | Should Be ''
    }
}

Describe 'Get-ExpectedGhAccount - lectura real de repo-classification.json (caracterizacion, Issue #347)' {

    function New-ClassRepo {
        param([string]$Json)
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("ghacct-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $root '.agent/memory') -Force | Out-Null
        if ($null -ne $Json) { Set-Content -Path (Join-Path $root '.agent/memory/repo-classification.json') -Value $Json }
        return $root
    }

    It 'devuelve expected_gh_account cuando esta declarado' {
        $root = New-ClassRepo '{"repo_type":"personal","expected_gh_account":"diegosvart"}'
        try { Get-ExpectedGhAccount -ProjectRoot $root | Should Be 'diegosvart' }
        finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'devuelve $null (fail-open) si falta el campo, el archivo, o el JSON esta corrupto' {
        foreach ($json in @('{"repo_type":"personal"}', $null, '{ roto')) {
            $root = New-ClassRepo $json
            try { Get-ExpectedGhAccount -ProjectRoot $root | Should BeNullOrEmpty }
            finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
