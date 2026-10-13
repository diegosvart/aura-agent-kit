# capture.Tests.ps1 - Pester 3.4.0, corre en pwsh 7 e invoca capture.ps1 con powershell.exe 5.1
# (Issue #402, A1). Cubre AC2 (contrato sin fotografiar, 18 casos) y AC3 (captura real, 3 casos,
# opt-in con EYES_TEST_CAPTURE=1).
#
# Solo contenido sintetico: la ventana de prueba pinta franjas blancas y negras generadas aqui; los
# PNG se escriben bajo una carpeta temporal y se borran. Nunca se versiona ni se pega una captura.

$script:Capture = Join-Path $PSScriptRoot 'capture.ps1'
$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:TempItems = New-Object System.Collections.ArrayList
$script:Junctions = New-Object System.Collections.ArrayList

function Skip-UnlessWindows {
    if (-not $script:IsWin) { Set-TestInconclusive -Message 'SKIP: el SO no es Windows' }
}

function Skip-UnlessCapture {
    Skip-UnlessWindows
    if (-not $env:EYES_TEST_CAPTURE) { Set-TestInconclusive -Message 'SKIP: EYES_TEST_CAPTURE no definido' }
}

function New-TempDir {
    $p = Join-Path ([IO.Path]::GetTempPath()) ('eyes-c-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
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

function Write-Utf8 {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($true)))
}

function New-CaptureRepo {
    param(
        [string]$Classification = '{"repo_type":"harness"}',
        [bool]$IgnoreOutput = $true,
        [string]$PlanLine = 'Capturas de pantalla: pantalla completa - prueba',
        [string]$PlanStatus = 'approved'
    )
    $d = New-TempDir
    git -C $d init -q 2>$null | Out-Null
    git -C $d config user.email 'test@example.invalid' | Out-Null
    git -C $d config user.name 'test' | Out-Null
    if ($IgnoreOutput) { Write-Utf8 (Join-Path $d '.gitignore') "output/`n" }
    if ($null -ne $Classification) {
        Write-Utf8 (Join-Path $d '.agent\memory\repo-classification.json') $Classification
    }
    $planText = "---`nstatus: $PlanStatus`n---`n# Plan sintetico`n"
    if ($PlanLine) { $planText += "$PlanLine`n" }
    Write-Utf8 (Join-Path $d '.agent\memory\plans\2026-10-12-prueba.md') $planText
    [pscustomobject]@{ Root = $d; Plan = '.agent/memory/plans/2026-10-12-prueba.md' }
}

function Invoke-Capture {
    param([string[]]$ScriptArgs)
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
    $raw = & powershell.exe -NoProfile -File $script:Capture @ScriptArgs 2>$null
    $code = $LASTEXITCODE
    $text = ($raw | Out-String).Trim()
    $json = $null
    try { $json = $text | ConvertFrom-Json } catch { }
    [pscustomobject]@{ Exit = $code; Raw = $text; Json = $json }
}

function New-RunIdAgo {
    param([int]$Minutes, [string]$Suffix = 'ab12')
    $ts = (Get-Date).ToUniversalTime().AddMinutes(-$Minutes)
    $ts.ToString("yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture) + '-' + $Suffix
}

function New-OldRun {
    param([string]$Root, [string]$RunId)
    $d = Join-Path (Join-Path (Join-Path $Root 'output') 'eyes') $RunId
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $d 'captura.txt') -Value 'sintetico'
    $d
}

Describe 'capture.ps1 - contrato sin fotografiar (AC2)' {

    It 'sin -AvisoDado termina en exit 2 con ok:false y motivo' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        $o = Invoke-Capture @('-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        Clear-TempItems
    }

    It '-AvisoDado con ruta inexistente termina en exit 2' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        $o = Invoke-Capture @('-AvisoDado', '.agent/memory/plans/no-existe.md', '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        Clear-TempItems
    }

    It 'plan sin linea "Capturas de pantalla:" termina en exit 2' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -PlanLine ''
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        Clear-TempItems
    }

    It 'plan con status distinto de approved y done termina en exit 2' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -PlanStatus 'draft'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        Clear-TempItems
    }

    It 'plan fuera de .agent/memory/plans/ termina en exit 2' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        Write-Utf8 (Join-Path $r.Root 'plan-fuera.md') "---`nstatus: approved`n---`nCapturas de pantalla: pantalla completa - x`n"
        $o = Invoke-Capture @('-AvisoDado', 'plan-fuera.md', '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        Clear-TempItems
    }

    It '-Region 0,0,0,10 (ancho cero) termina en exit 2' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-Region', '0,0,0,10', '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        Clear-TempItems
    }

    It '-Region fuera de la pantalla virtual termina en exit 2 habiendo purgado ya los runs antiguos' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        $viejoId = New-RunIdAgo -Minutes 61
        $viejo = New-OldRun -Root $r.Root -RunId $viejoId
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-Region', '100000,100000,10,10', '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        [string]::IsNullOrWhiteSpace($o.Json.motivo) | Should Be $false
        (Test-Path -LiteralPath $viejo) | Should Be $false
        Clear-TempItems
    }

    It 'repo con output/ no ignorado y plan valido termina en exit 5 y no crea output/eyes' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -IgnoreOutput $false
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 5
        $o.Json.ok | Should Be $false
        (Test-Path -LiteralPath (Join-Path $r.Root 'output\eyes')) | Should Be $false
        Clear-TempItems
    }

    It 'alcance region del plan sin -Region termina en exit 2 con motivo alcance: (sin mojibake)' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -PlanLine ('Capturas de pantalla: regi' + [char]0x00F3 + 'n - prueba')
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        $o.Json.motivo.StartsWith('alcance:') | Should Be $true
        $o.Json.motivo.Contains('regi' + [char]0x00F3 + 'n') | Should Be $true
        $o.Json.motivo.Contains([string][char]0x00C3) | Should Be $false
        Clear-TempItems
    }

    It 'alcance ventana (reservado a v1.1) termina en exit 2 con motivo alcance:' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -PlanLine 'Capturas de pantalla: ventana - prueba'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.motivo.StartsWith('alcance:') | Should Be $true
        Clear-TempItems
    }

    It 'alcance no reconocido (todo) termina en exit 2 con motivo alcance:' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -PlanLine 'Capturas de pantalla: todo - prueba'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.motivo.StartsWith('alcance:') | Should Be $true
        Clear-TempItems
    }

    It 'repo_type cliente sin -Region termina en exit 2 con motivo clasificacion: aun con plan pantalla completa' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -Classification '{"repo_type":"cliente"}'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        $o.Json.motivo.StartsWith('clasificacion:') | Should Be $true
        Clear-TempItems
    }

    It 'repo-classification.json ausente sin -Region termina en exit 2 con motivo clasificacion:' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -Classification $null
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.motivo.StartsWith('clasificacion:') | Should Be $true
        Clear-TempItems
    }

    It 'repo-classification.json corrupto sin -Region termina en exit 2 con motivo clasificacion:' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -Classification '{"repo_type": '
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.motivo.StartsWith('clasificacion:') | Should Be $true
        Clear-TempItems
    }

    It 'repo_type vacio sin -Region termina en exit 2 con motivo clasificacion:' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -Classification '{"repo_type":""}'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.motivo.StartsWith('clasificacion:') | Should Be $true
        Clear-TempItems
    }

    It 'repo_type invalido sin -Region termina en exit 2 con motivo clasificacion:' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -Classification '{"repo_type":"otro"}'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.motivo.StartsWith('clasificacion:') | Should Be $true
        Clear-TempItems
    }

    It 'repo_type cliente CON -Region valida y output/ no ignorado llega al gitignore (exit 5)' {
        Skip-UnlessWindows
        $r = New-CaptureRepo -Classification '{"repo_type":"cliente"}' -IgnoreOutput $false `
            -PlanLine ('Capturas de pantalla: regi' + [char]0x00F3 + 'n - prueba')
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-Region', '0,0,10,10', '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 5
        $o.Json.ok | Should Be $false
        Clear-TempItems
    }

    It 'output/eyes convertido en junction: exit 2 con motivo purga:, sin capturar y centinela intacto' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        New-Item -ItemType Directory -Path (Join-Path $r.Root 'output') | Out-Null
        $target = New-TempDir
        $sentinel = Join-Path $target 'centinela.txt'
        Set-Content -LiteralPath $sentinel -Value 'no me borres'
        $link = Join-Path $r.Root 'output\eyes'
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        [void]$script:Junctions.Add($link)
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        $o.Json.motivo.StartsWith('purga:') | Should Be $true
        (Test-Path -LiteralPath $sentinel) | Should Be $true
        @(Get-ChildItem -LiteralPath $target -Force).Count | Should Be 1
        Clear-TempItems
    }
}

Describe 'capture.ps1 - rechazo de runs enlace o preexistentes (review MAYOR 1)' {

    AfterEach { Clear-TempItems }

    It '-RunId que apunta a una junction preexistente: exit 2 con motivo enlace:, sin PNG y centinela intacto' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        $id = New-RunIdAgo -Minutes 5 -Suffix 'cd34'
        New-Item -ItemType Directory -Path (Join-Path $r.Root 'output\eyes') -Force | Out-Null
        $target = New-TempDir
        $sentinel = Join-Path $target 'centinela.txt'
        Set-Content -LiteralPath $sentinel -Value 'no me borres'
        $link = Join-Path $r.Root "output\eyes\$id"
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        [void]$script:Junctions.Add($link)
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-RunId', $id, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        $o.Json.motivo.StartsWith('enlace:') | Should Be $true
        (Test-Path -LiteralPath $sentinel) | Should Be $true
        @(Get-ChildItem -LiteralPath $target -Force).Count | Should Be 1
        Clear-TempItems
    }

    It '-RunId de un run ya existente: exit 2 con motivo run: y el contenido previo queda intacto' {
        Skip-UnlessWindows
        $r = New-CaptureRepo
        $id = New-RunIdAgo -Minutes 5 -Suffix 'ef56'
        $dir = New-OldRun -Root $r.Root -RunId $id
        $previo = Join-Path $dir 'captura.png'
        Set-Content -LiteralPath $previo -Value 'contenido previo'
        $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-RunId', $id, '-ProjectRoot', $r.Root)
        $o.Exit | Should Be 2
        $o.Json.ok | Should Be $false
        $o.Json.motivo.StartsWith('run:') | Should Be $true
        (Get-Content -LiteralPath $previo -Raw).Trim() | Should Be 'contenido previo'
        (Test-Path -LiteralPath (Join-Path $dir 'captura.txt')) | Should Be $true
        Clear-TempItems
    }
}

function Start-TestWindow {
    $dir = New-TempDir
    $title = 'EYES-TEST-' + [guid]::NewGuid().ToString('N').Substring(0, 4)
    $ready = Join-Path $dir 'ready.txt'
    $stop = Join-Path $dir 'stop.txt'
    $childScript = Join-Path $dir 'ventana.ps1'
    $code = @'
param([string]$ReadyFile, [string]$StopFile, [string]$Title)
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class EyesTestDpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value); public static void Enable() { bool ok = false; try { ok = SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch (EntryPointNotFoundException) { } if (!ok) { SetProcessDPIAware(); } } }'
[EyesTestDpi]::Enable()
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap 200, 200
$g = [System.Drawing.Graphics]::FromImage($bmp)
for ($i = 0; $i -lt 10; $i++) {
    $color = if ($i % 2 -eq 0) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black }
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillRectangle($brush, 0, $i * 20, 200, 20)
    $brush.Dispose()
}
$g.Dispose()
$f = New-Object System.Windows.Forms.Form
$f.Text = $Title
$f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$f.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$f.ShowInTaskbar = $false
$f.TopMost = $true
$f.Size = New-Object System.Drawing.Size 200, 200
$f.Location = New-Object System.Drawing.Point ($vs.Left + 100), ($vs.Top + 100)
$f.BackgroundImage = $bmp
$f.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::None
$f.Show()
$sw = [Diagnostics.Stopwatch]::StartNew()
$signaled = $false
while (-not (Test-Path -LiteralPath $StopFile) -and $sw.Elapsed.TotalSeconds -lt 120) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 40
    if (-not $signaled -and $sw.ElapsedMilliseconds -gt 800) {
        Set-Content -LiteralPath $ReadyFile -Value 'ready'
        $signaled = $true
    }
}
$f.Close()
'@
    Set-Content -LiteralPath $childScript -Value $code -Encoding UTF8
    $p = Start-Process -FilePath 'powershell.exe' -PassThru -WindowStyle Hidden `
        -ArgumentList @('-NoProfile', '-File', $childScript, '-ReadyFile', $ready, '-StopFile', $stop, '-Title', $title)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $ready) -and $sw.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 500
    [pscustomobject]@{ Pid = $p.Id; Dir = $dir; Ready = (Test-Path -LiteralPath $ready) }
}

function Stop-TestWindow {
    param($Window)
    try { Stop-Process -Id $Window.Pid -Force -ErrorAction SilentlyContinue } catch { }
}

Describe 'capture.ps1 - captura real opt-in (AC3, EYES_TEST_CAPTURE=1)' {

    It 'AC3-1: -Region 100,100,200,200 captura la ventana de prueba como PNG de 200x200' {
        Skip-UnlessCapture
        $win = Start-TestWindow
        try {
            $win.Ready | Should Be $true
            $r = New-CaptureRepo -PlanLine ('Capturas de pantalla: regi' + [char]0x00F3 + 'n - prueba')
            $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-Region', '100,100,200,200', '-ProjectRoot', $r.Root)
            $o.Exit | Should Be 0
            $o.Json.ok | Should Be $true
            $o.Json.width | Should Be 200
            $o.Json.height | Should Be 200
            $o.Json.dpi_aware | Should Be $true
            $o.Json.alcance | Should Be ('regi' + [char]0x00F3 + 'n')
            $png = $o.Json.path
            (Test-Path -LiteralPath $png) | Should Be $true
            $runDir = Join-Path (Join-Path $r.Root 'output\eyes') $o.Json.run_id
            ([IO.Path]::GetFullPath($png)).StartsWith($runDir, [StringComparison]::OrdinalIgnoreCase) | Should Be $true
            $bytes = [IO.File]::ReadAllBytes($png)
            ($bytes[0..3] -join ',') | Should Be '137,80,78,71'

            Add-Type -AssemblyName System.Drawing
            $ms = New-Object IO.MemoryStream (, $bytes)
            $img = New-Object System.Drawing.Bitmap $ms
            try {
                $img.GetPixel(100, 10).R | Should BeGreaterThan 200
                $img.GetPixel(100, 30).R | Should BeLessThan 60
            } finally { $img.Dispose(); $ms.Dispose() }

            Remove-Item -LiteralPath $runDir -Recurse -Force
            (Test-Path -LiteralPath $runDir) | Should Be $false
        } finally {
            Stop-TestWindow $win
            Clear-TempItems
        }
    }

    It 'AC3-2: la purga integrada borra el run de 61 minutos y conserva el de 59' {
        Skip-UnlessCapture
        $win = Start-TestWindow
        try {
            $r = New-CaptureRepo -PlanLine ('Capturas de pantalla: regi' + [char]0x00F3 + 'n - prueba')
            $idViejo = New-RunIdAgo -Minutes 61 -Suffix 'aaaa'
            $idNuevo = New-RunIdAgo -Minutes 59 -Suffix 'bbbb'
            $viejo = New-OldRun -Root $r.Root -RunId $idViejo
            $reciente = New-OldRun -Root $r.Root -RunId $idNuevo
            $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-Region', '100,100,200,200', '-ProjectRoot', $r.Root)
            $o.Exit | Should Be 0
            $o.Json.ok | Should Be $true
            (Test-Path -LiteralPath $viejo) | Should Be $false
            (@($o.Json.purgados) -contains $idViejo) | Should Be $true
            (Test-Path -LiteralPath $reciente) | Should Be $true
            (@($o.Json.purgados) -contains $idNuevo) | Should Be $false
        } finally {
            Stop-TestWindow $win
            Clear-TempItems
        }
    }

    It 'AC3-3: sin -Region, repo harness y plan pantalla completa captura la pantalla virtual' {
        Skip-UnlessCapture
        $win = Start-TestWindow
        try {
            $r = New-CaptureRepo
            $o = Invoke-Capture @('-AvisoDado', $r.Plan, '-ProjectRoot', $r.Root)
            $o.Exit | Should Be 0
            $o.Json.ok | Should Be $true
            $o.Json.alcance | Should Be 'pantalla completa'
            $o.Json.width | Should BeGreaterThan 0
            $o.Json.height | Should BeGreaterThan 0
            $runDir = Join-Path (Join-Path $r.Root 'output\eyes') $o.Json.run_id
            Remove-Item -LiteralPath $runDir -Recurse -Force
            (Test-Path -LiteralPath $runDir) | Should Be $false
        } finally {
            Stop-TestWindow $win
            Clear-TempItems
        }
    }
}
