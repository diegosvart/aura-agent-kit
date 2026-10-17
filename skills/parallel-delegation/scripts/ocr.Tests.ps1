# ocr.Tests.ps1 - Pester 3.4.0, corre en pwsh 7 e invoca ocr.ps1 con powershell.exe 5.1
# (Issue #403, A2). Cubre AC5 (OCR + -OutFile) y AC7 (calibracion sintetica).
#
# Todas las imagenes son SINTETICAS: las dibuja este test con System.Drawing (dentro de
# powershell.exe 5.1) a partir de textos fijados aqui. Nunca se fotografia la pantalla real ni se
# usa texto de pantallas reales. Las 7 muestras de calibracion imprimen filas
#   | muestra-N | tipo | esperado | devuelto | correcta | umbral |
# que se copian tal cual al body del PR, y la ultima imprime las lineas umbral_<nombre>: <numero>.
# Esas muestras registran su resultado y nunca fallan por un OCR incorrecto (solo si el script falla).

$script:Ocr = Join-Path $PSScriptRoot 'ocr.ps1'
$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:TempItems = New-Object System.Collections.ArrayList
$script:Junctions = New-Object System.Collections.ArrayList
$script:Muestras = New-Object System.Collections.ArrayList

$script:GenSource = @'
param(
    [string]$Out,
    [int]$W,
    [int]$H,
    [string]$Text,
    [string]$Font,
    [double]$Size,
    [string]$Unit,
    [string]$Fg,
    [string]$Bg,
    [string]$Hint,
    [int]$X,
    [int]$Y
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$gUnit = [System.Drawing.GraphicsUnit]::Point
if ($Unit -eq 'px') { $gUnit = [System.Drawing.GraphicsUnit]::Pixel }
$fontObj = New-Object System.Drawing.Font $Font, ([single]$Size), ([System.Drawing.FontStyle]::Regular), $gUnit
$fgRgb = $Fg.Split(',') | ForEach-Object { [int]$_ }
$bgRgb = $Bg.Split(',') | ForEach-Object { [int]$_ }
if ($W -le 0 -or $H -le 0) {
    $probe = New-Object System.Drawing.Bitmap 10, 10
    $gp = [System.Drawing.Graphics]::FromImage($probe)
    $sz = $gp.MeasureString($Text, $fontObj)
    $gp.Dispose(); $probe.Dispose()
    $W = [int][math]::Ceiling($sz.Width) + 2 * $X
    $H = [int][math]::Ceiling($sz.Height) + 2 * $Y
}
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255, $bgRgb[0], $bgRgb[1], $bgRgb[2]))
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::$Hint
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $fgRgb[0], $fgRgb[1], $fgRgb[2]))
if ($Text) { $g.DrawString($Text, $fontObj, $brush, [single]$X, [single]$Y) }
$brush.Dispose(); $g.Dispose(); $fontObj.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
'@

function Skip-UnlessWindows {
    if (-not $script:IsWin) { Set-TestInconclusive -Message 'SKIP: el SO no es Windows' }
}

function New-TempDir {
    $p = Join-Path ([IO.Path]::GetTempPath()) ('eyes-o-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
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

function New-OcrRepo {
    param([switch]$SinIgnore)
    $d = New-TempDir
    git -C $d init -q 2>$null | Out-Null
    git -C $d config user.email 'test@example.invalid' | Out-Null
    git -C $d config user.name 'test' | Out-Null
    if (-not $SinIgnore) { [IO.File]::WriteAllText((Join-Path $d '.gitignore'), "output/`n") }
    $d
}

function Get-GenScript {
    $p = Join-Path ([IO.Path]::GetTempPath()) 'eyes-o-gen.ps1'
    if (-not (Test-Path -LiteralPath $p)) {
        [IO.File]::WriteAllText($p, $script:GenSource, (New-Object Text.UTF8Encoding($false)))
    }
    if (-not $script:TempItems.Contains($p)) { [void]$script:TempItems.Add($p) }
    $p
}

function New-SynthPng {
    param(
        [string]$Path, [string]$Text, [string]$Font = 'Segoe UI', [double]$Size = 28, [string]$Unit = 'px',
        [string]$Fg = '0,0,0', [string]$Bg = '255,255,255', [string]$Hint = 'AntiAlias',
        [int]$W = 0, [int]$H = 0, [int]$X = 20, [int]$Y = 30
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $gen = Get-GenScript
    $null = & powershell.exe -NoProfile -File $gen -Out $Path -W $W -H $H -Text $Text -Font $Font -Size $Size -Unit $Unit -Fg $Fg -Bg $Bg -Hint $Hint -X $X -Y $Y 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Path)) { throw "no se pudo generar la muestra sintetica en $Path" }
}

function New-RunId {
    (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture) + '-ab12'
}

function Invoke-Ocr {
    param([string[]]$ScriptArgs)
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
    $raw = & powershell.exe -NoProfile -File $script:Ocr @ScriptArgs 2>$null
    $code = $LASTEXITCODE
    $text = ($raw | Out-String).Trim()
    $json = $null
    try { $json = $text | ConvertFrom-Json } catch { }
    [pscustomobject]@{ Exit = $code; Raw = $text; Json = $json }
}

function ConvertTo-NormText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    (($Text.ToLowerInvariant()) -replace '\s+', ' ').Trim()
}

function Get-RarosPct {
    param([string]$Text)
    $t = ($Text -replace '\s', '')
    if ($t.Length -eq 0) { return 0 }
    $raros = ([regex]::Matches($t, '[^A-Za-z0-9\$>/\.,:;_=\-\+\*\(\)\[\]\{\}"''#@%&!\?~\^\\<`]')).Count
    [int][math]::Round(100.0 * $raros / $t.Length)
}

function Get-SimilitudPct {
    param([string]$A, [string]$B)
    if ($A.Length -eq 0 -and $B.Length -eq 0) { return 100 }
    $prev = New-Object 'int[]' ($B.Length + 1)
    $cur = New-Object 'int[]' ($B.Length + 1)
    for ($j = 0; $j -le $B.Length; $j++) { $prev[$j] = $j }
    for ($i = 1; $i -le $A.Length; $i++) {
        $cur[0] = $i
        for ($j = 1; $j -le $B.Length; $j++) {
            $cost = 1
            if ($A[$i - 1] -ceq $B[$j - 1]) { $cost = 0 }
            $cur[$j] = [math]::Min([math]::Min($cur[$j - 1] + 1, $prev[$j] + 1), $prev[$j - 1] + $cost)
        }
        $t = $prev; $prev = $cur; $cur = $t
    }
    $dist = $prev[$B.Length]
    $max = [math]::Max($A.Length, $B.Length)
    [int][math]::Round(100.0 * (1 - $dist / $max))
}

function Invoke-Muestra {
    param([string]$Id, [string]$Tipo, [string]$Expected, [hashtable]$Draw)
    $root = New-TempDir
    $png = Join-Path $root 'muestra.png'
    New-SynthPng -Path $png @Draw
    $o = Invoke-Ocr @('-Image', $png, '-Lang', 'es-MX')
    $o.Exit | Should Be 0
    $o.Json.ok | Should Be $true
    $devuelto = [string]$o.Json.text
    $normD = ConvertTo-NormText $devuelto
    $correcta = $normD.Contains((ConvertTo-NormText $Expected))
    $raros = Get-RarosPct $devuelto
    $chars = [int]$o.Json.chars
    $mostrar = ($normD -replace '\|', '\|')
    $sim = Get-SimilitudPct -A (ConvertTo-NormText $Expected) -B $normD
    $row = [pscustomobject]@{
        Id = $Id; Tipo = $Tipo; Correcta = $correcta; Chars = $chars; Raros = $raros; Sim = $sim
        Fila = ('| {0} | {1} | {2} | {3} | {4} | chars={5} raros={6} |' -f $Id, $Tipo, ($Expected -replace '\|', '\|'), $mostrar, $(if ($correcta) { 'sí' } else { 'no' }), $chars, $raros)
    }
    [void]$script:Muestras.Add($row)
    Write-Host $row.Fila
    $row
}

Describe 'ocr.ps1 (AC5, AC7)' {

    AfterEach { Clear-TempItems }

    It 'AC5: -Lang es-MX reconoce "Prueba OCR 123"' {
        Skip-UnlessWindows
        $root = New-TempDir
        $png = Join-Path $root 'prueba.png'
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $o = Invoke-Ocr @('-Image', $png, '-Lang', 'es-MX')
        $o.Exit | Should Be 0
        $o.Json.ok | Should Be $true
        $o.Json.engine | Should Be 'windows-media-ocr'
        if ($o.Json.lang_fallback) { Set-TestInconclusive -Message 'SKIP: idioma es-MX no instalado' }
        $o.Json.lang | Should Be 'es-MX'
        (ConvertTo-NormText $o.Json.text).Contains('prueba ocr 123') | Should Be $true
        @($o.Json.lines).Count | Should BeGreaterThan 0
        @($o.Json.lines[0].bbox).Count | Should Be 4
    }

    It 'AC5: -Lang en-US reconoce "Prueba OCR 123"' {
        Skip-UnlessWindows
        $root = New-TempDir
        $png = Join-Path $root 'prueba.png'
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $o = Invoke-Ocr @('-Image', $png, '-Lang', 'en-US')
        $o.Exit | Should Be 0
        $o.Json.ok | Should Be $true
        if ($o.Json.lang_fallback) { Set-TestInconclusive -Message 'SKIP: idioma en-US no instalado' }
        $o.Json.lang | Should Be 'en-US'
        (ConvertTo-NormText $o.Json.text).Contains('prueba ocr 123') | Should Be $true
    }

    It 'AC5: imagen inexistente termina en exit 2' {
        Skip-UnlessWindows
        $root = New-TempDir
        $o = Invoke-Ocr @('-Image', (Join-Path $root 'no-existe.png'))
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
    }

    It 'AC5: PNG de 10001x10 (sobre MaxImageDimension) termina en exit 2' {
        Skip-UnlessWindows
        $root = New-TempDir
        $png = Join-Path $root 'ancha.png'
        Add-Type -AssemblyName System.Drawing
        $bmp = New-Object System.Drawing.Bitmap 10001, 10
        $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $o = Invoke-Ocr @('-Image', $png)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
    }

    It 'AC5: PNG blanco 600x120 devuelve exit 0, chars 0, text vacio y lines vacio' {
        Skip-UnlessWindows
        $root = New-TempDir
        $png = Join-Path $root 'blanco.png'
        New-SynthPng -Path $png -Text ' ' -W 600 -H 120
        $o = Invoke-Ocr @('-Image', $png)
        $o.Exit | Should Be 0
        $o.Json.ok | Should Be $true
        $o.Json.chars | Should Be 0
        $o.Json.text | Should Be ''
        @($o.Json.lines).Count | Should Be 0
    }

    It 'AC7: muestra-1 terminal Consolas 9 pt tema oscuro' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-1' 'terminal' '$ ls -la /var/log/app' @{
            Text = '$ ls -la /var/log/app'; Font = 'Consolas'; Size = 9; Unit = 'pt'
            Fg = '204,204,204'; Bg = '12,12,12'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }
    }

    It 'AC7: muestra-2 terminal Consolas 10 pt tema oscuro' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-2' 'terminal' '$ cd /srv/demo && make test' @{
            Text = '$ cd /srv/demo && make test'; Font = 'Consolas'; Size = 10; Unit = 'pt'
            Fg = '204,204,204'; Bg = '12,12,12'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }
    }

    It 'AC7: muestra-3 terminal Consolas 12 pt tema oscuro' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-3' 'terminal' '> npm run build --silent' @{
            Text = '> npm run build --silent'; Font = 'Consolas'; Size = 12; Unit = 'pt'
            Fg = '204,204,204'; Bg = '12,12,12'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }
    }

    It 'AC7: muestra-4 terminal Consolas 9 pt tema claro' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-4' 'terminal' '$ grep -c error /var/log/app.log' @{
            Text = '$ grep -c error /var/log/app.log'; Font = 'Consolas'; Size = 9; Unit = 'pt'
            Fg = '30,30,30'; Bg = '255,255,255'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }
    }

    It 'AC7: muestra-5 terminal Consolas 12 pt tema claro' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-5' 'terminal' '$ echo listo > /tmp/salida.txt' @{
            Text = '$ echo listo > /tmp/salida.txt'; Font = 'Consolas'; Size = 12; Unit = 'pt'
            Fg = '30,30,30'; Bg = '255,255,255'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }
    }

    It 'AC7: muestra-6 dialogo Segoe UI 9 pt fondo gris' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-6' 'diálogo' 'Desea guardar los cambios antes de salir?' @{
            Text = 'Desea guardar los cambios antes de salir?'; Font = 'Segoe UI'; Size = 9; Unit = 'pt'
            Fg = '0,0,0'; Bg = '240,240,240'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }
    }

    It 'AC7: muestra-7 texto pequeno Segoe UI 9 pt y umbrales resultantes' {
        Skip-UnlessWindows
        $null = Invoke-Muestra 'muestra-7' 'texto pequeño' 'Ultima actualizacion: version 2.4.1 estable' @{
            Text = 'Ultima actualizacion: version 2.4.1 estable'; Font = 'Segoe UI'; Size = 9; Unit = 'pt'
            Fg = '0,0,0'; Bg = '255,255,255'; Hint = 'ClearTypeGridFit'; X = 20; Y = 12 }

        $todas = @($script:Muestras)
        $minChars = [int](($todas | Measure-Object -Property Chars -Minimum).Minimum)
        $maxRaros = [int](($todas | Measure-Object -Property Raros -Maximum).Maximum)
        $umbralChars = [int][math]::Floor($minChars / 2)
        $umbralRaros = [int][math]::Min(100, $maxRaros * 2 + 10)
        Write-Host ('umbral_min_chars: {0}' -f $umbralChars)
        Write-Host ('umbral_max_raros_pct: {0}' -f $umbralRaros)
        foreach ($m in $todas) { Write-Host ('# {0} similitud con lo esperado: {1} por ciento' -f $m.Id, $m.Sim) }
        Write-Host ('# terminal correctas (contiene el esperado): {0} de 5' -f @($todas | Where-Object { $_.Tipo -eq 'terminal' -and $_.Correcta }).Count)
    }

    It 'AC5: -OutFile escribe el mismo JSON que stdout bajo output/eyes/<run>/' {
        Skip-UnlessWindows
        $root = New-OcrRepo
        $id = New-RunId
        $dir = Join-Path $root "output\eyes\$id"
        $png = Join-Path $dir 'captura.png'
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $out = Join-Path $dir 'ocr.json'
        $o = Invoke-Ocr @('-Image', $png, '-Lang', 'es-MX', '-OutFile', $out, '-ProjectRoot', $root)
        $o.Exit | Should Be 0
        (Test-Path -LiteralPath $out) | Should Be $true
        $bytes = [IO.File]::ReadAllBytes($out)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should Be $false
        $fileText = [Text.Encoding]::UTF8.GetString($bytes).Trim()
        $fileText | Should Be $o.Raw
        ($fileText | ConvertFrom-Json).engine | Should Be 'windows-media-ocr'
    }

    It 'AC5: -OutFile fuera de output/eyes/<run>/ termina en exit 2 y no escribe nada' {
        Skip-UnlessWindows
        $root = New-OcrRepo
        $id = New-RunId
        $png = Join-Path $root "output\eyes\$id\captura.png"
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $fuera = Join-Path $root 'otro\ocr.json'
        $o = Invoke-Ocr @('-Image', $png, '-OutFile', $fuera, '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath $fuera) | Should Be $false
        (Test-Path -LiteralPath (Join-Path $root 'otro')) | Should Be $false
        $raiz = Join-Path $root 'output\eyes\ocr.json'
        $o2 = Invoke-Ocr @('-Image', $png, '-OutFile', $raiz, '-ProjectRoot', $root)
        $o2.Exit | Should Be 2
        (Test-Path -LiteralPath $raiz) | Should Be $false
    }

    It 'AC5: -OutFile con ".." que escapa del run termina en exit 2 y no escribe nada' {
        Skip-UnlessWindows
        $root = New-OcrRepo
        $id = New-RunId
        $png = Join-Path $root "output\eyes\$id\captura.png"
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $escape = Join-Path $root "output\eyes\$id\..\..\ocr.json"
        $o = Invoke-Ocr @('-Image', $png, '-OutFile', $escape, '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        (Test-Path -LiteralPath (Join-Path $root 'output\ocr.json')) | Should Be $false
    }

    It 'AC5: -OutFile con el run convertido en junction termina en exit 2 y no escribe en el destino' {
        Skip-UnlessWindows
        $root = New-OcrRepo
        $target = New-TempDir
        $id = New-RunId
        New-Item -ItemType Directory -Path (Join-Path $root 'output\eyes') -Force | Out-Null
        $link = Join-Path $root "output\eyes\$id"
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        [void]$script:Junctions.Add($link)
        $png = Join-Path $target 'captura.png'
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $o = Invoke-Ocr @('-Image', $png, '-OutFile', (Join-Path $link 'ocr.json'), '-ProjectRoot', $root)
        $o.Exit | Should Be 2
        (Test-Path -LiteralPath (Join-Path $target 'ocr.json')) | Should Be $false
    }

    It 'AC5: -OutFile bajo output/ no ignorado por git termina en exit 5 y no escribe' {
        Skip-UnlessWindows
        $root = New-OcrRepo -SinIgnore
        $id = New-RunId
        $png = Join-Path $root "output\eyes\$id\captura.png"
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $out = Join-Path $root "output\eyes\$id\ocr.json"
        $o = Invoke-Ocr @('-Image', $png, '-OutFile', $out, '-ProjectRoot', $root)
        $o.Exit | Should Be 5
        (Test-Path -LiteralPath $out) | Should Be $false
    }

    It 'AC5: idioma no instalado cae al perfil con lang_fallback true y lang_solicitado' {
        Skip-UnlessWindows
        $root = New-TempDir
        $png = Join-Path $root 'prueba.png'
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $o = Invoke-Ocr @('-Image', $png, '-Lang', 'zu-ZA')
        $o.Exit | Should Be 0
        $o.Json.lang_fallback | Should Be $true
        $o.Json.lang_solicitado | Should Be 'zu-ZA'
        $o.Json.lang | Should Not Be 'zu-ZA'
    }

    It 'AC5: -Lang con formato invalido termina en exit 2' {
        Skip-UnlessWindows
        $root = New-TempDir
        $png = Join-Path $root 'prueba.png'
        New-SynthPng -Path $png -Text 'Prueba OCR 123' -W 600 -H 120
        $o = Invoke-Ocr @('-Image', $png, '-Lang', 'es MX; calc')
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
    }
}
