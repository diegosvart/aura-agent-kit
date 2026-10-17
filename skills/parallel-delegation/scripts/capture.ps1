# capture.ps1 - captura de pantalla de aura:eyes (Issue #402, A1). Solo Windows, PowerShell 5.1.
#
# Salida: JSON UTF-8 por stdout, logs por stderr. No usa red. Contrato y orden de validacion en el
# Issue #402: argumentos -> raiz -> clasificacion del repo -> plan (-AvisoDado) -> gitignore (exit 5)
# -> purga de runs de mas de 1 hora -> captura. Ni la captura ni la purga ocurren antes de pasar
# las comprobaciones previas. Codigos: 0 ok, 2 argumentos/entrada, 4 plataforma/motor, 5 ruta no
# ignorada, 7 E/S, 8 captura invalida (vacia o de un solo color).
param(
    [string]$AvisoDado,
    [string]$Region,
    [string]$RunId,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'eyes-common.ps1')

function Stop-Eyes {
    param([int]$Code, [string]$Motivo, $Extra)
    $o = [ordered]@{ ok = $false; motivo = $Motivo }
    if ($Extra) { foreach ($k in $Extra.Keys) { $o[$k] = $Extra[$k] } }
    Write-EyesJson $o
    exit $Code
}

function Get-EyesRepoType {
    param([string]$Root)
    $file = Join-Path $Root '.agent\memory\repo-classification.json'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return $null }
    try {
        $j = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
    if ($null -eq $j) { return $null }
    $t = $j.repo_type
    if ($t -isnot [string]) { return $null }
    if ($t -cmatch '\A(harness|personal|cliente)\z') { return $t }
    return $null
}

function Get-EyesPlanInfo {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $status = $null
    $lines = $text -split "`r?`n"
    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '---') { break }
            if ($lines[$i] -match '^\s*status\s*:\s*(.+?)\s*$') {
                $status = $Matches[1].Trim('"', "'", ' ').ToLowerInvariant()
                break
            }
        }
    }
    $alcance = $null
    $m = [regex]::Match($text, '(?im)^[ \t]*(?:[-*][ \t]+)?Capturas de pantalla[ \t]*:[ \t]*(.*)$')
    if ($m.Success) { $alcance = $m.Groups[1].Value.Trim().ToLowerInvariant() }
    [pscustomobject]@{ Status = $status; Alcance = $alcance }
}

try {
    if ($env:OS -ne 'Windows_NT') { Stop-Eyes 4 'plataforma: aura:eyes v1 solo funciona en Windows' }

    # 1. Argumentos y -Region bien formada (solo sintactico)
    if ([string]::IsNullOrWhiteSpace($AvisoDado)) {
        Stop-Eyes 2 'argumentos: falta -AvisoDado (ruta del plan aprobado, relativa a la raíz)'
    }
    if ($PSBoundParameters.ContainsKey('RunId') -and -not (Test-EyesRunId $RunId)) {
        Stop-Eyes 2 'argumentos: -RunId inválido (se espera yyyyMMddTHHmmssZ-xxxx, hex en minúsculas)'
    }
    $rect = $null
    if ($PSBoundParameters.ContainsKey('Region')) {
        try { $rect = Convert-EyesRect -Text $Region }
        catch [System.ArgumentException] { Stop-Eyes 2 ('argumentos: -Region inválida: ' + $_.Exception.Message) }
    }

    # 2. Raíz
    try { $root = Resolve-EyesRoot -ProjectRoot $ProjectRoot }
    catch [System.ArgumentException] { Stop-Eyes 2 ('raíz: ' + $_.Exception.Message) }

    # 3. Clasificación del repo (fail-closed)
    $repoType = Get-EyesRepoType -Root $root
    $pantallaCompletaPermitida = ($repoType -eq 'harness' -or $repoType -eq 'personal')
    if (-not $pantallaCompletaPermitida -and $null -eq $rect) {
        $detalle = if ($repoType) { "repo_type '$repoType'" } else { 'clasificación ausente, corrupta o inválida' }
        Stop-Eyes 2 "clasificacion: $detalle; la pantalla completa solo se permite en harness o personal, use -Region"
    }

    # 4. Plan (-AvisoDado): ubicación, estado y alcance
    $planPath = $AvisoDado
    if (-not [IO.Path]::IsPathRooted($planPath)) { $planPath = Join-Path $root $planPath }
    $planFull = [IO.Path]::GetFullPath($planPath)
    $plansDir = [IO.Path]::GetFullPath((Join-Path $root '.agent\memory\plans')).TrimEnd('\') + '\'
    if (-not $planFull.StartsWith($plansDir, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Eyes 2 'plan: -AvisoDado debe resolver dentro de .agent/memory/plans/'
    }
    if (-not (Test-Path -LiteralPath $planFull -PathType Leaf)) {
        Stop-Eyes 2 'plan: el archivo indicado en -AvisoDado no existe'
    }
    $plan = Get-EyesPlanInfo -Path $planFull
    if ($plan.Status -ne 'approved' -and $plan.Status -ne 'done') {
        Stop-Eyes 2 'plan: el frontmatter debe tener status: approved o status: done'
    }
    if ($null -eq $plan.Alcance) {
        Stop-Eyes 2 'plan: falta la línea "Capturas de pantalla: <alcance> — <motivo>"'
    }
    $planRegion = $false
    if ($plan.Alcance.StartsWith('pantalla completa')) {
        $planRegion = $false
    } elseif ($plan.Alcance.StartsWith('región') -or $plan.Alcance.StartsWith('region')) {
        $planRegion = $true
    } else {
        Stop-Eyes 2 "alcance: alcance no reconocido en el plan ('$($plan.Alcance)'); v1 solo admite pantalla completa o región"
    }
    if ($planRegion -and $null -eq $rect) {
        Stop-Eyes 2 'alcance: el plan solo autoriza capturas de región y se pidió pantalla completa; use -Region'
    }
    $alcanceCaptura = if ($null -ne $rect) { 'región' } else { 'pantalla completa' }

    # 5. Gitignore (falla cerrada)
    if ($PSBoundParameters.ContainsKey('RunId')) { $runId = $RunId } else { $runId = New-EyesRunId }
    $runDir = Get-EyesRunDir -Root $root -RunId $runId
    $pngPath = Join-Path $runDir 'captura.png'
    try { [void](Assert-OutputIgnored -Root $root -Path $pngPath) }
    catch [System.InvalidOperationException] { Stop-Eyes 5 ('gitignore: ' + $_.Exception.Message) }

    try {
        if (Test-EyesLink -Path $runDir) {
            Stop-Eyes 2 "enlace: la carpeta del run $runId es un enlace (junction/symlink); no se captura a través de enlaces"
        }
    } catch [System.ArgumentException] {
        Stop-Eyes 2 ('enlace: ' + $_.Exception.Message)
    }
    if (Test-Path -LiteralPath $runDir) {
        Stop-Eyes 2 "run: el run $runId ya existe; no se sobrescribe una captura previa"
    }

    # 6. Purga de runs de más de 1 hora
    try { $purga = Invoke-EyesPurge -Root $root }
    catch [System.ArgumentException] { Stop-Eyes 2 ('purga: ' + $_.Exception.Message) }
    catch [System.IO.IOException] { Stop-Eyes 7 ('purga: ' + $_.Exception.Message) }

    # 7. Captura
    try {
        Initialize-EyesNative
        $dpiAware = [EyesNative]::EnableDpiAwareness()
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    } catch {
        Stop-Eyes 4 ('motor: no se pudo preparar la captura: ' + $_.Exception.Message)
    }
    $sysDpi = [EyesNative]::SystemDpi()
    if ($sysDpi -eq 0) {
        $gfx = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
        $sysDpi = $gfx.DpiX
        $gfx.Dispose()
    }
    $dpiScale = [math]::Round($sysDpi / 96.0, 2)
    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $monitors = [System.Windows.Forms.SystemInformation]::MonitorCount

    if ($null -ne $rect) {
        if ($rect.X -lt 0 -or $rect.Y -lt 0 -or ($rect.X + $rect.W) -gt $vs.Width -or ($rect.Y + $rect.H) -gt $vs.Height) {
            Stop-Eyes 2 "región: el rectángulo queda fuera de la pantalla virtual ($($vs.Width)x$($vs.Height))"
        }
        $srcX = [int]($vs.Left + $rect.X); $srcY = [int]($vs.Top + $rect.Y)
        $capW = [int]$rect.W; $capH = [int]$rect.H
    } else {
        if ($vs.Width -le 0 -or $vs.Height -le 0) {
            Stop-Eyes 8 'captura inválida: la pantalla virtual mide 0 (sesión no interactiva o bloqueada)'
        }
        $srcX = [int]$vs.Left; $srcY = [int]$vs.Top
        $capW = [int]$vs.Width; $capH = [int]$vs.Height
    }

    try { [void](New-EyesRunDir -Root $root -RunId $runId) }
    catch [System.ArgumentException] { Stop-Eyes 2 ('run: ' + $_.Exception.Message) }
    $bmp = $null
    $final = $null
    try {
        try {
            $bmp = New-Object System.Drawing.Bitmap $capW, $capH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.CopyFromScreen($srcX, $srcY, 0, 0, (New-Object System.Drawing.Size $capW, $capH), [System.Drawing.CopyPixelOperation]::SourceCopy)
            } finally { $g.Dispose() }
        } catch {
            [void](Remove-EyesRun -Root $root -RunId $runId)
            Stop-Eyes 7 ('captura: fallo de E/S al copiar la pantalla: ' + $_.Exception.Message)
        }

        $final = $bmp
        $scaled = $false
        $maxSide = [math]::Max($capW, $capH)
        if ($maxSide -gt $script:MaxImageDimension) {
            $f = $script:MaxImageDimension / [double]$maxSide
            $nw = [int][math]::Max(1, [math]::Round($capW * $f))
            $nh = [int][math]::Max(1, [math]::Round($capH * $f))
            $small = New-Object System.Drawing.Bitmap $nw, $nh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g2 = [System.Drawing.Graphics]::FromImage($small)
            try {
                $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g2.DrawImage($bmp, 0, 0, $nw, $nh)
            } finally { $g2.Dispose() }
            $final = $small
            $scaled = $true
        }

        if (Test-EyesImageUniform -Bitmap $final) {
            [void](Remove-EyesRun -Root $root -RunId $runId)
            Stop-Eyes 8 'captura inválida: imagen vacía o de un solo color (pantalla bloqueada o sesión remota)'
        }

        try {
            $final.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } catch {
            [void](Remove-EyesRun -Root $root -RunId $runId)
            Stop-Eyes 7 ('captura: no se pudo escribir el PNG: ' + $_.Exception.Message)
        }

        $outW = $final.Width
        $outH = $final.Height
    } finally {
        if ($final -and $final -ne $bmp) { $final.Dispose() }
        if ($bmp) { $bmp.Dispose() }
    }

    Write-EyesJson ([ordered]@{
        ok               = $true
        run_id           = $runId
        path             = (ConvertTo-EyesSlashPath $pngPath)
        width            = $outW
        height           = $outH
        dpi_aware        = [bool]$dpiAware
        dpi_scale        = $dpiScale
        monitors         = [int]$monitors
        scaled           = $scaled
        repo_type        = $repoType
        alcance          = $alcanceCaptura
        purgados         = @($purga.purgados)
        purga_omitidos   = @($purga.omitidos)
    })
    exit 0
} catch {
    Stop-Eyes 7 ('error: ' + $_.Exception.Message)
}
