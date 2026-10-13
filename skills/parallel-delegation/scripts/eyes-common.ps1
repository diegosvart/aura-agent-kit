# eyes-common.ps1 - libreria dot-source de la serie "ojos" (aura:eyes), Issue #402 (A1).
#
# No se ejecuta sola: los scripts hacen `. (Join-Path $PSScriptRoot 'eyes-common.ps1')`.
# Debe ser valida en PowerShell 5.1 (corre los scripts) y 7 (corre los tests): sin `??`, `?.`,
# ternarios ni `&&`. Solo Windows (P6 declarado). La raiz del proyecto nunca se deduce de la
# ubicacion del script (ver Resolve-EyesRoot).
#
# Clases de excepcion (los scripts las mapean a codigos de salida):
#   System.ArgumentException         argumento invalido, fuera de contencion o enlace   -> exit 2
#   System.InvalidOperationException ruta de salida no ignorada por git (falla cerrada)  -> exit 5
#   System.IO.IOException            no se pudo borrar / error de E/S                    -> exit 7

$script:MaxImageDimension = 10000

function New-EyesArgError {
    param([string]$Message)
    New-Object System.ArgumentException $Message
}

function Invoke-EyesGit {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @GitArgs 2>$null
        $code = $LASTEXITCODE
    } catch {
        $out = $null
        $code = 127
    } finally {
        $ErrorActionPreference = $prev
    }
    [pscustomobject]@{ Code = $code; Output = ((@($out) -join "`n").Trim()) }
}

function Resolve-EyesRoot {
    param([string]$ProjectRoot)
    if ($ProjectRoot) {
        if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
            throw (New-EyesArgError "ProjectRoot no existe: $ProjectRoot")
        }
        $base = (Resolve-Path -LiteralPath $ProjectRoot).ProviderPath
    } else {
        $base = (Get-Location).ProviderPath
    }
    $top = Invoke-EyesGit @('-C', $base, 'rev-parse', '--show-toplevel')
    if ($top.Code -ne 0 -or -not $top.Output) {
        throw (New-EyesArgError "no es un repositorio git: $base")
    }
    $root = $top.Output
    if ($root -match '[\\/]\.aura$') {
        $super = Invoke-EyesGit @('-C', $base, 'rev-parse', '--show-superproject-working-tree')
        if ($super.Code -eq 0 -and $super.Output) { $root = $super.Output }
    }
    [IO.Path]::GetFullPath($root)
}

function New-EyesRunId {
    $ts = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture)
    $hex = [guid]::NewGuid().ToString('N').Substring(0, 4)
    "$ts-$hex"
}

function Test-EyesRunId {
    param($RunId)
    if ($RunId -isnot [string]) { return $false }
    return ($RunId -cmatch '\A[0-9]{8}T[0-9]{6}Z-[0-9a-f]{4}\z')
}

function Get-EyesRunDir {
    param([string]$Root, [string]$RunId)
    if (-not (Test-EyesRunId $RunId)) {
        throw (New-EyesArgError 'RunId invalido (se espera yyyyMMddTHHmmssZ-xxxx, hex en minusculas)')
    }
    if (-not $Root) { $Root = Resolve-EyesRoot }
    $eyes = [IO.Path]::GetFullPath((Join-Path (Join-Path $Root 'output') 'eyes'))
    $dir = [IO.Path]::GetFullPath((Join-Path $eyes $RunId))
    $prefix = $eyes.TrimEnd('\') + '\'
    if (-not $dir.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw (New-EyesArgError 'la carpeta del run queda fuera de output/eyes/')
    }
    $dir
}

function Assert-OutputIgnored {
    param([string]$Root, [string]$Path = 'output/eyes/captura.png')
    if (-not $Root) { $Root = Resolve-EyesRoot }
    $rel = $Path
    if ([IO.Path]::IsPathRooted($Path)) {
        $full = [IO.Path]::GetFullPath($Path)
        $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw (New-Object System.InvalidOperationException "la ruta queda fuera de la raiz: $Path")
        }
        $rel = $full.Substring($prefix.Length)
    }
    $rel = $rel.Replace('\', '/')
    $r = Invoke-EyesGit @('-C', $Root, 'check-ignore', '-q', '--', $rel)
    if ($r.Code -ne 0) {
        throw (New-Object System.InvalidOperationException "la ruta de salida no esta ignorada por git: $rel")
    }
    $true
}

function Convert-EyesRect {
    param([string]$Text)
    if ($Text -notmatch '^\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)\s*,\s*(-?[0-9]+)\s*$') {
        throw (New-EyesArgError 'se esperan cuatro enteros "x,y,w,h"')
    }
    $v = @()
    for ($i = 1; $i -le 4; $i++) {
        $n = 0L
        if (-not [long]::TryParse($Matches[$i], [ref]$n)) {
            throw (New-EyesArgError 'entero fuera de rango')
        }
        $v += $n
    }
    if ($v[2] -le 0 -or $v[3] -le 0) {
        throw (New-EyesArgError 'w y h deben ser mayores que 0')
    }
    [pscustomobject]@{ X = $v[0]; Y = $v[1]; W = $v[2]; H = $v[3] }
}

$script:EyesNativeSource = @'
using System;
using System.Runtime.InteropServices;

public static class EyesNative
{
    [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] private static extern bool IsProcessDPIAware();
    [DllImport("user32.dll")] private static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] private static extern uint GetDpiForSystem();

    public static bool EnableDpiAwareness()
    {
        bool done = false;
        try { done = SetProcessDpiAwarenessContext(new IntPtr(-4)); }
        catch (EntryPointNotFoundException) { }
        if (!done)
        {
            try { SetProcessDPIAware(); } catch (EntryPointNotFoundException) { }
        }
        try { return IsProcessDPIAware(); } catch (EntryPointNotFoundException) { return false; }
    }

    public static uint SystemDpi()
    {
        try { return GetDpiForSystem(); } catch (EntryPointNotFoundException) { return 0; }
    }

    public static bool IsUniform(IntPtr scan0, int stride, int width, int height)
    {
        if (width <= 0 || height <= 0) return true;
        int[] row = new int[width];
        int first = 0;
        bool haveFirst = false;
        for (int y = 0; y < height; y++)
        {
            Marshal.Copy(new IntPtr(scan0.ToInt64() + (long)y * stride), row, 0, width);
            for (int x = 0; x < width; x++)
            {
                int px = row[x] & 0x00FFFFFF;
                if (!haveFirst) { first = px; haveFirst = true; }
                else if (px != first) { return false; }
            }
        }
        return true;
    }
}
'@

function Initialize-EyesNative {
    if ('EyesNative' -as [type]) { return }
    Add-Type -TypeDefinition $script:EyesNativeSource -Language CSharp
}

function Test-EyesImageUniform {
    param($Bitmap)
    Add-Type -AssemblyName System.Drawing
    Initialize-EyesNative
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Bitmap.Width, $Bitmap.Height
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        return [EyesNative]::IsUniform($data.Scan0, $data.Stride, $data.Width, $data.Height)
    } finally {
        $Bitmap.UnlockBits($data)
    }
}

function Test-EyesLink {
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    } catch {
        $e = $_.Exception
        $noExiste = ($e -is [System.Management.Automation.ItemNotFoundException]) -or
            ($e -is [System.IO.FileNotFoundException]) -or
            ($e -is [System.IO.DirectoryNotFoundException]) -or
            ($_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound)
        if ($noExiste) { return $false }
        throw (New-EyesArgError "no se pudo consultar la ruta '$Path': $($e.Message)")
    }
    if ($null -eq $item) { return $false }
    $lt = [string]$item.LinkType
    return ($lt -eq 'Junction' -or $lt -eq 'SymbolicLink')
}

function Assert-EyesNoLinks {
    param([string]$Root)
    foreach ($rel in @('output', 'output\eyes')) {
        if (Test-EyesLink -Path (Join-Path $Root $rel)) {
            throw (New-EyesArgError "$($rel.Replace('\', '/')) es un enlace (junction/symlink): no se purga ni se escribe a traves de enlaces")
        }
    }
}

function New-EyesResult {
    param([string[]]$Purgados = @(), $Omitidos = @())
    [pscustomobject]@{ purgados = @($Purgados); omitidos = @($Omitidos) }
}

function Remove-EyesTree {
    param([string]$Path)
    $di = New-Object System.IO.DirectoryInfo $Path
    foreach ($child in $di.GetFileSystemInfos()) {
        $isReparse = (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
        $isDir = ($child -is [System.IO.DirectoryInfo])
        if ($isReparse -and (Test-EyesLink -Path $child.FullName)) {
            if ($isDir) { [IO.Directory]::Delete($child.FullName) } else { [IO.File]::Delete($child.FullName) }
        } elseif ($isDir) {
            Remove-EyesTree -Path $child.FullName
        } else {
            if (($child.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
                [IO.File]::SetAttributes($child.FullName, [IO.FileAttributes]::Normal)
            }
            [IO.File]::Delete($child.FullName)
        }
    }
    [IO.Directory]::Delete($Path)
}

function Remove-EyesRun {
    param([string]$Root, [string]$RunId)
    if (-not (Test-EyesRunId $RunId)) {
        throw (New-EyesArgError 'RunId invalido (se espera yyyyMMddTHHmmssZ-xxxx, hex en minusculas)')
    }
    if (-not $Root) { $Root = Resolve-EyesRoot }
    Assert-EyesNoLinks -Root $Root
    $dir = Get-EyesRunDir -Root $Root -RunId $RunId
    if (-not (Test-Path -LiteralPath $dir)) { return (New-EyesResult) }
    if (Test-EyesLink -Path $dir) {
        throw (New-EyesArgError "el run $RunId es un enlace (junction/symlink): no se sigue ni se borra")
    }
    try {
        Remove-EyesTree -Path $dir
    } catch {
        throw (New-Object System.IO.IOException ("no se pudo borrar el run ${RunId}: " + $_.Exception.Message), $_.Exception)
    }
    New-EyesResult -Purgados @($RunId)
}

function Invoke-EyesPurge {
    param([string]$Root, [int]$MaxAgeMinutes = 60)
    if (-not $Root) { $Root = Resolve-EyesRoot }
    Assert-EyesNoLinks -Root $Root
    $eyes = Join-Path (Join-Path $Root 'output') 'eyes'
    if (-not (Test-Path -LiteralPath $eyes -PathType Container)) { return (New-EyesResult) }
    $purgados = New-Object System.Collections.ArrayList
    $omitidos = New-Object System.Collections.ArrayList
    $now = [DateTime]::UtcNow
    $style = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    foreach ($d in [IO.Directory]::GetDirectories($eyes)) {
        $name = [IO.Path]::GetFileName($d)
        if (-not (Test-EyesRunId $name)) { continue }
        $ts = [DateTime]::MinValue
        $parsed = [DateTime]::TryParseExact($name.Substring(0, 16), "yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture, $style, [ref]$ts)
        if (-not $parsed) {
            [void]$omitidos.Add([pscustomobject]@{ nombre = $name; motivo = 'marca de tiempo invalida en el nombre' })
            continue
        }
        if (($now - $ts).TotalMinutes -le $MaxAgeMinutes) { continue }
        try {
            [void](Remove-EyesRun -Root $Root -RunId $name)
            [void]$purgados.Add($name)
        } catch {
            [void]$omitidos.Add([pscustomobject]@{ nombre = $name; motivo = $_.Exception.Message })
        }
    }
    New-EyesResult -Purgados @($purgados.ToArray()) -Omitidos @($omitidos.ToArray())
}

function Write-EyesJson {
    param($Object)
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    $json = $Object | ConvertTo-Json -Depth 6 -Compress
    [Console]::Out.WriteLine($json)
}

function ConvertTo-EyesSlashPath {
    param([string]$Path)
    $Path.Replace('\', '/')
}
