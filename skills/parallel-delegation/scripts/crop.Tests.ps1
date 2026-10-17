# crop.Tests.ps1 - Pester 3.4.0, corre en pwsh 7 e invoca crop.ps1 con powershell.exe 5.1
# (Issue #402, A1). Cubre AC6. Solo usa PNG sinteticos generados por el propio test.

$script:Crop = Join-Path $PSScriptRoot 'crop.ps1'
$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:TempItems = New-Object System.Collections.ArrayList
$script:Junctions = New-Object System.Collections.ArrayList

function Skip-UnlessWindows {
    if (-not $script:IsWin) { Set-TestInconclusive -Message 'SKIP: el SO no es Windows' }
}

function New-TempDir {
    $p = Join-Path ([IO.Path]::GetTempPath()) ('eyes-k-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $p | Out-Null
    [void]$script:TempItems.Add($p)
    $p
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

function New-CropRepo {
    $d = New-TempDir
    git -C $d init -q 2>$null | Out-Null
    git -C $d config user.email 'test@example.invalid' | Out-Null
    git -C $d config user.name 'test' | Out-Null
    [IO.File]::WriteAllText((Join-Path $d '.gitignore'), "output/`n")
    $d
}

function New-SourcePng {
    param([string]$Path)
    Add-Type -AssemblyName System.Drawing
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp = New-Object System.Drawing.Bitmap 100, 100
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 220, 0, 0))
    $g.FillRectangle($brush, 10, 10, 20, 30)
    $brush.Dispose()
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function New-RunPng {
    param([string]$Root)
    $id = (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture) + '-ab12'
    $png = Join-Path $Root "output\eyes\$id\captura.png"
    New-SourcePng -Path $png
    [pscustomobject]@{ RunId = $id; Png = $png; Dir = (Split-Path -Parent $png) }
}

function Invoke-Crop {
    param([string[]]$ScriptArgs)
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
    $raw = & powershell.exe -NoProfile -File $script:Crop @ScriptArgs 2>$null
    $code = $LASTEXITCODE
    $text = ($raw | Out-String).Trim()
    $json = $null
    try { $json = $text | ConvertFrom-Json } catch { }
    [pscustomobject]@{ Exit = $code; Raw = $text; Json = $json }
}

Describe 'crop.ps1 (AC6)' {

    It 'AC6: -Bbox 10,10,20,30 devuelve 20x30 y escribe captura-crop.png junto al origen' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '10,10,20,30', '-ProjectRoot', $root)
        $o.Exit | Should Be 0
        $o.Json.ok | Should Be $true
        $o.Json.width | Should Be 20
        $o.Json.height | Should Be 30
        $expected = Join-Path $src.Dir 'captura-crop.png'
        (Test-Path -LiteralPath $expected) | Should Be $true
        ([IO.Path]::GetFullPath($o.Json.path)) | Should Be ([IO.Path]::GetFullPath($expected))
        Clear-TempItems
    }

    It 'AC6: el recorte contiene los pixeles de la region pedida' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '10,10,20,30', '-ProjectRoot', $root)
        $o.Exit | Should Be 0
        Add-Type -AssemblyName System.Drawing
        $bytes = [IO.File]::ReadAllBytes((Join-Path $src.Dir 'captura-crop.png'))
        $ms = New-Object IO.MemoryStream (, $bytes)
        $img = New-Object System.Drawing.Bitmap $ms
        try {
            $img.Width | Should Be 20
            $img.Height | Should Be 30
            $img.GetPixel(0, 0).R | Should BeGreaterThan 200
            $img.GetPixel(0, 0).G | Should BeLessThan 50
            $img.GetPixel(19, 29).G | Should BeLessThan 50
        } finally { $img.Dispose(); $ms.Dispose() }
        Clear-TempItems
    }

    It 'AC6: con -DeleteSource el origen deja de existir' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '10,10,20,30', '-DeleteSource', '-ProjectRoot', $root)
        $o.Exit | Should Be 0
        (Test-Path -LiteralPath $src.Png) | Should Be $false
        (Test-Path -LiteralPath (Join-Path $src.Dir 'captura-crop.png')) | Should Be $true
        Clear-TempItems
    }

    It 'AC6: sin -DeleteSource el origen existe' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '10,10,20,30', '-ProjectRoot', $root)
        $o.Exit | Should Be 0
        (Test-Path -LiteralPath $src.Png) | Should Be $true
        Clear-TempItems
    }

    It 'AC6: -Bbox fuera de la imagen termina en exit 2 y el origen queda intacto' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '90,90,20,20', '-DeleteSource', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath $src.Png) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $src.Dir 'captura-crop.png')) | Should Be $false
        Clear-TempItems
    }

    It 'AC6: -Bbox con w o h <= 0 termina en exit 2' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '10,10,0,30', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        Clear-TempItems
    }

    It 'AC6: -Image inexistente termina en exit 2' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $o = Invoke-Crop @('-Image', (Join-Path $root 'output\eyes\no-existe.png'), '-Bbox', '0,0,5,5', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        Clear-TempItems
    }

    It 'AC6: -DeleteSource con -Image fuera de output/eyes/ termina en exit 2 y el origen queda intacto' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $fuera = Join-Path $root 'otro\captura.png'
        New-SourcePng -Path $fuera
        $o = Invoke-Crop @('-Image', $fuera, '-Bbox', '10,10,20,30', '-DeleteSource', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath $fuera) | Should Be $true
        Clear-TempItems
    }

    It 'AC6: -DeleteSource con el run convertido en junction hacia fuera de output/eyes/ termina en exit 2 y el destino queda intacto' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $target = New-TempDir
        $real = Join-Path $target 'captura.png'
        New-SourcePng -Path $real
        $id = (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture) + '-cd34'
        New-Item -ItemType Directory -Path (Join-Path $root 'output\eyes') -Force | Out-Null
        $link = Join-Path $root "output\eyes\$id"
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        [void]$script:Junctions.Add($link)
        $o = Invoke-Crop @('-Image', (Join-Path $link 'captura.png'), '-Bbox', '10,10,20,30', '-DeleteSource', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath $real) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $target 'captura-crop.png')) | Should Be $false
        Clear-TempItems
    }

    It 'review MENOR 7: destino -crop.png existente como enlace: exit 2, nada escrito a traves del enlace y origen intacto' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $src = New-RunPng -Root $root
        $target = New-TempDir
        $sentinel = Join-Path $target 'centinela.txt'
        Set-Content -LiteralPath $sentinel -Value 'no me toques'
        $link = Join-Path $src.Dir 'captura-crop.png'
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        [void]$script:Junctions.Add($link)
        $o = Invoke-Crop @('-Image', $src.Png, '-Bbox', '10,10,20,30', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath $src.Png) | Should Be $true
        (Test-Path -LiteralPath $sentinel) | Should Be $true
        @(Get-ChildItem -LiteralPath $target -Force).Count | Should Be 1
        Clear-TempItems
    }

    It 'review MENOR 7: directorio padre enlace: exit 2 y no se escribe el recorte en el destino del enlace' {
        Skip-UnlessWindows
        $root = New-CropRepo
        $target = New-TempDir
        $real = Join-Path $target 'captura.png'
        New-SourcePng -Path $real
        $link = Join-Path $root 'enlace'
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        [void]$script:Junctions.Add($link)
        $o = Invoke-Crop @('-Image', (Join-Path $link 'captura.png'), '-Bbox', '10,10,20,30', '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath $real) | Should Be $true
        (Test-Path -LiteralPath (Join-Path $target 'captura-crop.png')) | Should Be $false
        Clear-TempItems
    }
}
