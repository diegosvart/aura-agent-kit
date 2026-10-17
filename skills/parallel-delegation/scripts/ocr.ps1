# ocr.ps1 - OCR local de aura:eyes sobre el motor nativo Windows.Media.Ocr (Issue #403, A2).
# Solo Windows, PowerShell 5.1 (los tipos WinRT asincronos se esperan via AsTask). Sin red.
#
# Entrada: -Image (PNG), -Lang (es-MX / en-US; ausente = idioma del perfil), -OutFile (opcional),
# -ProjectRoot. Salida: JSON UTF-8 por stdout (y el mismo JSON en -OutFile). Codigos: 0 ok,
# 2 argumentos/entrada invalida, 4 motor o plataforma no disponible, 5 -OutFile no ignorado por
# git, 7 fallo de E/S o de ejecucion (incluye el tiempo de espera de 60 s por imagen).
#
# -OutFile debe resolver bajo <raiz>/output/eyes/<run-id>/ sin enlaces (junction/symlink); si no,
# exit 2 sin escribir nada. El archivo es UTF-8 sin BOM con el mismo JSON que sale por stdout.
# "chars" es la longitud de "text" (lineas unidas con \n). El motor no entrega confianza por palabra.
param(
    [string]$Image,
    [string]$Lang,
    [string]$OutFile,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'eyes-common.ps1')

$script:WaitMs = 60000

function Write-Out {
    param([string]$Json)
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    [Console]::Out.WriteLine($Json)
}

function Stop-Eyes {
    param([int]$Code, [string]$Motivo)
    Write-Out (([ordered]@{ ok = $false; motivo = $Motivo }) | ConvertTo-Json -Depth 6 -Compress)
    exit $Code
}

function Resolve-OutFilePath {
    param([string]$Path, [string]$Root)
    $abs = $Path
    if (-not [IO.Path]::IsPathRooted($abs)) { $abs = Join-Path (Get-Location).ProviderPath $abs }
    $full = [IO.Path]::GetFullPath($abs)
    $outputDir = [IO.Path]::GetFullPath((Join-Path $Root 'output'))
    $eyesDir = [IO.Path]::GetFullPath((Join-Path $Root 'output\eyes'))
    $prefix = $eyesDir.TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw (New-EyesArgError '-OutFile debe resolver bajo <raíz>/output/eyes/<run-id>/')
    }
    $parts = @($full.Substring($prefix.Length) -split '\\' | Where-Object { $_ })
    if ($parts.Count -lt 2) {
        throw (New-EyesArgError '-OutFile debe ser un archivo dentro de output/eyes/<run-id>/')
    }
    if (-not (Test-EyesRunId $parts[0])) {
        throw (New-EyesArgError '-OutFile: el run-id no es válido (yyyyMMddTHHmmssZ-xxxx, hex en minúsculas)')
    }
    $cur = $outputDir
    foreach ($seg in @('output', 'output\eyes')) {
        if (Test-EyesLink -Path (Join-Path $Root $seg)) {
            throw (New-EyesArgError "-OutFile: $($seg.Replace('\', '/')) es un enlace (junction/symlink)")
        }
    }
    $cur = $eyesDir
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $cur = Join-Path $cur $parts[$i]
        if ($i -lt ($parts.Count - 1)) {
            if (-not (Test-Path -LiteralPath $cur -PathType Container)) {
                throw (New-EyesArgError '-OutFile: la carpeta de destino no existe (el run debe estar capturado)')
            }
        }
        if (Test-EyesLink -Path $cur) {
            throw (New-EyesArgError "-OutFile: un componente de la ruta es un enlace (junction/symlink): $($parts[$i])")
        }
    }
    $full
}

function Wait-WinRt {
    param($Operation, [Type]$ResultType)
    $task = $script:AsTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    if (-not $task.Wait($script:WaitMs)) {
        throw (New-Object System.TimeoutException "el OCR superó el tiempo de espera de $($script:WaitMs / 1000) s")
    }
    $task.Result
}

try {
    if ($env:OS -ne 'Windows_NT') { Stop-Eyes 4 'plataforma: aura:eyes v1 solo funciona en Windows' }

    if ([string]::IsNullOrWhiteSpace($Image)) { Stop-Eyes 2 'argumentos: falta -Image' }
    if ($PSBoundParameters.ContainsKey('Lang') -and $Lang -cnotmatch '\A[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}\z') {
        Stop-Eyes 2 'argumentos: -Lang inválido (se espera una etiqueta como es-MX o en-US)'
    }

    $outPath = $null
    if ($PSBoundParameters.ContainsKey('OutFile') -and -not [string]::IsNullOrWhiteSpace($OutFile)) {
        try {
            $root = Resolve-EyesRoot -ProjectRoot $ProjectRoot
            $outPath = Resolve-OutFilePath -Path $OutFile -Root $root
            [void](Assert-OutputIgnored -Root $root -Path $outPath)
        } catch [System.ArgumentException] {
            Stop-Eyes 2 ('outfile: ' + $_.Exception.Message)
        } catch [System.InvalidOperationException] {
            Stop-Eyes 5 ('outfile: ' + $_.Exception.Message)
        }
    }

    $imagePath = $Image
    if (-not [IO.Path]::IsPathRooted($imagePath)) { $imagePath = Join-Path (Get-Location).ProviderPath $imagePath }
    $full = [IO.Path]::GetFullPath($imagePath)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Stop-Eyes 2 'argumentos: -Image no existe' }

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType = WindowsRuntime]
        $null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]
        $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
        $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics, ContentType = WindowsRuntime]
        $script:AsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        } | Select-Object -First 1
        if ($null -eq $script:AsTask) { throw 'no se encontró AsTask para IAsyncOperation' }
    } catch {
        Stop-Eyes 4 ('motor: Windows.Media.Ocr no disponible: ' + $_.Exception.Message)
    }

    $engine = $null
    $fallback = $false
    try {
        if ($Lang) {
            $language = New-Object Windows.Globalization.Language $Lang
            if ([Windows.Media.Ocr.OcrEngine]::IsLanguageSupported($language)) {
                $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
            }
            if ($null -eq $engine) {
                $fallback = $true
                $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
            }
        } else {
            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
        }
    } catch {
        Stop-Eyes 4 ('motor: no se pudo crear el motor OCR: ' + $_.Exception.Message)
    }
    if ($null -eq $engine) { Stop-Eyes 4 'motor: no hay ningún idioma OCR disponible en el equipo' }
    $langUsed = [string]$engine.RecognizerLanguage.LanguageTag

    $bytes = [IO.File]::ReadAllBytes($full)
    $ms = New-Object System.IO.MemoryStream (, $bytes)
    $bitmap = $null
    try {
        $stream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($ms)
        try {
            $decoder = Wait-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        } catch [System.TimeoutException] {
            throw
        } catch {
            Stop-Eyes 2 'argumentos: -Image no es una imagen válida'
        }
        $max = [int][Windows.Media.Ocr.OcrEngine]::MaxImageDimension
        if ([int]$decoder.PixelWidth -gt $max -or [int]$decoder.PixelHeight -gt $max) {
            Stop-Eyes 2 "argumentos: la imagen ($($decoder.PixelWidth)x$($decoder.PixelHeight)) supera MaxImageDimension ($max px)"
        }
        $bitmap = Wait-WinRt ($decoder.GetSoftwareBitmapAsync([Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8, [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied)) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $ocr = Wait-WinRt ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    } catch [System.TimeoutException] {
        Stop-Eyes 7 ('ocr: ' + $_.Exception.Message)
    } catch {
        $e = $_.Exception
        if ($e -is [System.AggregateException] -and $e.InnerException) { $e = $e.InnerException }
        Stop-Eyes 7 ('ocr: falló el reconocimiento: ' + $e.Message)
    } finally {
        if ($bitmap) { $bitmap.Dispose() }
        $ms.Dispose()
    }

    $lines = New-Object System.Collections.ArrayList
    $texts = New-Object System.Collections.ArrayList
    foreach ($line in $ocr.Lines) {
        $minX = [double]::MaxValue; $minY = [double]::MaxValue
        $maxX = 0.0; $maxY = 0.0
        $any = $false
        foreach ($w in $line.Words) {
            $r = $w.BoundingRect
            $any = $true
            if ($r.X -lt $minX) { $minX = $r.X }
            if ($r.Y -lt $minY) { $minY = $r.Y }
            if (($r.X + $r.Width) -gt $maxX) { $maxX = $r.X + $r.Width }
            if (($r.Y + $r.Height) -gt $maxY) { $maxY = $r.Y + $r.Height }
        }
        $bbox = @(0, 0, 0, 0)
        if ($any) {
            $x0 = [int][math]::Floor($minX); $y0 = [int][math]::Floor($minY)
            $bbox = @($x0, $y0, ([int][math]::Ceiling($maxX) - $x0), ([int][math]::Ceiling($maxY) - $y0))
        }
        [void]$texts.Add([string]$line.Text)
        [void]$lines.Add([ordered]@{ text = [string]$line.Text; bbox = [int[]]$bbox })
    }
    $text = ($texts.ToArray() -join "`n")

    $result = [ordered]@{
        ok              = $true
        engine          = 'windows-media-ocr'
        lang            = $langUsed
        lang_solicitado = $(if ($Lang) { $Lang } else { $null })
        lang_fallback   = $fallback
        chars           = $text.Length
        text            = $text
        lines           = [object[]]$lines.ToArray()
    }
    $json = $result | ConvertTo-Json -Depth 6 -Compress

    if ($outPath) {
        try {
            [IO.File]::WriteAllText($outPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch {
            Stop-Eyes 7 ('outfile: no se pudo escribir: ' + $_.Exception.Message)
        }
    }
    Write-Out $json
    exit 0
} catch {
    Stop-Eyes 7 ('error: ' + $_.Exception.Message)
}
