#!/usr/bin/env bash
# Aplica la actualización del harness: checkout de tag, copia de hooks, resync de CLAUDE.md.
# Uso: apply-update.sh <version_tag> [aura_path]
# Exit code: 0 si éxito, 1 si error
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: apply-update.sh <version_tag> [aura_path]" >&2
  exit 1
fi

VERSION_TAG="$1"
AURA_PATH="${2:-.aura}"

echo "Aplicando actualización del harness: $VERSION_TAG"
echo ""

# Validar .aura/
if [ ! -d "$AURA_PATH/.git" ]; then
  echo "ERROR: $AURA_PATH no es un checkout git" >&2
  exit 1
fi

# Fetch tags
echo "[1/4] Descargando tags de .aura/..."
git -C "$AURA_PATH" fetch --tags origin >/dev/null 2>&1 || {
  echo "WARN: No se pudo descargar tags (¿sin red?), continuando con tags locales..." >&2
}

# Checkout del tag
echo "[2/4] Checkout de $VERSION_TAG en .aura/..."
if ! git -C "$AURA_PATH" checkout "$VERSION_TAG" >/dev/null 2>&1; then
  echo "ERROR: No se puede hacer checkout a $VERSION_TAG" >&2
  exit 1
fi

# Crear .claude/hooks si no existe
mkdir -p .claude/hooks

# Copiar hooks (sobreescritura directa, sin confirmación per D5)
echo "[3/4] Sincronizando hooks (.claude/hooks/*.ps1)..."
hooks_changed=0
if [ -d "$AURA_PATH/.claude/hooks" ]; then
  for hook_file in "$AURA_PATH"/.claude/hooks/*.ps1; do
    if [ -f "$hook_file" ]; then
      hook_name=$(basename "$hook_file")
      target=".claude/hooks/$hook_name"
      if ! diff -q "$hook_file" "$target" >/dev/null 2>&1; then
        cp "$hook_file" "$target"
        echo "  - Actualizado: $hook_name"
        ((hooks_changed++))
      fi
    fi
  done
  if [ $hooks_changed -eq 0 ]; then
    echo "  (Hooks ya están al día)"
  fi
fi

# Resincronizar bloque aura:begin/aura:end en CLAUDE.md (si existe)
echo "[4/4] Resincronizando CLAUDE.md..."
if [ -f "CLAUDE.md" ] && grep -q "aura:begin" CLAUDE.md 2>/dev/null; then
  if [ -f "$AURA_PATH/CLAUDE.md" ]; then
    # Extraer bloque aura:begin/aura:end de .aura/CLAUDE.md
    aura_block=$(sed -n '/aura:begin/,/aura:end/p' "$AURA_PATH/CLAUDE.md" 2>/dev/null || echo "")
    if [ -n "$aura_block" ]; then
      # Usar python para hacer el reemplazo preservando la estructura
      python3 << 'PYTHON_RESYNC'
import re
import sys

try:
    with open('CLAUDE.md', 'r', encoding='utf-8') as f:
        content = f.read()

    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        aura_content = f.read()

    # Extraer el bloque aura:begin/aura:end de aura_content
    match = re.search(r'(aura:begin.*?aura:end)', aura_content, re.DOTALL)
    if match:
        aura_block = match.group(1)
        # Reemplazar en content
        new_content = re.sub(r'aura:begin.*?aura:end', aura_block, content, flags=re.DOTALL)

        with open('CLAUDE.md', 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("  (Bloque aura:begin/aura:end resincronizado)")
except Exception as e:
    print(f"  WARN: No se pudo resincronizar CLAUDE.md: {e}", file=sys.stderr)
PYTHON_RESYNC
    fi
  fi
fi

# Leer CHANGELOG para reportar lo que se aplicó
echo ""
echo "=== RESUMEN DE CAMBIOS ==="
echo "Versión actualizada a: $VERSION_TAG"
if [ $hooks_changed -gt 0 ]; then
  echo "Hooks actualizados: $hooks_changed archivo(s)"
else
  echo "Hooks: sin cambios"
fi

# Intentar extraer entradas del CHANGELOG
echo ""
if [ -f "$AURA_PATH/CHANGELOG.md" ]; then
  echo "=== CHANGELOG ==="
  # Extraer solo las entradas del tag que se acaba de aplicar
  # Formato esperado: ## [tag] - YYYY-MM-DD
  python3 << 'PYTHON_CHANGELOG'
import re
import sys

tag = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    with open(sys.argv[2], 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Buscar la sección del tag
    in_section = False
    section_lines = []
    for line in lines:
        if re.match(rf'^## \[?{re.escape(tag)}', line):
            in_section = True
        elif in_section and re.match(r'^## \[', line):
            # Encontramos la siguiente sección, detenerse
            break
        elif in_section:
            section_lines.append(line.rstrip())

    if section_lines:
        # Imprimir solo primeras 10 líneas (con prefijo)
        for line in section_lines[:10]:
            if line.strip():
                print(f"  {line}")
    else:
        print(f"  (No hay entradas para {tag} en CHANGELOG.md)")
except Exception as e:
    print(f"  (No se pudo leer CHANGELOG.md: {e})", file=sys.stderr)
PYTHON_CHANGELOG
fi

echo ""
echo "✓ Actualización aplicada exitosamente"
exit 0
