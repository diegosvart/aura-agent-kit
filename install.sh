#!/usr/bin/env bash
# install.sh — Aura Agent Kit installer (Unix / macOS / Linux)
#
# Instala el harness en el proyecto actual como submodule en .aura/
# Uso: bash path/to/install.sh [desde la raiz del proyecto destino]
#
# Comportamiento:
#   - Si .aura/ no existe: git submodule add
#   - Detecta CLAUDE.md existente: append-only con marcadores <!-- aura:begin/end -->
#   - Copia hooks a .claude/hooks/
#   - No sobreescribe nada sin preguntar

set -euo pipefail

AURA_REPO="https://github.com/diegosvart/aura-agent-kit.git"
AURA_DIR=".aura"
MARKER_BEGIN="<!-- aura:begin -->"
MARKER_END="<!-- aura:end -->"

echo ""
echo "=== Aura Agent Kit — Instalador ==="

# Verificar que estamos en un repo git
if [ ! -d ".git" ]; then
    echo "ERROR: No se detectó un repositorio git. Ejecutar desde la raíz del proyecto."
    exit 1
fi

# Paso 1 — Submodule
echo ""
echo "[1/3] Verificando submodule..."

if [ -d "$AURA_DIR" ]; then
    echo "  .aura/ ya existe — omitiendo git submodule add."
else
    echo "  Agregando submodule en .aura/ ..."
    git submodule add "$AURA_REPO" "$AURA_DIR"
    git submodule update --init --recursive
    echo "  Submodule agregado correctamente."
fi

# Paso 2 — CLAUDE.md
echo ""
echo "[2/3] Configurando CLAUDE.md..."

CLAUDE_ENTRY="${MARKER_BEGIN}
> Este repo usa el harness Aura vía submódulo \`.aura/\`. Si \`.aura/CLAUDE.md\` no resuelve
> (aparece vacío o inexistente), el submódulo no está inicializado — correr
> \`git submodule update --init .aura\` es el PRIMER paso obligatorio de cualquier sesión en
> este repo, antes de cualquier otra acción. Omitirlo desperdicia el resto de la sesión
> operando sin protocolo, sin que se note (ver Issue #200).
@.aura/CLAUDE.md
${MARKER_END}"

if [ -f "CLAUDE.md" ]; then
    if grep -qF "$MARKER_BEGIN" CLAUDE.md; then
        echo "  CLAUDE.md ya contiene bloque aura — omitiendo."
    else
        echo "  CLAUDE.md existente detectado — haciendo append con marcadores."
        printf "\n%s\n" "$CLAUDE_ENTRY" >> CLAUDE.md
        echo "  Bloque aura agregado al final de CLAUDE.md."
    fi
else
    echo "  Creando CLAUDE.md con entry point aura..."
    printf "%s\n" "$CLAUDE_ENTRY" > CLAUDE.md
    echo "  CLAUDE.md creado."
fi

# Paso 3 — Hooks
echo ""
echo "[3/3] Copiando hooks..."

HOOKS_SRC="$AURA_DIR/.claude/hooks"
HOOKS_DST=".claude/hooks"

if [ ! -d "$HOOKS_SRC" ]; then
    echo "  WARN: No se encontraron hooks en .aura/.claude/hooks/ — omitiendo."
else
    mkdir -p "$HOOKS_DST"
    for hook in "$HOOKS_SRC"/*.ps1 "$HOOKS_SRC"/*.sh; do
        [ -f "$hook" ] || continue
        name=$(basename "$hook")
        dst="$HOOKS_DST/$name"
        if [ -f "$dst" ]; then
            echo "  $name ya existe — omitiendo (no sobreescribe)."
        else
            cp "$hook" "$dst"
            echo "  Copiado: $name"
        fi
    done
fi

echo ""
echo "=== Instalación completa ==="
echo ""
echo "Próximos pasos:"
echo "  1. Agregar hooks a .claude/settings.json (ver .aura/QUICKSTART.md Paso 3)"
echo "  2. Personalizar identidad en AGENTS.local.md EN LA RAIZ DEL PROYECTO (no dentro de .aura/) — ver .aura/AGENTS.local.example.md"
echo "  3. Iniciar sesión: claude ."
echo ""
