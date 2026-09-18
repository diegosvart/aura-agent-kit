# session-end-gather.Tests.ps1 — Pester 3.4.0 (unica version disponible en este entorno)
#
# Cubre session-end-gather.ps1 (Issue #259): script determinístico que reemplaza ~7 tool-calls
# dispersas de protocols/session_end.md (linter, tests, chequeo de rama, 4 llamadas gh) por una
# sola invocación. Dot-sourcea el hook para invocar las funciones internas directamente y
# mockear git/gh sin depender de un checkout real ni de red.

$hookPath = Join-Path $PSScriptRoot 'session-end-gather.ps1'
. $hookPath

Describe 'Get-StackInfo - lee session-stack.json si existe (no redetecta)' {

    $tempDir = Join-Path $env:TEMP "session-end-gather-tests-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    It 'usa profile_name/linter/test_runner del archivo (esquema stack-selection)' {
        $stackFile = Join-Path $tempDir 'session-stack-full.json'
        @{
            profile_name = 'fastapi'
            linter       = 'ruff check .'
            test_runner  = 'pytest -q'
        } | ConvertTo-Json | Set-Content -Path $stackFile -Encoding utf8

        $result = Get-StackInfo -StackFilePath $stackFile -ProjectRoot $tempDir
        $result.source | Should Be 'session-stack.json'
        $result.profile | Should Be 'fastapi'
        $result.lint | Should Be 'ruff check .'
        $result.test | Should Be 'pytest -q'
    }

    It 'usa stack/lint/test del archivo (esquema simplificado real de este repo)' {
        $stackFile = Join-Path $tempDir 'session-stack-simple.json'
        @{
            stack = 'bash-scripts + markdown'
            lint  = 'shellcheck **/*.sh'
            test  = ''
        } | ConvertTo-Json | Set-Content -Path $stackFile -Encoding utf8

        $result = Get-StackInfo -StackFilePath $stackFile -ProjectRoot $tempDir
        $result.source | Should Be 'session-stack.json'
        $result.profile | Should Be 'bash-scripts + markdown'
        $result.lint | Should Be 'shellcheck **/*.sh'
        $result.test | Should Be $null
    }

    It 'NO redetecta desde manifiestos si el archivo ya existe' {
        $subDir = Join-Path $tempDir 'no-redetect'
        New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        Set-Content -Path (Join-Path $subDir 'package.json') -Value '{}'
        $stackFile = Join-Path $subDir 'session-stack.json'
        @{ stack = 'ya-confirmado'; lint = 'algo'; test = 'algo-test' } | ConvertTo-Json |
            Set-Content -Path $stackFile -Encoding utf8

        $result = Get-StackInfo -StackFilePath $stackFile -ProjectRoot $subDir
        $result.profile | Should Be 'ya-confirmado'
        $result.source | Should Be 'session-stack.json'
    }

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-StackInfo - sin session-stack.json (detección o none)' {

    It 'detecta Python si hay pyproject.toml y no hay archivo de stack' {
        $tempDir = Join-Path $env:TEMP "session-end-gather-tests-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path (Join-Path $tempDir 'pyproject.toml') -Value '[project]'

        $result = Get-StackInfo -StackFilePath (Join-Path $tempDir 'session-stack.json') -ProjectRoot $tempDir
        $result.source | Should Be 'detected'
        $result.profile | Should Be 'Python'
        $result.lint | Should Not BeNullOrEmpty
        $result.test | Should Not BeNullOrEmpty

        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'devuelve stack "none" sin manifiestos ni archivo de stack' {
        $tempDir = Join-Path $env:TEMP "session-end-gather-tests-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        $result = Get-StackInfo -StackFilePath (Join-Path $tempDir 'session-stack.json') -ProjectRoot $tempDir
        $result.source | Should Be 'none'
        $result.profile | Should Be 'none'
        $result.lint | Should Be $null
        $result.test | Should Be $null

        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-CheckCommand - ejecución de linter/test' {

    It 'ran=false y sin exit_code cuando el comando es nulo/vacío' {
        $result = Invoke-CheckCommand -Command $null -ProjectRoot (Get-Location).Path
        $result.ran | Should Be $false
        $result.exit_code | Should Be $null
        $result.output_tail | Should Be $null
    }

    It 'ran=false cuando el comando es cadena vacía' {
        $result = Invoke-CheckCommand -Command '' -ProjectRoot (Get-Location).Path
        $result.ran | Should Be $false
    }

    It 'ejecuta el comando y captura exit_code real (éxito)' {
        $result = Invoke-CheckCommand -Command 'exit 0' -ProjectRoot (Get-Location).Path
        $result.ran | Should Be $true
        $result.exit_code | Should Be 0
    }

    It 'ejecuta el comando y captura exit_code real (falla)' {
        $result = Invoke-CheckCommand -Command 'exit 7' -ProjectRoot (Get-Location).Path
        $result.ran | Should Be $true
        $result.exit_code | Should Be 7
    }

    It 'captura output_tail con la salida del comando' {
        $result = Invoke-CheckCommand -Command 'echo hola-mundo' -ProjectRoot (Get-Location).Path
        $result.output_tail | Should Match 'hola-mundo'
    }

    It 'trunca output_tail a las ultimas ~20 lineas' {
        $lines = 1..30 | ForEach-Object { "echo line$_" }
        # ';' es el separador secuencial en bash (el comando corre vía Git Bash desde
        # Issue #259/reviewer fix) -- '&' en bash es backgrounding, no encadenado como en cmd.
        $chained = $lines -join '; '
        $result = Invoke-CheckCommand -Command $chained -ProjectRoot (Get-Location).Path
        $tailLines = $result.output_tail -split "`n"
        $tailLines.Count | Should BeLessThan 21
        $result.output_tail | Should Match 'line30'
        $result.output_tail | Should Not Match 'line1`n'
    }

    It 'ejecuta sintaxis bash real (command -v / >/dev/null / &&-||) sin fallback fantasma' {
        # Reproduce el [CRÍTICO] reportado por el reviewer: bajo cmd.exe, `command -v` y
        # `>/dev/null` no existen -- el && de la izquierda falla por sintaxis ajena a si la
        # herramienta existe, y el || de la derecha ejecuta el echo de fallback, dando
        # exit_code=0 sin haber evaluado nada real. Este comando usa una herramienta que NO
        # existe (definitivamente-no-existe-esta-herramienta) para forzar la rama del `||`,
        # y otra síntesis que SÍ existe (echo, disponible en cualquier bash) para forzar la
        # rama del `&&` -- ambas deben resolverse por la lógica real del comando, no por un
        # error de shell no reconocido.
        $missingToolCommand = "command -v definitivamente-no-existe-esta-herramienta >/dev/null 2>&1 && echo 'deberia-no-mostrarse' || echo 'no-disponible-en-este-path'"
        $result = Invoke-CheckCommand -Command $missingToolCommand -ProjectRoot (Get-Location).Path
        $result.exit_code | Should Be 0
        $result.output_tail | Should Match 'no-disponible-en-este-path'
        $result.output_tail | Should Not Match 'deberia-no-mostrarse'

        $presentToolCommand = "command -v echo >/dev/null 2>&1 && echo 'herramienta-encontrada' || echo 'no-disponible-en-este-path'"
        $result2 = Invoke-CheckCommand -Command $presentToolCommand -ProjectRoot (Get-Location).Path
        $result2.exit_code | Should Be 0
        $result2.output_tail | Should Match 'herramienta-encontrada'
        $result2.output_tail | Should Not Match 'no-disponible-en-este-path'
    }
}

Describe 'Get-PrForCurrentBranch - filtro puro sobre open_prs' {

    It 'devuelve null si ninguna PR abierta matchea la rama actual' {
        $openPrs = @(
            @{ number = 1; title = 'a'; headRefName = 'feature/otra-rama' }
        )
        $result = Get-PrForCurrentBranch -OpenPrs $openPrs -Branch 'feature/mi-rama'
        $result | Should Be $null
    }

    It 'devuelve el objeto correcto si matchea la rama actual' {
        $openPrs = @(
            @{ number = 1; title = 'a'; headRefName = 'feature/otra-rama' },
            @{ number = 2; title = 'b'; headRefName = 'feature/mi-rama' }
        )
        $result = Get-PrForCurrentBranch -OpenPrs $openPrs -Branch 'feature/mi-rama'
        $result.number | Should Be 2
    }

    It 'devuelve null con open_prs vacío' {
        $result = Get-PrForCurrentBranch -OpenPrs @() -Branch 'feature/mi-rama'
        $result | Should Be $null
    }
}

Describe 'Get-SessionEndGatherResult - orquestación completa' {

    It 'emite todos los campos esperados en el resultado' {
        Mock Get-StackInfo { @{ profile = 'none'; lint = $null; test = $null; source = 'none' } }
        Mock Get-CurrentBranchName { 'feature/issue-259-x' }
        Mock Get-GhAuthenticated { $false }
        Mock Get-CommitsAheadOfDevelop { 2 }

        $result = Get-SessionEndGatherResult -ProjectRoot (Get-Location).Path -StackFilePath 'irrelevante.json'

        $expectedKeys = @(
            'stack','lint_result','test_result','branch','branch_protected','gh_authenticated',
            'recently_merged_prs','recently_closed_issues','open_prs','ready_issues',
            'commits_ahead_of_develop','pr_for_current_branch'
        )
        foreach ($key in $expectedKeys) {
            $result.ContainsKey($key) | Should Be $true
        }
    }

    It 'stack "none" => lint_result.ran y test_result.ran son false' {
        Mock Get-StackInfo { @{ profile = 'none'; lint = $null; test = $null; source = 'none' } }
        Mock Get-CurrentBranchName { 'feature/issue-259-x' }
        Mock Get-GhAuthenticated { $false }
        Mock Get-CommitsAheadOfDevelop { 0 }

        $result = Get-SessionEndGatherResult -ProjectRoot (Get-Location).Path -StackFilePath 'irrelevante.json'

        $result.lint_result.ran | Should Be $false
        $result.test_result.ran | Should Be $false
    }

    It 'gh_authenticated=false => los 4 arrays de GitHub vienen vacíos y no se consultan' {
        Mock Get-StackInfo { @{ profile = 'none'; lint = $null; test = $null; source = 'none' } }
        Mock Get-CurrentBranchName { 'feature/issue-259-x' }
        Mock Get-GhAuthenticated { $false }
        Mock Get-RecentlyMergedPrs { @(@{ number = 999 }) } -Verifiable
        Mock Get-RecentlyClosedIssues { @(@{ number = 999 }) } -Verifiable
        Mock Get-OpenPrs { @(@{ number = 999 }) } -Verifiable
        Mock Get-ReadyIssues { @(@{ number = 999 }) } -Verifiable
        Mock Get-CommitsAheadOfDevelop { 0 }

        $result = Get-SessionEndGatherResult -ProjectRoot (Get-Location).Path -StackFilePath 'irrelevante.json'

        $result.gh_authenticated | Should Be $false
        @($result.recently_merged_prs).Count | Should Be 0
        @($result.recently_closed_issues).Count | Should Be 0
        @($result.open_prs).Count | Should Be 0
        @($result.ready_issues).Count | Should Be 0
        Assert-MockCalled Get-RecentlyMergedPrs -Times 0
        Assert-MockCalled Get-RecentlyClosedIssues -Times 0
        Assert-MockCalled Get-OpenPrs -Times 0
        Assert-MockCalled Get-ReadyIssues -Times 0
    }

    It 'gh_authenticated=true => trae los 4 arrays y deriva pr_for_current_branch' {
        Mock Get-StackInfo { @{ profile = 'none'; lint = $null; test = $null; source = 'none' } }
        Mock Get-CurrentBranchName { 'feature/issue-259-x' }
        Mock Get-GhAuthenticated { $true }
        Mock Get-RecentlyMergedPrs { @(@{ number = 264; title = 'x'; mergedAt = '2026-09-13'; headRefName = 'docs/262' }) }
        Mock Get-RecentlyClosedIssues { @(@{ number = 262; title = 'y'; closedAt = '2026-09-13' }) }
        Mock Get-OpenPrs { @(@{ number = 265; title = 'z'; headRefName = 'feature/issue-259-x' }) }
        Mock Get-ReadyIssues { @(@{ number = 231; title = 'w' }) }
        Mock Get-CommitsAheadOfDevelop { 3 }

        $result = Get-SessionEndGatherResult -ProjectRoot (Get-Location).Path -StackFilePath 'irrelevante.json'

        @($result.recently_merged_prs).Count | Should Be 1
        @($result.open_prs).Count | Should Be 1
        $result.pr_for_current_branch.number | Should Be 265
        $result.commits_ahead_of_develop | Should Be 3
    }

    It 'branch_protected=true en develop/main' {
        Mock Get-StackInfo { @{ profile = 'none'; lint = $null; test = $null; source = 'none' } }
        Mock Get-CurrentBranchName { 'develop' }
        Mock Get-GhAuthenticated { $false }
        Mock Get-CommitsAheadOfDevelop { 0 }

        $result = Get-SessionEndGatherResult -ProjectRoot (Get-Location).Path -StackFilePath 'irrelevante.json'
        $result.branch_protected | Should Be $true
    }
}

Describe 'session-end-gather.ps1 - entry point emite JSON válido' {

    It 'al ejecutarse directamente imprime un JSON parseable con los campos esperados' {
        $raw = & pwsh -NonInteractive -File $hookPath 2>$null
        $json = ($raw -join "`n") | ConvertFrom-Json
        $names = @($json.PSObject.Properties.Name)
        $expectedFields = @(
            'stack','lint_result','test_result','branch','branch_protected','gh_authenticated',
            'recently_merged_prs','recently_closed_issues','open_prs','ready_issues',
            'commits_ahead_of_develop','pr_for_current_branch'
        )
        foreach ($field in $expectedFields) {
            ($names -contains $field) | Should Be $true
        }
    }
}
