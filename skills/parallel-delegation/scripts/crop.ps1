# crop.ps1 - recorta un PNG a un bbox (Issue #402, A1). Solo Windows, PowerShell 5.1.
#
# El recorte se escribe como <nombre-origen>-crop.png junto a la imagen de origen. Con
# -DeleteSource la imagen de origen debe estar bajo <raíz>/output/eyes/ sin ningún componente de
# la ruta (desde output) que sea un enlace (junction/symlink); se comprueba antes de escribir o
# borrar nada. Salida: JSON UTF-8 por stdout. Códigos: 0 ok, 2 argumentos/entrada, 4 plataforma,
# 7 E/S.
param(
    [string]$Image,
    [string]$Bbox,
    [switch]$DeleteSource,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'eyes-common.ps1')

function Stop-Eyes {
    param([int]$Code, [string]$Motivo)
    Write-EyesJson ([ordered]@{ ok = $false; motivo = $Motivo })
    exit $Code
}

try {
    if ($env:OS -ne 'Windows_NT') { Stop-Eyes 4 'plataforma: aura:eyes v1 solo funciona en Windows' }

    if ([string]::IsNullOrWhiteSpace($Image)) { Stop-Eyes 2 'argumentos: falta -Image' }
    if ([string]::IsNullOrWhiteSpace($Bbox)) { Stop-Eyes 2 'argumentos: falta -Bbox' }
    try { $rect = Convert-EyesRect -Text $Bbox }
    catch [System.ArgumentException] { Stop-Eyes 2 ('argumentos: -Bbox inválido: ' + $_.Exception.Message) }

    $imagePath = $Image
    if (-not [IO.Path]::IsPathRooted($imagePath)) { $imagePath = Join-Path (Get-Location).ProviderPath $imagePath }
    $full = [IO.Path]::GetFullPath($imagePath)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Stop-Eyes 2 'argumentos: -Image no existe' }

    if ($DeleteSource) {
        try { $root = Resolve-EyesRoot -ProjectRoot $ProjectRoot }
        catch [System.ArgumentException] { Stop-Eyes 2 ('raíz: ' + $_.Exception.Message) }
        $outputDir = [IO.Path]::GetFullPath((Join-Path $root 'output'))
        $eyesPrefix = [IO.Path]::GetFullPath((Join-Path $root 'output\eyes')).TrimEnd('\') + '\'
        if (-not $full.StartsWith($eyesPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-Eyes 2 'delete-source: -Image debe estar bajo <raíz>/output/eyes/ para usar -DeleteSource'
        }
        $cur = $outputDir
        if (Test-EyesLink -Path $cur) {
            Stop-Eyes 2 'delete-source: output es un enlace (junction/symlink); no se borra a través de enlaces'
        }
        $rest = $full.Substring($outputDir.TrimEnd('\').Length + 1)
        foreach ($part in ($rest -split '\\')) {
            if (-not $part) { continue }
            $cur = Join-Path $cur $part
            if (Test-EyesLink -Path $cur) {
                Stop-Eyes 2 "delete-source: un componente de la ruta es un enlace (junction/symlink): $part"
            }
        }
    }

    try {
        Add-Type -AssemblyName System.Drawing
    } catch {
        Stop-Eyes 4 ('motor: no se pudo cargar System.Drawing: ' + $_.Exception.Message)
    }

    $bytes = [IO.File]::ReadAllBytes($full)
    $ms = New-Object System.IO.MemoryStream (, $bytes)
    $src = $null
    $dst = $null
    try {
        try { $src = New-Object System.Drawing.Bitmap $ms }
        catch { Stop-Eyes 2 'argumentos: -Image no es una imagen válida' }

        if ($rect.X -lt 0 -or $rect.Y -lt 0 -or ($rect.X + $rect.W) -gt $src.Width -or ($rect.Y + $rect.H) -gt $src.Height) {
            Stop-Eyes 2 "bbox: el rectángulo queda fuera de la imagen ($($src.Width)x$($src.Height))"
        }

        $cropPath = Join-Path (Split-Path -Parent $full) ([IO.Path]::GetFileNameWithoutExtension($full) + '-crop.png')
        $area = New-Object System.Drawing.Rectangle ([int]$rect.X), ([int]$rect.Y), ([int]$rect.W), ([int]$rect.H)
        try {
            $dst = $src.Clone($area, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $dst.Save($cropPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } catch {
            Stop-Eyes 7 ('recorte: no se pudo escribir el PNG: ' + $_.Exception.Message)
        }
        $outW = $dst.Width
        $outH = $dst.Height
    } finally {
        if ($dst) { $dst.Dispose() }
        if ($src) { $src.Dispose() }
        $ms.Dispose()
    }

    if ($DeleteSource) {
        try { [IO.File]::Delete($full) }
        catch { Stop-Eyes 7 ('delete-source: el recorte se escribió pero no se pudo borrar el origen: ' + $_.Exception.Message) }
    }

    Write-EyesJson ([ordered]@{
        ok     = $true
        path   = (ConvertTo-EyesSlashPath $cropPath)
        width  = $outW
        height = $outH
    })
    exit 0
} catch {
    Stop-Eyes 7 ('error: ' + $_.Exception.Message)
}
