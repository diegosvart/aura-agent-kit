#!/usr/bin/env bash
# build-harness-inventory.Tests.sh — Tests para build-harness-inventory.sh (Issue #208, Fase A)
# TDD: este archivo se escribe ANTES de que exista build-harness-inventory.sh. Se espera que
# TODOS los tests fallen hasta que el script se implemente (fase RED).
#
# Contrato bajo test:
#   Uso: bash build-harness-inventory.sh (sin argumentos), cwd en cualquier parte del repo.
#   Salida (una linea por item, en este orden):
#     AGENTS: <n>
#     SKILLS: <n>
#     PROTOCOLS: <n>
#     RULES: <n>
#     COMMANDS: <n>
#     HOOKS: <n>
#     BROKEN-REF: <situacion> -> <ruta>   (0 o mas lineas)
#   Categorias:
#     AGENTS    = agents/*.md
#     SKILLS    = skills/*/SKILL.md
#     PROTOCOLS = protocols/*.md
#     RULES     = .aura/rules/*.md + .claude/rules/*.md (suma combinada)
#     COMMANDS  = commands/*.md
#     HOOKS     = .claude/hooks/*.ps1
#   BROKEN-REF: parsea la tabla bajo "## Tabla de Routing" en protocols/router.md, extrae
#   todos los substrings entre backticks de la columna "Archivos a cargar", se queda solo con
#   los que contienen "/" y terminan en .md/.sh/.ps1/.json, y reporta los que no existen
#   relativos a la raiz del repo.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-harness-inventory.sh"

# Crea la estructura minima de directorios del harness dentro de un fixture git.
setup_fixture_repo() {
    local dir=$1
    mkdir -p "$dir"
    (
        cd "$dir"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git config core.autocrlf false
        mkdir -p agents skills protocols .aura/rules .claude/rules commands .claude/hooks
        echo base > base.txt
        git add base.txt
        git commit -q -m "base" >/dev/null
    )
}

run_test() {
    local test_name=$1
    local build_fixture_fn=$2
    local expected_output=$3

    test_count=$((test_count + 1))

    local fixture_dir
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-fixture-$$-$test_count"
    setup_fixture_repo "$fixture_dir"
    "$build_fixture_fn" "$fixture_dir"

    output=$(cd "$fixture_dir" && bash "$SCRIPT_PATH" 2>&1)
    rm -rf "$fixture_dir"

    if [ "$output" = "$expected_output" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected: $expected_output"
        echo "  Got:      $output"
        fail_count=$((fail_count + 1))
    fi
}

write_router_table() {
    # $1 = fixture dir, $2 = filas de tabla ya formateadas (una por linea, sin pipes iniciales/finales extra)
    local dir=$1
    local rows=$2
    cat > "$dir/protocols/router.md" << EOF
# Protocol — Router de Contexto

## Tabla de Routing

| Situación | Archivos a cargar | Trigger |
|-----------|------------------|---------|
$rows

## Otra Seccion

Texto que no debe parsearse.
EOF
}

# --- Fixture 1: conteo correcto de cada categoria, sin BROKEN-REF ---------------------------
fixture_counts_ok() {
    local dir=$1
    echo "# agent 1" > "$dir/agents/a1.md"
    echo "# agent 2" > "$dir/agents/a2.md"

    mkdir -p "$dir/skills/skill1" "$dir/skills/skill2" "$dir/skills/skill3"
    echo "# skill 1" > "$dir/skills/skill1/SKILL.md"
    echo "# skill 2" > "$dir/skills/skill2/SKILL.md"
    echo "# skill 3" > "$dir/skills/skill3/SKILL.md"

    echo "# other protocol" > "$dir/protocols/other.md"

    echo "# rule aura" > "$dir/.aura/rules/r1.md"
    echo "# rule claude" > "$dir/.claude/rules/r2.md"

    echo "# command" > "$dir/commands/c1.md"

    echo "# hook" > "$dir/.claude/hooks/h1.ps1"

    write_router_table "$dir" "| **Inicio de sesión** | \`protocols/other.md\` | Trigger de ejemplo |"
}

run_test "conteo correcto de cada categoria (agents, skills, protocols, rules, commands, hooks)" \
    fixture_counts_ok \
"AGENTS: 2
SKILLS: 3
PROTOCOLS: 2
RULES: 2
COMMANDS: 1
HOOKS: 1"

# --- Fixture 2: BROKEN-REF cuando router.md referencia una ruta inexistente ------------------
fixture_broken_ref() {
    local dir=$1
    write_router_table "$dir" "| **Situación fantasma** | \`protocols/no-existe.md\` | Trigger de ejemplo |"
}

run_test "detecta BROKEN-REF cuando router.md referencia una ruta que no existe" \
    fixture_broken_ref \
"AGENTS: 0
SKILLS: 0
PROTOCOLS: 1
RULES: 0
COMMANDS: 0
HOOKS: 0
BROKEN-REF: Situación fantasma → protocols/no-existe.md"

# --- Fixture 3: ninguna linea BROKEN-REF cuando todas las rutas existen ---------------------
fixture_no_broken_ref() {
    local dir=$1
    echo "# task start" > "$dir/protocols/task_start.md"
    write_router_table "$dir" "| **Nueva tarea** | \`protocols/task_start.md\` | Trigger de ejemplo |"
}

run_test "no reporta BROKEN-REF cuando todas las rutas referenciadas existen" \
    fixture_no_broken_ref \
"AGENTS: 0
SKILLS: 0
PROTOCOLS: 2
RULES: 0
COMMANDS: 0
HOOKS: 0"

# --- Fixture 4: celda con dos rutas separadas por " + ", una existe y otra no ---------------
fixture_two_paths_in_cell() {
    local dir=$1
    echo "# task start" > "$dir/protocols/task_start.md"
    write_router_table "$dir" "| **Retomar tarea** | \`protocols/task_start.md\` + \`.agent/memory/current-session.json\` | Trigger de ejemplo |"
}

run_test "celda con dos rutas en backticks valida ambas independientemente" \
    fixture_two_paths_in_cell \
"AGENTS: 0
SKILLS: 0
PROTOCOLS: 2
RULES: 0
COMMANDS: 0
HOOKS: 0
BROKEN-REF: Retomar tarea → .agent/memory/current-session.json"

# --- Fixture 5: slash-command en backticks junto a una ruta real se ignora ------------------
fixture_slash_command_ignored() {
    local dir=$1
    echo "# plan work" > "$dir/protocols/task_start.md"
    write_router_table "$dir" "| **Planificar trabajo nuevo** | \`/plan-work\` -> \`protocols/task_start.md\` | Trigger de ejemplo |"
}

run_test "slash-command entre backticks se ignora, no se reporta como BROKEN-REF" \
    fixture_slash_command_ignored \
"AGENTS: 0
SKILLS: 0
PROTOCOLS: 2
RULES: 0
COMMANDS: 0
HOOKS: 0"

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
