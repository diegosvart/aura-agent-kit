# install.ps1 — Aura Agent Kit installer (Windows / PowerShell)
#
# Instala el harness en el proyecto actual como submodule en .aura/
# Uso: pwsh -File path/to/install.ps1 [desde la raiz del proyecto destino]
#
# Comportamiento:
#   - Si .aura/ no existe: git submodule add
#   - Detecta CLAUDE.md existente: append-only con marcadores <!-- aura:begin/end -->
#   - Copia hooks a .claude/hooks/
#   - No sobreescribe nada sin preguntar

$AURA_REPO = "https://github.com/diegosvart/aura-agent-kit.git"
$AURA_DIR  = ".aura"
$MARKER_BEGIN = "<!-- aura:begin -->"
$MARKER_END   = "<!-- aura:end -->"

Write-Host "`n=== Aura Agent Kit — Instalador ===" -ForegroundColor Cyan

# Verificar que estamos en un repo git
if (-not (Test-Path ".git")) {
    Write-Host "ERROR: No se detectó un repositorio git. Ejecutar desde la raiz del proyecto." -ForegroundColor Red
    exit 1
}

# Paso 1 — Submodule
Write-Host "`n[1/4] Verificando submodule..." -ForegroundColor Yellow

if (Test-Path $AURA_DIR) {
    Write-Host "  .aura/ ya existe — omitiendo git submodule add." -ForegroundColor Gray
} else {
    Write-Host "  Agregando submodule en .aura/ ..."
    git submodule add $AURA_REPO $AURA_DIR
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Falló git submodule add." -ForegroundColor Red
        exit 1
    }
    git submodule update --init --recursive
    Write-Host "  Submodule agregado correctamente." -ForegroundColor Green
}

# Paso 2 — CLAUDE.md
Write-Host "`n[2/4] Configurando CLAUDE.md..." -ForegroundColor Yellow

$aura_notice = "> Este repo usa el harness Aura via submodulo ``.aura/``. Si ``.aura/CLAUDE.md`` no resuelve`n> (aparece vacio o inexistente), el submodulo no esta inicializado - correr`n> ``git submodule update --init .aura`` es el PRIMER paso obligatorio de cualquier sesion en`n> este repo, antes de cualquier otra accion. Omitirlo desperdicia el resto de la sesion`n> operando sin protocolo, sin que se note (ver Issue #200)."
$claude_entry = "$MARKER_BEGIN`n$aura_notice`n@.aura/CLAUDE.md`n$MARKER_END"

if (Test-Path "CLAUDE.md") {
    $content = Get-Content "CLAUDE.md" -Raw
    if ($content -match [regex]::Escape($MARKER_BEGIN)) {
        Write-Host "  CLAUDE.md ya contiene bloque aura — omitiendo." -ForegroundColor Gray
    } else {
        Write-Host "  CLAUDE.md existente detectado — haciendo append con marcadores."
        Add-Content "CLAUDE.md" "`n$claude_entry"
        Write-Host "  Bloque aura agregado al final de CLAUDE.md." -ForegroundColor Green
    }
} else {
    Write-Host "  Creando CLAUDE.md con entry point aura..."
    Set-Content "CLAUDE.md" $claude_entry
    Write-Host "  CLAUDE.md creado." -ForegroundColor Green
}

# Paso 3 — Hooks
Write-Host "`n[3/4] Copiando hooks..." -ForegroundColor Yellow

$hooks_src = Join-Path $AURA_DIR ".claude\hooks"
$hooks_dst = ".claude\hooks"

if (-not (Test-Path $hooks_src)) {
    Write-Host "  WARN: No se encontraron hooks en .aura/.claude/hooks/ — omitiendo." -ForegroundColor DarkYellow
} else {
    New-Item -ItemType Directory -Force -Path $hooks_dst | Out-Null
    $hooks = Get-ChildItem $hooks_src -Filter "*.ps1"

    foreach ($hook in $hooks) {
        $dst_file = Join-Path $hooks_dst $hook.Name
        if (Test-Path $dst_file) {
            Write-Host "  $($hook.Name) ya existe — omitiendo (no sobreescribe)." -ForegroundColor Gray
        } else {
            Copy-Item $hook.FullName $dst_file
            Write-Host "  Copiado: $($hook.Name)" -ForegroundColor Green
        }
    }
}

# Paso 4 — Verificación post-instalación
Write-Host "`n[4/4] Verificando instalación..." -ForegroundColor Yellow

# Intentar ejecutar verify-install.sh via bash si está disponible
$verify_script = Join-Path "skills" "harness-update" "scripts" "verify-install.sh"

if ((Get-Command bash -ErrorAction SilentlyContinue) -and (Test-Path $verify_script)) {
    # Bash disponible y script existe — ejecutar via bash
    Write-Host "  Ejecutando verificación (bash)..."
    & bash $verify_script
    $verify_exit = $LASTEXITCODE
} else {
    # Fallback: verificación simplificada en PowerShell nativo
    Write-Host "  Ejecutando verificación (PowerShell)..."

    $verify_exit = 0
    $hooks_found = 0

    # Verificar hooks referenciados en .claude/settings.json
    if (Test-Path ".claude/settings.json") {
        $settings_content = Get-Content ".claude/settings.json" -Raw

        # Buscar referencias a hooks (patrón simple: "command": "...path/hook...")
        $hook_matches = [regex]::Matches($settings_content, '"command"\s*:\s*"([^"]*)"')

        foreach ($match in $hook_matches) {
            $cmd = $match.Groups[1].Value

            # Extraer ruta si contiene .claude/hooks/
            if ($cmd -match '\.claude/hooks/[^ "]+\.(ps1|sh)') {
                $hook_path = $matches[0]

                if (-not (Test-Path $hook_path)) {
                    Write-Host "  MISSING_FILE: $hook_path" -ForegroundColor Red
                    $verify_exit = 1
                } else {
                    # No verificamos git tracking en fallback (requeriría git command)
                }
            }
        }
    }
}

if ($verify_exit -eq 0) {
    Write-Host "  Verificación completada: OK" -ForegroundColor Green
} else {
    Write-Host "  Advertencia: Algunos archivos pueden no estar correctamente configurados." -ForegroundColor DarkYellow
    Write-Host "  Ejecutar: bash skills/harness-update/scripts/verify-install.sh" -ForegroundColor DarkYellow
}

# Instrucciones finales
Write-Host "`n=== Instalación completa ===" -ForegroundColor Cyan
Write-Host @"

Próximos pasos:
  1. Agregar hooks a .claude/settings.json (ver .aura/QUICKSTART.md Paso 3)
  2. Personalizar identidad en AGENTS.local.md EN LA RAIZ DEL PROYECTO (no dentro de .aura/) — ver .aura/AGENTS.local.example.md
  3. Iniciar sesión: claude .

"@ -ForegroundColor White
