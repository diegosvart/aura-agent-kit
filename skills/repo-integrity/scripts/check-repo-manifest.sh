#!/usr/bin/env bash
# Verifica que los archivos versionados listados en manifest.txt existan en su ruta esperada
# (ADR-007). Solo evalua rutas del manifest, nunca prosa libre ni heuristicas de arbol.
# MISPLACED solo se reporta para basenames unicos en el manifest (ej. session_start.md) -
# basenames repetidos (ej. SKILL.md) solo pueden reportar MISSING, para no producir un falso
# positivo apuntando a un SKILL.md ajeno sin relacion real con el que falta.
# Salida: una linea "MISSING: <ruta>" o "MISPLACED: <encontrada> - se esperaba en <ruta>" por
# hallazgo; vacio si todo esta en orden.
# Exit code: 0 siempre (chequeo informativo, nunca bloqueante; no depende de gh).
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
MANIFEST="$REPO_ROOT/skills/repo-integrity/manifest.txt"

[ -f "$MANIFEST" ] || exit 0
cd "$REPO_ROOT" || exit 0

declare -a paths=()
declare -A optional_map
declare -A basename_count

# Solo builtins de bash en este loop (sin sed/basename) - en Windows/Git Bash el fork de un
# proceso externo cuesta ~50-150ms, y con ~20 lineas de manifest eso solo ya empuja el
# script por encima del limite de <2s del contrato de salida.
while read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"  # defensivo: un checkout Windows sin eol=lf deja \r y test -f falla en silencio
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
  esac

  optional=0
  path="$line"
  if [[ "$line" == *"#optional"* ]]; then
    optional=1
    read -r path <<< "${line%%#optional*}"
  fi

  [ -z "$path" ] && continue
  paths+=("$path")
  optional_map["$path"]=$optional
  bn="${path##*/}"
  basename_count["$bn"]=$(( ${basename_count["$bn"]:-0} + 1 ))
done < "$MANIFEST"

for path in "${paths[@]}"; do
  [ -f "$path" ] && continue
  [ "${optional_map[$path]}" = "1" ] && continue

  bn="${path##*/}"
  if [ "${basename_count[$bn]}" -eq 1 ]; then
    match=$(find . -name "$bn" -not -path './.git/*' -type f 2>/dev/null | sed 's#^\./##' | grep -vF "$path" | head -1)
    if [ -n "$match" ]; then
      echo "MISPLACED: $match - se esperaba en $path"
      continue
    fi
  fi

  echo "MISSING: $path"
done

exit 0
