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

# Validar .aura/ — -e (no -d): en un git submodule .aura/.git es un ARCHIVO
# gitlink ("gitdir: ..."), no un directorio (caso real: crawler-mcp-diagram)
if [ ! -e "$AURA_PATH/.git" ]; then
  echo "ERROR: $AURA_PATH no es un checkout git" >&2
  exit 1
fi

# Fetch tags
echo "[1/6] Descargando tags de .aura/..."
git -C "$AURA_PATH" fetch --tags origin >/dev/null 2>&1 || {
  echo "WARN: No se pudo descargar tags (¿sin red?), continuando con tags locales..." >&2
}

# Checkout del tag
echo "[2/6] Checkout de $VERSION_TAG en .aura/..."
checkout_err=$(git -C "$AURA_PATH" checkout "$VERSION_TAG" 2>&1 >/dev/null)
if [ $? -ne 0 ]; then
  echo "ERROR: No se puede hacer checkout a $VERSION_TAG" >&2
  echo "$checkout_err" >&2
  exit 1
fi

# Crear .claude/hooks y .githooks si no existen
mkdir -p .claude/hooks .githooks

# Copiar hooks (sobreescritura directa, sin confirmación per D5)
echo "[3/6] Sincronizando hooks (.claude/hooks/*.ps1 + .githooks/pre-push)..."
hooks_changed=0
if [ -d "$AURA_PATH/.claude/hooks" ]; then
  for hook_file in "$AURA_PATH"/.claude/hooks/*.ps1; do
    if [ -f "$hook_file" ]; then
      hook_name=$(basename "$hook_file")
      target=".claude/hooks/$hook_name"
      if ! diff -q "$hook_file" "$target" >/dev/null 2>&1; then
        cp "$hook_file" "$target"
        echo "  - Actualizado: $hook_name"
        ((++hooks_changed))
      fi
    fi
  done
fi

# Sincronizar el hook nativo de Git (.githooks/pre-push) — segunda capa de enforcement
# independiente de Claude Code (ver session-start.ps1, que setea core.hooksPath).
if [ -f "$AURA_PATH/.githooks/pre-push" ]; then
  if ! diff -q "$AURA_PATH/.githooks/pre-push" ".githooks/pre-push" >/dev/null 2>&1; then
    cp "$AURA_PATH/.githooks/pre-push" ".githooks/pre-push"
    chmod +x ".githooks/pre-push"
    echo "  - Actualizado: .githooks/pre-push"
    ((++hooks_changed))
  fi
fi

if [ $hooks_changed -eq 0 ]; then
  echo "  (Hooks ya están al día)"
fi

# Resincronizar bloque aura:begin/aura:end en CLAUDE.md (si existe)
echo "[4/6] Resincronizando CLAUDE.md..."
if [ -f "CLAUDE.md" ] && grep -q "aura:begin" CLAUDE.md 2>/dev/null; then
  if [ -f "$AURA_PATH/CLAUDE.md" ]; then
    # Extraer bloque aura:begin/aura:end de .aura/CLAUDE.md
    aura_block=$(sed -n '/aura:begin/,/aura:end/p' "$AURA_PATH/CLAUDE.md" 2>/dev/null || echo "")
    if [ -n "$aura_block" ]; then
      # Usar python para hacer el reemplazo preservando la estructura
      python3 - "$AURA_PATH/CLAUDE.md" << 'PYTHON_RESYNC'
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
    raise ValueError(f"No se pudo resincronizar CLAUDE.md: {e}") from e
PYTHON_RESYNC
      if [ $? -ne 0 ]; then
        echo "ERROR: Resync de CLAUDE.md falló" >&2
        exit 1
      fi
    else
      echo "  ($AURA_PATH/CLAUDE.md sin bloque aura:begin/aura:end — resync omitido)"
    fi
  else
    echo "  ($AURA_PATH/CLAUDE.md no existe — resync omitido)"
  fi
else
  echo "  (CLAUDE.md local sin bloque aura:begin/aura:end — resync omitido)"
fi

# Sincronizar patrones muertos Write(...) -> Edit(...) en .claude/settings.json (si existe)
echo "[5/6] Sincronizando permisos de .claude/settings.json..."
settings_patterns_replaced=0
if [ -f ".claude/settings.json" ]; then
  settings_resync_output=$(python3 - << 'PYTHON_SETTINGS_RESYNC'
try:
    path = ".claude/settings.json"
    replacements = [
        ("Write(**)", "Edit(**)"),
        ("Write(.env)", "Edit(.env)"),
        ("Write(.env.*)", "Edit(.env.*)"),
        ("Write(*.pem)", "Edit(*.pem)"),
        ("Write(*.key)", "Edit(*.key)"),
        ("Write(*.secret)", "Edit(*.secret)"),
    ]

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    total = 0
    for old, new in replacements:
        count = content.count(old)
        if count:
            content = content.replace(old, new)
            total += count

    if total:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

    print(total)
except Exception as e:
    raise ValueError(f"No se pudo sincronizar .claude/settings.json: {e}") from e
PYTHON_SETTINGS_RESYNC
)
  if [ $? -ne 0 ]; then
    echo "ERROR: Sincronización de .claude/settings.json falló" >&2
    exit 1
  fi
  settings_patterns_replaced=$(echo "$settings_resync_output" | tail -n 1)
  if [ "$settings_patterns_replaced" -gt 0 ] 2>/dev/null; then
    echo "  - $settings_patterns_replaced patrón(es) Write(...) reemplazado(s) por Edit(...)"
  else
    settings_patterns_replaced=0
    echo "  (Sin patrones muertos que sincronizar)"
  fi
else
  echo "  (.claude/settings.json no existe — sincronización omitida)"
fi

# Verificar/registrar git-guard.ps1 como PreToolUse — caso real encontrado en
# crawler-mcp-diagram: el hook existia en .claude/hooks/git-guard.ps1 (sincronizado por el
# paso [3/6]) pero nunca quedo registrado en PreToolUse de settings.json, asi que Claude Code
# nunca lo invocaba y 3 commits terminaron pusheados directo a develop sin que nada lo
# bloqueara. apply-update.sh solo sincronizaba patrones de permisos muertos (Write->Edit), no
# la presencia de este hook critico. Autofix, no solo warning: mismo criterio que el paso
# [3/6] (sobreescritura directa de hooks sin confirmacion) porque un hook de seguridad sin
# registrar es tan grave como uno desactualizado.
echo "[6/6] Verificando registro de git-guard.ps1 en PreToolUse..."
git_guard_added=""
if [ -f ".claude/settings.json" ] && [ -f ".claude/hooks/git-guard.ps1" ]; then
  git_guard_added=$(python3 - << 'PYTHON_GITGUARD_SYNC'
import json

path = ".claude/settings.json"
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    pretooluse = data.setdefault("PreToolUse", [])

    def has_git_guard(matcher):
        for entry in pretooluse:
            if entry.get("matcher") == matcher:
                for h in entry.get("hooks", []):
                    if "git-guard.ps1" in h.get("command", ""):
                        return True
        return False

    added = []
    for matcher in ["Bash", "PowerShell"]:
        if not has_git_guard(matcher):
            pretooluse.append({
                "matcher": matcher,
                "hooks": [
                    {
                        "type": "command",
                        "command": "pwsh -NonInteractive -File .claude/hooks/git-guard.ps1",
                        "timeout": 5,
                    }
                ],
            })
            added.append(matcher)

    if added:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")

    print(",".join(added))
except Exception as e:
    raise ValueError(f"No se pudo verificar/registrar git-guard.ps1 en PreToolUse: {e}") from e
PYTHON_GITGUARD_SYNC
)
  if [ $? -ne 0 ]; then
    echo "ERROR: Verificación de git-guard.ps1 en PreToolUse falló" >&2
    exit 1
  fi
  if [ -n "$git_guard_added" ]; then
    echo "  - PreToolUse registrado para: $git_guard_added (git-guard.ps1 no estaba enforced)"
  else
    echo "  (git-guard.ps1 ya estaba registrado en PreToolUse)"
  fi
elif [ -f ".claude/hooks/git-guard.ps1" ]; then
  echo "  (.claude/settings.json no existe — no se puede verificar el registro)"
else
  echo "  (.claude/hooks/git-guard.ps1 no existe todavía — se sincronizará en la próxima corrida)"
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
if [ "$settings_patterns_replaced" -gt 0 ] 2>/dev/null; then
  echo "Permisos settings.json: sincronizados ($settings_patterns_replaced patrones)"
else
  echo "Permisos settings.json: sin cambios"
fi
if [ -n "$git_guard_added" ]; then
  echo "git-guard.ps1 en PreToolUse: registrado ($git_guard_added) — antes NO estaba enforced"
else
  echo "git-guard.ps1 en PreToolUse: ya estaba registrado"
fi

# Intentar extraer entradas del CHANGELOG
echo ""
if [ -f "$AURA_PATH/CHANGELOG.md" ]; then
  echo "=== CHANGELOG ==="
  # Extraer solo las entradas del tag que se acaba de aplicar
  # Formato esperado: ## [tag] - YYYY-MM-DD
  python3 - "$VERSION_TAG" "$AURA_PATH/CHANGELOG.md" << 'PYTHON_CHANGELOG'
import re
import sys

try:
    tag = sys.argv[1]
    changelog_path = sys.argv[2]

    with open(changelog_path, 'r', encoding='utf-8') as f:
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
    raise ValueError(f"No se pudo leer CHANGELOG.md: {e}") from e
PYTHON_CHANGELOG
  if [ $? -ne 0 ]; then
    echo "ERROR: Lectura de CHANGELOG.md falló" >&2
    exit 1
  fi
fi

echo ""
echo "✓ Actualización aplicada exitosamente"
exit 0
