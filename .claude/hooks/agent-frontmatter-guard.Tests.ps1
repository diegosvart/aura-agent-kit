# agent-frontmatter-guard.Tests.ps1 — Pester 3.4.0 (unica version disponible en este entorno)
#
# Regresion de Issue #295: el hook corre en cada Edit/Write del repo (matcher Edit|Write) y
# no tenia tests. Dot-sourcea el hook para invocar Test-AgentFrontmatterGuard directamente;
# usa el check-agent-frontmatter.sh real y un git-bash real, mockeando solo Write-GuardLog
# para no ensuciar agent-frontmatter-guard.log.

$hookPath = Join-Path $PSScriptRoot 'agent-frontmatter-guard.ps1'
. $hookPath

$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:gitBash = Get-GitBashPath
$script:bogusBash = Join-Path $env:TEMP 'no-existe-bash.exe'

$script:validAgent = @"
---
name: demo
description: Demo agent. Use proactively when testing.
tools: Read, Grep
---
cuerpo
"@

function New-TempAgentFile {
    param([string]$Content)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("fm-guard-" + [guid]::NewGuid().ToString('N'))
    $agentsDir = Join-Path $dir 'agents'
    New-Item -ItemType Directory -Path $agentsDir | Out-Null
    $path = Join-Path $agentsDir 'demo.md'
    Set-Content -Path $path -Value $Content -NoNewline -Encoding utf8
    return $path
}

Describe 'Test-AgentFrontmatterGuard - Write' {

    It 'bloquea Write sin frontmatter' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md'; content = "# solo titulo`n" }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result.decision | Should Be 'block'
    }

    It 'permite Write con frontmatter valido' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md'; content = $script:validAgent }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result | Should Be $null
    }

    It 'el motivo del bloqueo cita la ruta original, no el temporal' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md'; content = "sin frontmatter`n" }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result.reason | Should Match 'nuevo\.md'
        $result.reason | Should Match 'NO-FRONTMATTER'
    }
}

Describe 'Test-AgentFrontmatterGuard - rutas fuera de agents/*.md' {

    It 'permite Write fuera de agents/ sin invocar git-bash' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\docs\nota.md'; content = 'sin frontmatter' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:bogusBash
        $result | Should Be $null
    }

    It 'permite agents/ con extension distinta de .md' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nota.txt'; content = 'sin frontmatter' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:bogusBash
        $result | Should Be $null
    }

    It 'ignora tools que no son Edit ni Write' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Read' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:bogusBash
        $result | Should Be $null
    }
}

Describe 'Test-AgentFrontmatterGuard - Edit' {

    It 'bloquea un Edit que rompe un campo requerido' {
        Mock Write-GuardLog {}
        $path = New-TempAgentFile -Content $script:validAgent
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'tools: Read, Grep'; new_string = 'otro: x' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Edit' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result.decision | Should Be 'block'
        $result.reason | Should Match 'MISSING-FIELD'
    }

    It 'permite un Edit que mantiene el frontmatter valido' {
        Mock Write-GuardLog {}
        $path = New-TempAgentFile -Content $script:validAgent
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'cuerpo'; new_string = 'cuerpo nuevo' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Edit' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result | Should Be $null
    }

    It 'no modifica el archivo real en disco' {
        Mock Write-GuardLog {}
        $path = New-TempAgentFile -Content $script:validAgent
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'tools: Read, Grep'; new_string = 'otro: x' }
        Test-AgentFrontmatterGuard -ToolName 'Edit' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash | Out-Null
        (Get-Content -Path $path -Raw) | Should Match 'tools: Read, Grep'
    }

    It 'old_string ausente en el archivo: evalua el contenido sin modificar (comportamiento actual) y permite si es valido' {
        Mock Write-GuardLog {}
        $path = New-TempAgentFile -Content $script:validAgent
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'texto que no existe'; new_string = 'x' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Edit' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result | Should Be $null
    }

    It 'Get-ResultingContent devuelve el contenido actual cuando old_string no se encuentra' {
        $path = New-TempAgentFile -Content $script:validAgent
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'texto que no existe'; new_string = 'x' }
        $content = Get-ResultingContent -ToolName 'Edit' -ToolInput $toolInput
        $content | Should Be (Get-Content -Path $path -Raw)
    }

    It 'sin replace_all reemplaza solo la primera ocurrencia' {
        $path = New-TempAgentFile -Content "uno uno uno"
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'uno'; new_string = 'dos' }
        Get-ResultingContent -ToolName 'Edit' -ToolInput $toolInput | Should Be 'dos uno uno'
    }

    It 'con replace_all reemplaza todas las ocurrencias' {
        $path = New-TempAgentFile -Content "uno uno uno"
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'uno'; new_string = 'dos'; replace_all = $true }
        Get-ResultingContent -ToolName 'Edit' -ToolInput $toolInput | Should Be 'dos dos dos'
    }

    It 'con replace_all bloquea si alguna ocurrencia rompe el frontmatter' {
        Mock Write-GuardLog {}
        $path = New-TempAgentFile -Content $script:validAgent
        $toolInput = [pscustomobject]@{ file_path = $path; old_string = 'name:'; new_string = 'nombre:'; replace_all = $true }
        $result = Test-AgentFrontmatterGuard -ToolName 'Edit' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result.decision | Should Be 'block'
    }

    It 'fail-open con log cuando el archivo del Edit no existe' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\no\existe\agents\fantasma.md'; old_string = 'a'; new_string = 'b' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Edit' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash
        $result | Should Be $null
        Assert-MockCalled Write-GuardLog -Exactly 1 -Scope It
    }
}

Describe 'Test-AgentFrontmatterGuard - fail-open' {

    It 'permite y loguea cuando git-bash no se resuelve' {
        Mock Write-GuardLog {}
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md'; content = 'sin frontmatter' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $null
        $result | Should Be $null
        Assert-MockCalled Write-GuardLog -Exactly 1 -Scope It
    }

    It 'permite y loguea cuando check-agent-frontmatter.sh esta ausente' {
        Mock Write-GuardLog {}
        $emptyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fm-guard-root-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $emptyRoot | Out-Null
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md'; content = 'sin frontmatter' }
        $result = Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $emptyRoot -GitBashPath $script:gitBash
        $result | Should Be $null
        Assert-MockCalled Write-GuardLog -Exactly 1 -Scope It
    }

    It 'no deja archivos temporales tras evaluar' {
        Mock Write-GuardLog {}
        $before = @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter '*.tmp' -ErrorAction SilentlyContinue).Count
        $toolInput = [pscustomobject]@{ file_path = 'C:\x\agents\nuevo.md'; content = $script:validAgent }
        Test-AgentFrontmatterGuard -ToolName 'Write' -ToolInput $toolInput -RepoRoot $script:repoRoot -GitBashPath $script:gitBash | Out-Null
        $after = @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter '*.tmp' -ErrorAction SilentlyContinue).Count
        $after | Should Not BeGreaterThan $before
    }
}

Describe 'Get-GitBashPath' {

    It 'resuelve bash.exe cuando el ejecutable de Git vive en mingw64\bin (PATH heredado de Git Bash)' {
        $fakeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fm-guard-gitroot-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'bin') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'mingw64\bin') | Out-Null
        New-Item -ItemType File -Path (Join-Path $fakeRoot 'bin\bash.exe') | Out-Null
        $fakeExe = Join-Path $fakeRoot 'mingw64\bin\git.exe'
        Mock Get-Command { [pscustomobject]@{ Source = $fakeExe } } -ParameterFilter { $Name -eq 'git' }
        Get-GitBashPath | Should Be (Join-Path $fakeRoot 'bin\bash.exe')
    }

    It 'devuelve null cuando no hay bash.exe en ningun ancestro' {
        $fakeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fm-guard-nobash-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'cmd') | Out-Null
        $fakeExe = Join-Path $fakeRoot 'cmd\git.exe'
        Mock Get-Command { [pscustomobject]@{ Source = $fakeExe } } -ParameterFilter { $Name -eq 'git' }
        Get-GitBashPath | Should Be $null
    }
}
