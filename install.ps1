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
Write-Host "`n[1/3] Verificando submodule..." -ForegroundColor Yellow

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
Write-Host "`n[2/3] Configurando CLAUDE.md..." -ForegroundColor Yellow

$claude_entry = "$MARKER_BEGIN`n@.aura/CLAUDE.md`n$MARKER_END"

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
Write-Host "`n[3/3] Copiando hooks..." -ForegroundColor Yellow

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

# Instrucciones finales
Write-Host "`n=== Instalación completa ===" -ForegroundColor Cyan
Write-Host @"

Próximos pasos:
  1. Agregar hooks a .claude/settings.json (ver .aura/QUICKSTART.md Paso 3)
  2. Personalizar identidad en AGENTS.local.md EN LA RAIZ DEL PROYECTO (no dentro de .aura/) — ver .aura/AGENTS.local.example.md
  3. Iniciar sesión: claude .

"@ -ForegroundColor White
