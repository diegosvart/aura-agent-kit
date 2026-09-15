#!/usr/bin/env bash
# check-process-errors.Tests.sh — Tests para check-process-errors.sh (Issue #206, idea [021])
# TDD: este archivo se escribe ANTES de que exista check-process-errors.sh. Se espera que
# TODOS los tests fallen hasta que el script se implemente (fase RED).
#
# Contrato bajo test:
#   Uso: check-process-errors.sh (sin argumentos), cwd en cualquier parte del repo.
#   Lee .agent/memory/observability/process-errors.jsonl (relativo a la raiz del repo).
#   Si no existe o esta vacio: sin salida, exit 0 (fail-open).
#   Si existe: agrupa por tipo dentro de las ultimas 10 session_id distintas (por orden de
#   aparicion en el archivo, mas recientes = mas al final). Para cada tipo con 3+ ocurrencias
#   dentro de esas sesiones, imprime una linea:
#     PROCESS-ERROR-PATTERN: <tipo> aparecio <n> veces en las ultimas 10 sesiones -- considerar /auto-research
#   Siempre exit 0 (chequeo informativo, no bloqueante).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-process-errors.sh"
FIXTURE_DIR="$(dirname "$SCRIPT_PATH")/.tmp-test-fixture-check-process-errors-$$"

setup_fixture_repo() {
    mkdir -p "$FIXTURE_DIR"
    (
        cd "$FIXTURE_DIR"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
    )
}

write_jsonl_entry() {
    local session_id=$1
    local tipo=$2
    mkdir -p "$FIXTURE_DIR/.agent/memory/observability"
    echo "{\"logged_at\": \"2026-09-15T00:00:00Z\", \"session_id\": \"$session_id\", \"tipo\": \"$tipo\", \"descripcion\": \"x\", \"afectado\": \"\", \"corregido\": true}" >> "$FIXTURE_DIR/.agent/memory/observability/process-errors.jsonl"
}

run_test() {
    local test_name=$1
    local expected_output=$2

    test_count=$((test_count + 1))
    output=$(cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" 2>&1)
    exit_code=$?

    if [ "$output" = "$expected_output" ] && [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected (exit 0): $expected_output"
        echo "  Got (exit $exit_code): $output"
        fail_count=$((fail_count + 1))
    fi
}

setup_fixture_repo

# --- Test 1: sin archivo -> sin salida, exit 0 -----------------------------------------------
run_test "sin process-errors.jsonl: sin salida" ""

# --- Test 2: mismo tipo 3 veces en 3 sesiones distintas -> reporta el patron -----------------
write_jsonl_entry "sess-1" "branch-wrong-base"
write_jsonl_entry "sess-2" "branch-wrong-base"
write_jsonl_entry "sess-3" "branch-wrong-base"
run_test "mismo tipo 3+ veces en sesiones distintas: reporta patron" \
    "PROCESS-ERROR-PATTERN: branch-wrong-base aparecio 3 veces en las ultimas 10 sesiones -- considerar /auto-research"

# --- Test 3: menos de 3 ocurrencias -> sin salida --------------------------------------------
rm -f "$FIXTURE_DIR/.agent/memory/observability/process-errors.jsonl"
write_jsonl_entry "sess-1" "merge-order"
write_jsonl_entry "sess-2" "merge-order"
run_test "menos de 3 ocurrencias: sin salida" ""

# --- Test 4: 3 ocurrencias del mismo tipo pero en la MISMA sesion -> tambien cuenta ----------
# (autodeclarado en el momento -- 3 eventos reales son 3 eventos reales, sesion no filtra el conteo por tipo,
#  solo acota la ventana de "ultimas 10 sesiones" a considerar)
rm -f "$FIXTURE_DIR/.agent/memory/observability/process-errors.jsonl"
write_jsonl_entry "sess-1" "no-retry-after-rejection"
write_jsonl_entry "sess-1" "no-retry-after-rejection"
write_jsonl_entry "sess-1" "no-retry-after-rejection"
run_test "3 ocurrencias del mismo tipo en una sola sesion: reporta patron" \
    "PROCESS-ERROR-PATTERN: no-retry-after-rejection aparecio 3 veces en las ultimas 10 sesiones -- considerar /auto-research"

rm -rf "$FIXTURE_DIR"

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
