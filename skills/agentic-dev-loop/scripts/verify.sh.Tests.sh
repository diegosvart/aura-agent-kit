#!/usr/bin/env bash
# verify.sh.Tests.sh — Tests para verify.sh (Issue #351)
#
# Cubre el bug real: con comando vacio en session-stack.json, verify.sh devolvia 0 EN
# SILENCIO (sin imprimir nada) -- indistinguible para un dev-runner de "el check corrio y
# paso". El fix hace que un comando vacio imprima "SKIP <name> ..." explicito, visible en el
# output, aunque siga sin bloquear el exit code agregado (mismo criterio no-fatal que ya usa
# "lint" cuando shellcheck no esta disponible: una herramienta/check ausente por diseño no es
# lo mismo que un test rojo).
#
# Patron de fixture: igual a check-repo-manifest.Tests.sh -- un directorio temporal con su
# propio ".agent/memory/session-stack.json", se invoca verify.sh con cwd adentro de ese
# fixture (verify.sh usa la ruta relativa ".agent/memory/session-stack.json").

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify.sh"
trap 'rm -rf "$(dirname "$SCRIPT_PATH")"/.tmp-test-verify-*' EXIT

write_stack_file() {
    # Escribe el JSON a mano (sin python3): el python3 nativo de Windows de este entorno no
    # resuelve paths estilo MSYS ("/c/Users/...") que produce "$(pwd)" bajo Git Bash -- solo
    # funciona con rutas relativas (que es justamente lo unico que verify.sh le pasa). Evita
    # ese problema de entorno por completo en vez de arrastrarlo a la suite de tests.
    local fixture_dir="$1" lint="$2" typecheck="$3" test_cmd="$4"
    mkdir -p "$fixture_dir/.agent/memory"
    cat > "$fixture_dir/.agent/memory/session-stack.json" << STACK_JSON_END
{"lint": "$lint", "typecheck": "$typecheck", "test": "$test_cmd"}
STACK_JSON_END
}

run_verify_in() {
    local fixture_dir="$1"
    ( cd "$fixture_dir" && bash "$SCRIPT_PATH" )
}

echo ""
echo "--- Comando vacio -> imprime SKIP explicito (no omite en silencio) ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-verify-skip-$$"
write_stack_file "$fixture_dir" "" "" ""
output=$(run_verify_in "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
if [ "$actual_exit" -eq 0 ] && echo "$output" | grep -q "SKIP lint" && echo "$output" | grep -q "SKIP typecheck" && echo "$output" | grep -q "SKIP test"; then
    echo -e "${GREEN}✓ PASS${NC} — comando vacio imprime SKIP para los 3 checks y exit 0"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — comando vacio imprime SKIP para los 3 checks y exit 0"
    echo "  Got exit $actual_exit"
    echo "$output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Comando que falla -> propaga exit 1 y lo reporta como FAIL ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-verify-fail-$$"
write_stack_file "$fixture_dir" "" "" "exit 1"
output=$(run_verify_in "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
if [ "$actual_exit" -eq 1 ] && echo "$output" | grep -q "FAIL test"; then
    echo -e "${GREEN}✓ PASS${NC} — comando que falla -> exit 1 y FAIL test"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — comando que falla -> exit 1 y FAIL test"
    echo "  Got exit $actual_exit"
    echo "$output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Comando que pasa -> imprime OK y exit 0 ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-verify-ok-$$"
write_stack_file "$fixture_dir" "" "" "echo hecho"
output=$(run_verify_in "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
if [ "$actual_exit" -eq 0 ] && echo "$output" | grep -q "OK test"; then
    echo -e "${GREEN}✓ PASS${NC} — comando que pasa -> exit 0 y OK test"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — comando que pasa -> exit 0 y OK test"
    echo "  Got exit $actual_exit"
    echo "$output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
