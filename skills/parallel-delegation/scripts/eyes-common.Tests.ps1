# eyes-common.Tests.ps1 - Pester 3.4.0, corre en pwsh 7 (Issue #402, A1).
#
# Cubre AC1 (raiz y RunId), AC4 (imagen uniforme) y AC22 (purga, enlaces, Remove-EyesRun).
# Dot-sourcea la libreria para llamar a las funciones directamente; los scripts que la usan
# (capture.ps1, crop.ps1) se prueban en sus propias suites, invocados con powershell.exe 5.1.
# Solo usa contenido sintetico: nada de capturas reales ni datos de pantalla.

$commonPath = Join-Path $PSScriptRoot 'eyes-common.ps1'
if (Test-Path -LiteralPath $commonPath) { . $commonPath }

$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:TempItems = New-Object System.Collections.ArrayList
$script:Junctions = New-Object System.Collections.ArrayList

function Skip-UnlessWindows {
    if (-not $script:IsWin) { Set-TestInconclusive -Message 'SKIP: el SO no es Windows' }
}

function New-TempDir {
    $p = Join-Path ([IO.Path]::GetTempPath()) ('eyes-t-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $p | Out-Null
    [void]$script:TempItems.Add($p)
    $p
}

function New-TempRepo {
    $d = New-TempDir
    git -C $d init -q 2>$null | Out-Null
    git -C $d config user.email 'test@example.invalid' | Out-Null
    git -C $d config user.name 'test' | Out-Null
    $d
}

function New-TestJunction {
    param([string]$Link, [string]$Target)
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    [void]$script:Junctions.Add($Link)
}

function Clear-TempItems {
    foreach ($j in @($script:Junctions)) {
        if (Test-Path -LiteralPath $j) { [IO.Directory]::Delete($j) }
    }
    $script:Junctions.Clear()
    foreach ($p in @($script:TempItems)) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $script:TempItems.Clear()
}

function New-RunIdAgo {
    param([int]$Minutes, [string]$Suffix = 'ab12')
    $ts = (Get-Date).ToUniversalTime().AddMinutes(-$Minutes)
    $ts.ToString("yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture) + '-' + $Suffix
}

function New-RunFolder {
    param([string]$Root, [string]$RunId)
    $d = Join-Path (Join-Path (Join-Path $Root 'output') 'eyes') $RunId
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $d 'captura.txt') -Value 'sintetico'
    $d
}

function Get-Thrown {
    param([scriptblock]$Block)
    try { & $Block } catch { return $_.Exception }
    $null
}

function New-TestBitmap {
    param([int]$W = 120, [int]$H = 60, [switch]$Text)
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    if ($Text) {
        $font = New-Object System.Drawing.Font 'Arial', 14
        $g.DrawString('EYES 123', $font, [System.Drawing.Brushes]::Black, 4, 10)
        $font.Dispose()
    }
    $g.Dispose()
    $bmp
}

Describe 'Resolve-EyesRoot (AC1 a-d)' {

    It 'AC1a: desde un subdirectorio devuelve el toplevel' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $sub = Join-Path $repo 'a\b'
        New-Item -ItemType Directory -Path $sub -Force | Out-Null
        Push-Location $sub
        try { $root = Resolve-EyesRoot } finally { Pop-Location }
        $root.Replace('/', '\').TrimEnd('\') | Should Be $repo.TrimEnd('\')
        Clear-TempItems
    }

    It 'AC1b: dentro de un submodulo .aura devuelve el superproyecto' {
        Skip-UnlessWindows
        $sub = New-TempRepo
        git -C $sub commit --allow-empty -q -m init 2>$null | Out-Null
        $super = New-TempRepo
        git -C $super -c protocol.file.allow=always submodule add $sub .aura 2>$null | Out-Null
        $inside = Join-Path $super '.aura'
        Test-Path -LiteralPath (Join-Path $inside '.git') | Should Be $true
        Push-Location $inside
        try { $root = Resolve-EyesRoot } finally { Pop-Location }
        $root.Replace('/', '\').TrimEnd('\') | Should Be $super.TrimEnd('\')
        Clear-TempItems
    }

    It 'AC1c: con -ProjectRoot explicito y cwd en otro lado devuelve ese repo' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $elsewhere = New-TempDir
        Push-Location $elsewhere
        try { $root = Resolve-EyesRoot -ProjectRoot $repo } finally { Pop-Location }
        $root.Replace('/', '\').TrimEnd('\') | Should Be $repo.TrimEnd('\')
        Clear-TempItems
    }

    It 'AC1d: fuera de un repo git lanza error' {
        Skip-UnlessWindows
        $plain = New-TempDir
        $ex = Get-Thrown { Resolve-EyesRoot -ProjectRoot $plain }
        ($ex -is [System.ArgumentException]) | Should Be $true
        Clear-TempItems
    }
}

Describe 'Test-EyesRunId (AC1 e)' {

    It 'AC1e: acepta un RunId valido' {
        Test-EyesRunId '20261012T181500Z-a3f1' | Should Be $true
    }
    It 'AC1e: rechaza cadena vacia' {
        Test-EyesRunId '' | Should Be $false
    }
    It 'AC1e: rechaza ..\x' {
        Test-EyesRunId '..\x' | Should Be $false
    }
    It 'AC1e: rechaza ../x' {
        Test-EyesRunId '../x' | Should Be $false
    }
    It 'AC1e: rechaza ruta absoluta con letra de unidad' {
        Test-EyesRunId 'C:\Windows' | Should Be $false
    }
    It 'AC1e: rechaza hex en mayusculas' {
        Test-EyesRunId '20261012T181500Z-A3F1' | Should Be $false
    }
    It 'AC1e: rechaza un caracter de sobra al final' {
        Test-EyesRunId '20261012T181500Z-a3f1x' | Should Be $false
    }
    It 'AC1e: rechaza salto de linea final' {
        Test-EyesRunId ("20261012T181500Z-a3f1" + "`n") | Should Be $false
    }
}

Describe 'Get-EyesRunDir y New-EyesRunId (AC1 f-g)' {

    It 'AC1f: Get-EyesRunDir con RunId invalido lanza error' {
        $root = Join-Path ([IO.Path]::GetTempPath()) 'eyes-no-existe'
        $ex = Get-Thrown { Get-EyesRunDir -Root $root -RunId '..\x' }
        ($ex -is [System.ArgumentException]) | Should Be $true
    }

    It 'Get-EyesRunDir con RunId valido queda dentro de output/eyes' {
        $root = Join-Path ([IO.Path]::GetTempPath()) 'eyes-no-existe'
        $dir = Get-EyesRunDir -Root $root -RunId '20261012T181500Z-a3f1'
        $expected = [IO.Path]::GetFullPath((Join-Path $root 'output\eyes\20261012T181500Z-a3f1'))
        $dir | Should Be $expected
    }

    It 'AC1g: New-EyesRunId cumple la regex en 100 iteraciones' {
        $bad = 0
        for ($i = 0; $i -lt 100; $i++) {
            $id = New-EyesRunId
            if (-not ($id -cmatch '\A[0-9]{8}T[0-9]{6}Z-[0-9a-f]{4}\z')) { $bad++ }
            if (-not (Test-EyesRunId $id)) { $bad++ }
        }
        $bad | Should Be 0
    }
}

Describe 'Assert-OutputIgnored' {

    It 'devuelve sin error cuando output/ esta en .gitignore' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        Set-Content -LiteralPath (Join-Path $repo '.gitignore') -Value 'output/'
        Assert-OutputIgnored -Root $repo -Path 'output/eyes/x/captura.png' | Should Be $true
        Clear-TempItems
    }

    It 'lanza InvalidOperationException cuando output/ no esta ignorado (falla cerrada)' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $ex = Get-Thrown { Assert-OutputIgnored -Root $repo -Path 'output/eyes/x/captura.png' }
        ($ex -is [System.InvalidOperationException]) | Should Be $true
        Clear-TempItems
    }
}

Describe 'Test-EyesImageUniform (AC4)' {

    It 'AC4: bitmap de un solo color es uniforme' {
        Skip-UnlessWindows
        $bmp = New-TestBitmap
        try { Test-EyesImageUniform -Bitmap $bmp | Should Be $true } finally { $bmp.Dispose() }
    }

    It 'AC4: bitmap con texto no es uniforme' {
        Skip-UnlessWindows
        $bmp = New-TestBitmap -Text
        try { Test-EyesImageUniform -Bitmap $bmp | Should Be $false } finally { $bmp.Dispose() }
    }
}

Describe 'Invoke-EyesPurge y Remove-EyesRun (AC22)' {

    It 'AC22-1: un run de hace 61 minutos se borra y figura en purgados' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 61
        $dir = New-RunFolder -Root $repo -RunId $id
        $r = Invoke-EyesPurge -Root $repo
        (Test-Path -LiteralPath $dir) | Should Be $false
        (@($r.purgados) -contains $id) | Should Be $true
        Clear-TempItems
    }

    It 'AC22-2: un run de hace 59 minutos sobrevive' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 59
        $dir = New-RunFolder -Root $repo -RunId $id
        $r = Invoke-EyesPurge -Root $repo
        (Test-Path -LiteralPath $dir) | Should Be $true
        @($r.purgados).Count | Should Be 0
        Clear-TempItems
    }

    It 'AC22-3: nombres que no son RunId sobreviven' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $eyes = Join-Path $repo 'output\eyes'
        New-Item -ItemType Directory -Path $eyes -Force | Out-Null
        $upper = (New-RunIdAgo -Minutes 300).ToUpper()
        $survivors = @('.venv', 'manual-viejo', $upper)
        foreach ($n in $survivors) { New-Item -ItemType Directory -Path (Join-Path $eyes $n) | Out-Null }
        Set-Content -LiteralPath (Join-Path $eyes 'notas.txt') -Value 'x'
        $r = Invoke-EyesPurge -Root $repo
        foreach ($n in $survivors) { (Test-Path -LiteralPath (Join-Path $eyes $n)) | Should Be $true }
        (Test-Path -LiteralPath (Join-Path $eyes 'notas.txt')) | Should Be $true
        @($r.purgados).Count | Should Be 0
        Clear-TempItems
    }

    It 'AC22-4: un run enlace (junction) no se sigue ni se borra y figura en omitidos' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $eyes = Join-Path $repo 'output\eyes'
        New-Item -ItemType Directory -Path $eyes -Force | Out-Null
        $target = New-TempDir
        $sentinel = Join-Path $target 'centinela.txt'
        Set-Content -LiteralPath $sentinel -Value 'no me borres'
        $id = New-RunIdAgo -Minutes 120
        New-TestJunction -Link (Join-Path $eyes $id) -Target $target
        $r = Invoke-EyesPurge -Root $repo
        (Test-Path -LiteralPath $sentinel) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $eyes $id)) | Should Be $true
        @($r.purgados).Count | Should Be 0
        $om = @($r.omitidos)
        $om.Count | Should Be 1
        $om[0].nombre | Should Be $id
        [string]::IsNullOrWhiteSpace($om[0].motivo) | Should Be $false
        Clear-TempItems
    }

    It 'AC22-5: contencion - hermano output/eyes-otro y centinela externo intactos' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        New-Item -ItemType Directory -Path (Join-Path $repo 'output\eyes') -Force | Out-Null
        $id = New-RunIdAgo -Minutes 300
        $otro = New-RunFolder -Root $repo -RunId $id
        $hermano = Join-Path $repo "output\eyes-otro\$id"
        New-Item -ItemType Directory -Path $hermano -Force | Out-Null
        $fuera = Join-Path $repo 'centinela-fuera.txt'
        Set-Content -LiteralPath $fuera -Value 'x'
        $r = Invoke-EyesPurge -Root $repo
        (Test-Path -LiteralPath $hermano) | Should Be $true
        (Test-Path -LiteralPath $fuera) | Should Be $true
        (Test-Path -LiteralPath $otro) | Should Be $false
        Clear-TempItems
    }

    It 'AC22-6: sin output/eyes devuelve purgados vacio sin error y no crea la carpeta' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $r = Invoke-EyesPurge -Root $repo
        @($r.purgados).Count | Should Be 0
        @($r.omitidos).Count | Should Be 0
        (Test-Path -LiteralPath (Join-Path $repo 'output\eyes')) | Should Be $false
        Clear-TempItems
    }

    It 'AC22-7: un run con archivo abierto no detiene la purga y figura en omitidos' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $idBloqueado = New-RunIdAgo -Minutes 100 -Suffix 'aaaa'
        $idLibre = New-RunIdAgo -Minutes 100 -Suffix 'bbbb'
        $dirBloqueado = New-RunFolder -Root $repo -RunId $idBloqueado
        $dirLibre = New-RunFolder -Root $repo -RunId $idLibre
        $fs = [IO.File]::Open((Join-Path $dirBloqueado 'captura.txt'), 'Open', 'ReadWrite', 'None')
        try {
            $r = Invoke-EyesPurge -Root $repo
        } finally { $fs.Dispose() }
        (Test-Path -LiteralPath $dirBloqueado) | Should Be $true
        (Test-Path -LiteralPath $dirLibre) | Should Be $false
        (@($r.purgados) -contains $idLibre) | Should Be $true
        $om = @($r.omitidos | Where-Object { $_.nombre -eq $idBloqueado })
        $om.Count | Should Be 1
        [string]::IsNullOrWhiteSpace($om[0].motivo) | Should Be $false
        Clear-TempItems
    }

    It 'AC22-8: Remove-EyesRun con RunId invalido lanza la clase argumento/enlace y no borra nada' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 300
        $dir = New-RunFolder -Root $repo -RunId $id
        $ex = Get-Thrown { Remove-EyesRun -Root $repo -RunId '..\x' }
        ($ex -is [System.ArgumentException]) | Should Be $true
        ($ex -is [System.IO.IOException]) | Should Be $false
        (Test-Path -LiteralPath $dir) | Should Be $true
        Clear-TempItems
    }

    It 'AC22-9: con output/eyes como junction Invoke-EyesPurge lanza argumento/enlace y no toca el destino' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        New-Item -ItemType Directory -Path (Join-Path $repo 'output') -Force | Out-Null
        $target = New-TempDir
        $id = New-RunIdAgo -Minutes 300
        $viejoReal = Join-Path $target $id
        New-Item -ItemType Directory -Path $viejoReal | Out-Null
        Set-Content -LiteralPath (Join-Path $viejoReal 'captura.txt') -Value 'sintetico'
        New-TestJunction -Link (Join-Path $repo 'output\eyes') -Target $target
        $ex = Get-Thrown { Invoke-EyesPurge -Root $repo }
        ($ex -is [System.ArgumentException]) | Should Be $true
        (Test-Path -LiteralPath $viejoReal) | Should Be $true
        Clear-TempItems
    }

    It 'AC22-10: con output como junction Invoke-EyesPurge lanza argumento/enlace y no toca el destino' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $target = New-TempDir
        $id = New-RunIdAgo -Minutes 300
        $viejo = New-RunFolder -Root $target -RunId $id
        New-TestJunction -Link (Join-Path $repo 'output') -Target (Join-Path $target 'output')
        $ex = Get-Thrown { Invoke-EyesPurge -Root $repo }
        ($ex -is [System.ArgumentException]) | Should Be $true
        (Test-Path -LiteralPath $viejo) | Should Be $true
        Clear-TempItems
    }

    It 'AC22-12: Remove-EyesRun sobre un run con archivo abierto lanza la clase E/S' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 5
        $dir = New-RunFolder -Root $repo -RunId $id
        $fs = [IO.File]::Open((Join-Path $dir 'captura.txt'), 'Open', 'ReadWrite', 'None')
        try {
            $ex = Get-Thrown { Remove-EyesRun -Root $repo -RunId $id }
        } finally { $fs.Dispose() }
        ($ex -is [System.IO.IOException]) | Should Be $true
        ($ex -is [System.ArgumentException]) | Should Be $false
        Clear-TempItems
    }

    It 'Remove-EyesRun borra un run valido y lo devuelve en purgados' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 5
        $dir = New-RunFolder -Root $repo -RunId $id
        $r = Remove-EyesRun -Root $repo -RunId $id
        (Test-Path -LiteralPath $dir) | Should Be $false
        (@($r.purgados) -contains $id) | Should Be $true
        Clear-TempItems
    }
}

function New-NestedLinkRun {
    $repo = New-TempRepo
    $id = New-RunIdAgo -Minutes 100
    $dir = New-RunFolder -Root $repo -RunId $id
    $target = New-TempDir
    $sentinel = Join-Path $target 'centinela.txt'
    Set-Content -LiteralPath $sentinel -Value 'no me borres'
    New-TestJunction -Link (Join-Path $dir 'lnk') -Target $target
    [pscustomobject]@{ Repo = $repo; RunId = $id; Dir = $dir; Sentinel = $sentinel }
}

function Invoke-Ps51Scenario {
    param([string]$Root, [string]$Mode, [string]$RunId)
    $scriptDir = New-TempDir
    $scenario = Join-Path $scriptDir 'escenario.ps1'
    $body = @'
param([string]$Common, [string]$Root, [string]$Mode, [string]$RunId)
$ErrorActionPreference = 'Stop'
. $Common
if ($Mode -eq 'remove') { $r = Remove-EyesRun -Root $Root -RunId $RunId } else { $r = Invoke-EyesPurge -Root $Root }
$r | ConvertTo-Json -Depth 5 -Compress
'@
    Set-Content -LiteralPath $scenario -Value $body -Encoding UTF8
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
    $raw = & powershell.exe -NoProfile -File $scenario -Common $commonPath -Root $Root -Mode $Mode -RunId $RunId 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Raw = (($raw | Out-String).Trim()) }
}

Describe 'Enlace anidado dentro de un run (review MAYOR 2)' {

    AfterEach { Clear-TempItems }

    It 'Remove-EyesRun (pwsh 7) borra el run y no el contenido del destino de un enlace anidado' {
        Skip-UnlessWindows
        $s = New-NestedLinkRun
        $r = Remove-EyesRun -Root $s.Repo -RunId $s.RunId
        (Test-Path -LiteralPath $s.Dir) | Should Be $false
        (Test-Path -LiteralPath $s.Sentinel) | Should Be $true
        (@($r.purgados) -contains $s.RunId) | Should Be $true
        Clear-TempItems
    }

    It 'Invoke-EyesPurge (pwsh 7) borra el run y no el contenido del destino de un enlace anidado' {
        Skip-UnlessWindows
        $s = New-NestedLinkRun
        $r = Invoke-EyesPurge -Root $s.Repo
        (Test-Path -LiteralPath $s.Dir) | Should Be $false
        (Test-Path -LiteralPath $s.Sentinel) | Should Be $true
        (@($r.purgados) -contains $s.RunId) | Should Be $true
        Clear-TempItems
    }

    It 'Remove-EyesRun bajo powershell.exe 5.1 borra el run y no el contenido del destino de un enlace anidado' {
        Skip-UnlessWindows
        $s = New-NestedLinkRun
        $o = Invoke-Ps51Scenario -Root $s.Repo -Mode 'remove' -RunId $s.RunId
        $o.Exit | Should Be 0
        (Test-Path -LiteralPath $s.Dir) | Should Be $false
        (Test-Path -LiteralPath $s.Sentinel) | Should Be $true
        Clear-TempItems
    }

    It 'Invoke-EyesPurge bajo powershell.exe 5.1 borra el run y no el contenido del destino de un enlace anidado' {
        Skip-UnlessWindows
        $s = New-NestedLinkRun
        $o = Invoke-Ps51Scenario -Root $s.Repo -Mode 'purge' -RunId $s.RunId
        $o.Exit | Should Be 0
        (Test-Path -LiteralPath $s.Dir) | Should Be $false
        (Test-Path -LiteralPath $s.Sentinel) | Should Be $true
        Clear-TempItems
    }
}

Describe 'New-EyesRunDir crea el run de forma atomica (review ronda 3, punto A)' {

    AfterEach { Clear-TempItems }

    It 'crea output/eyes y el run cuando faltan y devuelve la ruta del run' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 1
        $dir = New-EyesRunDir -Root $repo -RunId $id
        (Test-Path -LiteralPath $dir -PathType Container) | Should Be $true
        $dir | Should Be (Get-EyesRunDir -Root $repo -RunId $id)
    }

    It 'un run que ya existe lanza la clase argumento/enlace y no toca su contenido' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 1
        $dir = New-RunFolder -Root $repo -RunId $id
        $ex = Get-Thrown { New-EyesRunDir -Root $repo -RunId $id }
        ($ex -is [System.ArgumentException]) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $dir 'captura.txt')) | Should Be $true
    }

    It 'un run que es una junction lanza la clase argumento/enlace y no escribe en el destino' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $id = New-RunIdAgo -Minutes 1
        New-Item -ItemType Directory -Path (Join-Path $repo 'output\eyes') -Force | Out-Null
        $target = New-TempDir
        $sentinel = Join-Path $target 'centinela.txt'
        Set-Content -LiteralPath $sentinel -Value 'no me toques'
        New-TestJunction -Link (Join-Path $repo "output\eyes\$id") -Target $target
        $ex = Get-Thrown { New-EyesRunDir -Root $repo -RunId $id }
        ($ex -is [System.ArgumentException]) | Should Be $true
        (Test-Path -LiteralPath $sentinel) | Should Be $true
        @(Get-ChildItem -LiteralPath $target -Force).Count | Should Be 1
    }

    It 'un RunId invalido lanza la clase argumento/enlace sin crear nada' {
        Skip-UnlessWindows
        $repo = New-TempRepo
        $ex = Get-Thrown { New-EyesRunDir -Root $repo -RunId '..\x' }
        ($ex -is [System.ArgumentException]) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $repo 'output')) | Should Be $false
    }
}

Describe 'Test-EyesLink con ruta inexistente (review MENOR 3)' {

    It 'una ruta que no existe devuelve false sin lanzar' {
        $ruta = Join-Path ([IO.Path]::GetTempPath()) ('eyes-no-existe-' + [guid]::NewGuid().ToString('N'))
        Test-EyesLink -Path $ruta | Should Be $false
    }
}

Describe 'Test-EyesLink falla cerrada ante errores de consulta (review MENOR 3)' {

    It 'si Get-Item falla por un motivo distinto de no existe lanza la clase argumento/enlace' {
        Mock Get-Item { throw (New-Object System.UnauthorizedAccessException 'acceso denegado simulado') }
        $ex = Get-Thrown { Test-EyesLink -Path 'C:\no-consultable' }
        ($ex -is [System.ArgumentException]) | Should Be $true
    }
}

# Describe aparte: en Pester 3.4 un Mock declarado dentro de un It sigue activo hasta el fin del Describe.
Describe 'Test-EyesLink con objetos simulados (AC22-11)' {

    It 'AC22-11: Test-EyesLink distingue enlaces de placeholders de nube (Mock Get-Item)' {
        Mock Get-Item { [pscustomobject]@{ Attributes = ([IO.FileAttributes]::ReparsePoint -bor [IO.FileAttributes]::Directory); LinkType = $null } }
        Test-EyesLink -Path 'C:\placeholder-nube' | Should Be $false
        Mock Get-Item { [pscustomobject]@{ Attributes = ([IO.FileAttributes]::ReparsePoint -bor [IO.FileAttributes]::Directory); LinkType = 'Junction' } }
        Test-EyesLink -Path 'C:\una-junction' | Should Be $true
        Mock Get-Item { [pscustomobject]@{ Attributes = ([IO.FileAttributes]::ReparsePoint -bor [IO.FileAttributes]::Directory); LinkType = 'SymbolicLink' } }
        Test-EyesLink -Path 'C:\un-symlink' | Should Be $true
    }
}
