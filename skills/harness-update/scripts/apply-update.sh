#!/usr/bin/env bash
# Aplica la actualización del harness: canal submodule (checkout de tag) o canal plugin
# (claude plugin update), seguido de los mismos pasos de sincronización en ambos casos
# (hooks, CLAUDE.md, permisos, registro de hooks críticos) — ver ADR-009 y
# docs/aura/specs/2026-09-02-harness-update-plugin-apply-design.md.
# Uso: apply-update.sh <version_tag> [aura_path]
# Exit code: 0 si éxito, 1 si error
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: apply-update.sh <version_tag> [aura_path]" >&2
  exit 1
fi

VERSION_TAG="$1"
AURA_PATH="${2:-.aura}"
CACHE_FILE=".agent/memory/harness-update-check.json"

echo "Aplicando actualización del harness: $VERSION_TAG"
echo ""

# Detección de canal — misma señal que session-start.ps1: .aura/.git existe -> submodule;
# si no, se busca el plugin_id que dejó el hook en el cache (harness_update_plugin_id).
CHANNEL="submodule"
SOURCE_PATH="$AURA_PATH"
PLUGIN_ID=""

if [ ! -e "$AURA_PATH/.git" ]; then
  if [ -f "$CACHE_FILE" ]; then
    PLUGIN_ID=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        data = json.load(f)
    print(data.get('harness_update_plugin_id') or '')
except Exception:
    print('')
" "$CACHE_FILE" 2>/dev/null || echo "")
  fi

  if [ -n "$PLUGIN_ID" ]; then
    CHANNEL="plugin"
  else
    echo "ERROR: $AURA_PATH no es un checkout git, y no se detectó instalación vía plugin" >&2
    echo "(harness_update_plugin_id ausente en $CACHE_FILE)." >&2
    echo "Corré 'claude plugin marketplace list' para diagnosticar, o verificá que $AURA_PATH exista como submodulo." >&2
    exit 1
  fi
fi

echo "Canal detectado: $CHANNEL"
echo ""

if [ "$CHANNEL" = "submodule" ]; then
  # Fetch tags
  echo "[1/6] Descargando tags de $AURA_PATH/..."
  git -C "$AURA_PATH" fetch --tags origin >/dev/null 2>&1 || {
    echo "WARN: No se pudo descargar tags (¿sin red?), continuando con tags locales..." >&2
  }

  # Checkout del tag
  echo "[2/6] Checkout de $VERSION_TAG en $AURA_PATH/..."
  checkout_err=$(git -C "$AURA_PATH" checkout "$VERSION_TAG" 2>&1 >/dev/null)
  if [ $? -ne 0 ]; then
    echo "ERROR: No se puede hacer checkout a $VERSION_TAG" >&2
    echo "$checkout_err" >&2
    exit 1
  fi
else
  # Canal plugin: no hay tag que checkoutear -- "actualizar" es refrescar el cache del
  # marketplace y pedirle a Claude Code que instale la última versión disponible del plugin.
  MARKETPLACE_NAME="${PLUGIN_ID#*@}"

  echo "[1/6] Refrescando marketplace '$MARKETPLACE_NAME'..."
  marketplace_err=$(claude plugin marketplace update "$MARKETPLACE_NAME" 2>&1)
  if [ $? -ne 0 ]; then
    echo "WARN: No se pudo refrescar el marketplace '$MARKETPLACE_NAME' (¿sin red?), continuando con el cache existente..." >&2
    echo "$marketplace_err" >&2
  fi

  # El scope instalado real puede ser distinto del default ("user") de `claude plugin
  # update` -- se resuelve antes de aplicar, priorizando "project" si hay ambos (mismo
  # criterio que session-start.ps1).
  installed_before=$(claude plugin list --json 2>/dev/null || echo "[]")
  PLUGIN_SCOPE=$(python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1]) if sys.argv[1] else []
except Exception:
    data = []
matches = [e for e in data if e.get('id') == sys.argv[2]]
matches.sort(key=lambda e: e.get('scope') != 'project')
print(matches[0]['scope'] if matches else 'user')
" "$installed_before" "$PLUGIN_ID" 2>/dev/null || echo "user")

  echo "[2/6] Actualizando plugin $PLUGIN_ID (scope: $PLUGIN_SCOPE)..."
  update_err=$(claude plugin update "$PLUGIN_ID" --scope "$PLUGIN_SCOPE" -y 2>&1)
  if [ $? -ne 0 ]; then
    echo "ERROR: 'claude plugin update $PLUGIN_ID' falló" >&2
    echo "$update_err" >&2
    exit 1
  fi

  installed_after=$(claude plugin list --json 2>/dev/null || echo "[]")
  SOURCE_PATH=$(python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1]) if sys.argv[1] else []
except Exception:
    data = []
matches = [e for e in data if e.get('id') == sys.argv[2] and e.get('scope') == sys.argv[3]]
print(matches[0].get('installPath', '') if matches else '')
" "$installed_after" "$PLUGIN_ID" "$PLUGIN_SCOPE" 2>/dev/null || echo "")

  if [ -z "$SOURCE_PATH" ] || [ ! -d "$SOURCE_PATH" ]; then
    echo "ERROR: No se pudo resolver installPath tras actualizar $PLUGIN_ID" >&2
    exit 1
  fi
fi

# A partir de acá, ambos canales comparten los mismos pasos de sincronización — $SOURCE_PATH
# apunta a .aura/ (submodule) o al installPath del plugin recién actualizado (plugin), que
# contiene el mismo árbol de archivos del repo en ambos casos.

# Crear .claude/hooks y .githooks si no existen
mkdir -p .claude/hooks .githooks

# Copiar hooks (sobreescritura directa, sin confirmación per D5)
echo "[3/6] Sincronizando hooks (.claude/hooks/*.ps1 + .githooks/pre-push)..."
hooks_changed=0
if [ -d "$SOURCE_PATH/.claude/hooks" ]; then
  for hook_file in "$SOURCE_PATH"/.claude/hooks/*.ps1; do
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
if [ -f "$SOURCE_PATH/.githooks/pre-push" ]; then
  if ! diff -q "$SOURCE_PATH/.githooks/pre-push" ".githooks/pre-push" >/dev/null 2>&1; then
    cp "$SOURCE_PATH/.githooks/pre-push" ".githooks/pre-push"
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
  if [ -f "$SOURCE_PATH/CLAUDE.md" ]; then
    # Extraer bloque aura:begin/aura:end de $SOURCE_PATH/CLAUDE.md
    aura_block=$(sed -n '/aura:begin/,/aura:end/p' "$SOURCE_PATH/CLAUDE.md" 2>/dev/null || echo "")
    if [ -n "$aura_block" ]; then
      # Usar python para hacer el reemplazo preservando la estructura
      python3 - "$SOURCE_PATH/CLAUDE.md" << 'PYTHON_RESYNC'
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
      echo "  ($SOURCE_PATH/CLAUDE.md sin bloque aura:begin/aura:end — resync omitido)"
    fi
  else
    echo "  ($SOURCE_PATH/CLAUDE.md no existe — resync omitido)"
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

# Verificar/registrar hooks críticos de seguridad como PreToolUse — caso real encontrado en
# crawler-mcp-diagram: git-guard.ps1 existia en .claude/hooks/ (sincronizado por el paso
# [3/6]) pero nunca quedo registrado en PreToolUse de settings.json, asi que Claude Code
# nunca lo invocaba y 3 commits terminaron pusheados directo a develop sin que nada lo
# bloqueara. apply-update.sh solo sincronizaba patrones de permisos muertos (Write->Edit), no
# la presencia de estos hooks criticos. Autofix, no solo warning: mismo criterio que el paso
# [3/6] (sobreescritura directa de hooks sin confirmacion) porque un hook de seguridad sin
# registrar es tan grave como uno desactualizado. Parametrizado por nombre de hook (no
# duplicar el bloque Python por cada hook nuevo) — cubre git-guard.ps1 y
# sensitive-data-guard.ps1 con la misma función.
# Deja el resultado en HOOK_SYNC_RESULT (global, no via stdout) — evita mezclar los echo de
# progreso con el valor devuelto cuando se llama desde $(...).
sync_pretooluse_hook() {
  local hook_name="$1"
  HOOK_SYNC_RESULT=""
  if [ ! -f ".claude/settings.json" ] || [ ! -f ".claude/hooks/$hook_name" ]; then
    if [ -f ".claude/hooks/$hook_name" ]; then
      echo "  (.claude/settings.json no existe — no se puede verificar el registro de $hook_name)"
    else
      echo "  (.claude/hooks/$hook_name no existe todavía — se sincronizará en la próxima corrida)"
    fi
    return 0
  fi

  local added
  added=$(python3 - "$hook_name" << 'PYTHON_HOOK_SYNC'
import json
import sys

hook_name = sys.argv[1]
path = ".claude/settings.json"
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    hooks_root = data.setdefault("hooks", {})
    pretooluse = hooks_root.setdefault("PreToolUse", [])
    hook_entry = {
        "type": "command",
        "command": f"pwsh -NonInteractive -File .claude/hooks/{hook_name}",
        "timeout": 5,
    }

    def find_entry(matcher):
        for entry in pretooluse:
            if entry.get("matcher") == matcher:
                return entry
        return None

    added = []
    for matcher in ["Bash", "PowerShell"]:
        entry = find_entry(matcher)
        if entry is None:
            # Sin entrada para este matcher todavia -> crear una nueva
            pretooluse.append({"matcher": matcher, "hooks": [hook_entry]})
            added.append(matcher)
            continue

        hooks = entry.setdefault("hooks", [])
        if not any(hook_name in h.get("command", "") for h in hooks):
            # Ya existe una entrada para este matcher (posiblemente con hooks custom
            # del consumidor) -> agregar AL FINAL de su lista, nunca crear un matcher
            # duplicado. Un segundo objeto con el mismo "matcher" en el array es
            # comportamiento ambiguo (no esta claro si Claude Code corre ambos o solo
            # el ultimo) y arriesgaria desactivar en silencio un hook custom existente.
            hooks.append(hook_entry)
            added.append(matcher)

    if added:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")

    print(",".join(added))
except Exception as e:
    raise ValueError(f"No se pudo verificar/registrar {hook_name} en PreToolUse: {e}") from e
PYTHON_HOOK_SYNC
)
  if [ $? -ne 0 ]; then
    echo "ERROR: Verificación de $hook_name en PreToolUse falló" >&2
    exit 1
  fi
  if [ -n "$added" ]; then
    echo "  - PreToolUse registrado para: $added ($hook_name no estaba enforced)"
  else
    echo "  ($hook_name ya estaba registrado en PreToolUse)"
  fi
  HOOK_SYNC_RESULT="$added"
}

echo "[6/6] Verificando registro de hooks críticos en PreToolUse..."
sync_pretooluse_hook "git-guard.ps1"
git_guard_added="$HOOK_SYNC_RESULT"
sync_pretooluse_hook "sensitive-data-guard.ps1"
sensitive_guard_added="$HOOK_SYNC_RESULT"

# Leer CHANGELOG para reportar lo que se aplicó
echo ""
echo "=== RESUMEN DE CAMBIOS ==="
echo "Canal: $CHANNEL"
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
if [ -n "$sensitive_guard_added" ]; then
  echo "sensitive-data-guard.ps1 en PreToolUse: registrado ($sensitive_guard_added) — antes NO estaba enforced"
else
  echo "sensitive-data-guard.ps1 en PreToolUse: ya estaba registrado"
fi

if [ "$CHANNEL" = "plugin" ]; then
  echo ""
  echo "⚠ Canal plugin: Claude Code requiere reiniciar la sesión para que el contenido"
  echo "  actualizado del plugin ($PLUGIN_ID) tome efecto — limitación conocida del CLI"
  echo "  ('claude plugin update --help': 'restart required to apply')."
fi

# Intentar extraer entradas del CHANGELOG
echo ""
if [ -f "$SOURCE_PATH/CHANGELOG.md" ]; then
  echo "=== CHANGELOG ==="
  # Extraer solo las entradas del tag que se acaba de aplicar
  # Formato esperado: ## [tag] - YYYY-MM-DD
  python3 - "$VERSION_TAG" "$SOURCE_PATH/CHANGELOG.md" << 'PYTHON_CHANGELOG'
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
