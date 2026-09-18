#!/usr/bin/env bash
# build-harness-inventory.sh — Inventario del harness + deteccion de referencias rotas en
# protocols/router.md (Issue #208, Fase A). Bash puro, sin dependencias externas mas alla de
# git/grep/sed (mismo patron que skills/repo-integrity/scripts/check-repo-manifest.sh).
#
# Uso: bash build-harness-inventory.sh (sin argumentos), cwd en cualquier parte del repo.
# Exit code: siempre 0 (chequeo informativo, no bloqueante).
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
cd "$REPO_ROOT" || exit 0

count_glob() {
    local pattern="$1"
    shopt -s nullglob
    local files=( $pattern )
    shopt -u nullglob
    echo "${#files[@]}"
}

agents_count=$(count_glob "agents/*.md")
skills_count=$(count_glob "skills/*/SKILL.md")
protocols_count=$(count_glob "protocols/*.md")
rules_aura_count=$(count_glob ".aura/rules/*.md")
rules_claude_count=$(count_glob ".claude/rules/*.md")
rules_count=$((rules_aura_count + rules_claude_count))
commands_count=$(count_glob "commands/*.md")
hooks_count=$(count_glob ".claude/hooks/*.ps1")

echo "AGENTS: $agents_count"
echo "SKILLS: $skills_count"
echo "PROTOCOLS: $protocols_count"
echo "RULES: $rules_count"
echo "COMMANDS: $commands_count"
echo "HOOKS: $hooks_count"

ROUTER_FILE="$REPO_ROOT/protocols/router.md"
[ -f "$ROUTER_FILE" ] || exit 0

in_table=0
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"

    if [ "$in_table" -eq 0 ]; then
        if [ "$line" = "## Tabla de Routing" ]; then
            in_table=1
        fi
        continue
    fi

    # Fin de la seccion: cualquier otro encabezado de nivel 2
    if [[ "$line" == "## "* ]]; then
        in_table=0
        continue
    fi

    # Solo procesar lineas de tabla
    [[ "$line" == "|"* ]] || continue

    # Fila separadora (solo pipes, guiones y espacios)
    if [[ "$line" =~ ^[\|\ -]+$ ]]; then
        continue
    fi

    col1=$(echo "$line" | cut -d'|' -f2)
    col2=$(echo "$line" | cut -d'|' -f3)

    # trim whitespace
    col1=$(echo "$col1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    col2=$(echo "$col2" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # strip markdown bold wrapping
    col1="${col1#\*\*}"
    col1="${col1%\*\*}"

    # fila de encabezado
    [ "$col1" = "Situación" ] && continue
    [ -z "$col1" ] && continue

    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        ref="${ref#\`}"
        ref="${ref%\`}"

        [[ "$ref" == */* ]] || continue
        [[ "$ref" =~ \.(md|sh|ps1|json)$ ]] || continue

        if [ ! -e "$REPO_ROOT/$ref" ]; then
            echo "BROKEN-REF: $col1 → $ref"
        fi
    done < <(echo "$col2" | grep -oE '`[^`]*`')

done < "$ROUTER_FILE"

exit 0
