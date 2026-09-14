#!/usr/bin/env bash
# verify-install.sh — Verificación post-instalación del harness Aura
#
# Verifica que:
# 1. Hooks referenciados en .claude/settings.json existan en disco
# 2. Esos archivos estén trackeados en git
# 3. El submodule .aura/ esté inicializado y sin diffs inesperados
#
# Salida: MISSING_FILE / NOT_TRACKED / SUBMODULE_DRIFT por línea si hay issues,
# o "Verificación post-instalación: OK" si todo está bien.
# Exit code: 0 si OK, 1 si hay MISSING_FILE o NOT_TRACKED

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
cd "$REPO_ROOT" || exit 0

# Listas de hallazgos
declare -a missing_files=()
declare -a not_tracked_files=()
submodule_drift=""

# Para evitar duplicados
declare -A seen_files

# Extraer y procesar comandos de .claude/settings.json
if [ -f ".claude/settings.json" ]; then
    # Buscar todas las líneas con "command" y extraer el comando
    while IFS= read -r cmd_line; do
        # Línea típica: "command": "pwsh -NonInteractive -File .claude/hooks/git-guard.ps1"
        # Usar sed para extraer comando entre comillas
        cmd=$(echo "$cmd_line" | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

        if [ -z "$cmd" ] || [ "$cmd" = "$cmd_line" ]; then
            continue
        fi

        # Extraer ruta del archivo del comando
        # Soportamos: .claude/hooks/*.ps1, .claude/hooks/*.sh
        # Usar sed para extraer la primera ruta
        file_path=$(echo "$cmd" | sed -n 's/.*\(\.claude\/hooks\/[^ "]*\.\(ps1\|sh\)\).*/\1/p')

        if [ -n "$file_path" ] && [ -z "${seen_files[$file_path]:-}" ]; then
            seen_files["$file_path"]=1

            # 1. Verificar que existe en disco
            if [ ! -f "$file_path" ]; then
                missing_files+=("$file_path")
            else
                # 2. Verificar que está trackeado en git
                if ! git ls-files --error-unmatch "$file_path" > /dev/null 2>&1; then
                    not_tracked_files+=("$file_path")
                fi
            fi
        fi
    done < <(grep '"command"' ".claude/settings.json")
fi

# 3. Verificar submodule .aura/
if [ -d ".aura" ] && [ -f ".gitmodules" ]; then
    status_line=$(git submodule status 2>/dev/null | grep "\.aura" || echo "")
    if [ -n "$status_line" ]; then
        first_char="${status_line:0:1}"
        if [ "$first_char" = "-" ]; then
            submodule_drift="SUBMODULE_DRIFT: .aura no inicializado — correr git submodule update --init .aura"
        elif [ "$first_char" = "+" ]; then
            submodule_drift="SUBMODULE_DRIFT: .aura en commit distinto al registrado — revisar git diff --cached .aura"
        fi
    fi
fi

# Salida
has_issues=0

# Reportar archivos faltantes
for file in "${missing_files[@]}"; do
    echo "MISSING_FILE: $file"
    echo "Sugerencia para corregir: copiar desde .aura/.claude/hooks/$(basename "$file") (si existe)"
    has_issues=1
done

# Reportar archivos no trackeados
for file in "${not_tracked_files[@]}"; do
    echo "NOT_TRACKED: $file"
    echo "Sugerencia para corregir: git add $file"
    has_issues=1
done

# Reportar drifts de submodule
if [ -n "$submodule_drift" ]; then
    echo "$submodule_drift"
    has_issues=1
fi

# Reporte final
if [ $has_issues -eq 0 ]; then
    echo "Verificación post-instalación: OK"
    exit 0
else
    exit 1
fi
