#!/usr/bin/env bash
# loop-summary.Tests.sh — Tests para loop-summary.sh (Issue #304, Modo 3)
#
# TDD: fixtures de sessions.jsonl bajo skills/observability/scripts/fixtures/, nunca tocan
# .agent/memory/observability/ real. El script bajo test lee LOOP_SUMMARY_INPUT (env var) en
# vez de la ruta real cuando está definida — mismo patrón que session-report.sh
# (SESSION_REPORT_INPUT) y process-session.sh (Issue #205: heredoc sin comillas en el
# delimitador corrompe rutas de Windows con backslashes — este script usa 'EOPYTHON' también).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/loop-summary.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo -e "${RED}✗ FAIL${NC} — script no encontrado: $SCRIPT_PATH"
    exit 1
fi

assert_contains_all() {
    local test_name=$1
    local expected_exit_code=$2
    shift 2
    local -a expected_patterns=("$@")

    test_count=$((test_count + 1))

    local output
    output=$(bash "$SCRIPT_PATH" "${EXTRA_ARGS[@]}" 2>&1)
    local actual_exit_code=$?

    local ok=1
    if [[ "$actual_exit_code" != "$expected_exit_code" ]]; then
        ok=0
    fi
    for pattern in "${expected_patterns[@]}"; do
        if ! grep -qF "$pattern" <<< "$output"; then
            ok=0
        fi
    done

    if [[ $ok -eq 1 ]]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected exit code: $expected_exit_code, got: $actual_exit_code"
        echo "  Expected to contain (each of):"
        printf '    %s\n' "${expected_patterns[@]}"
        echo "  Got output:"
        echo "$output" | sed 's/^/    /'
        fail_count=$((fail_count + 1))
    fi
}

# --- Test 1: --session-ids selecciona exactamente las sesiones pedidas, en cualquier orden ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u4,u2)
assert_contains_all \
    "--session-ids selecciona exactamente las sesiones pedidas" \
    0 \
    "2 sesion(es) incluida(s) de 5 totales" \
    "u2" \
    "u4"

# --- Test 2: tokens totales y duración total se agregan correctamente ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u1,u2)
assert_contains_all \
    "tokens y duración se suman (no promedian) sobre las sesiones incluidas" \
    0 \
    "tokens totales: 30000" \
    "duración total: 300000 ms"

# --- Test 3: tool_uses por categoría se agrega sobre las sesiones incluidas ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u1,u2)
assert_contains_all \
    "tool_uses por categoría agregado" \
    0 \
    "llm: 5" \
    "script_command: 5"

# --- Test 4: delegation_rate agregado sobre las sesiones incluidas ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u3,u4,u5)
assert_contains_all \
    "delegation_rate agregado sobre las sesiones incluidas" \
    0 \
    "sum(b)=3" \
    "sum(a)=3"

# --- Test 5: --since selecciona por rango de tiempo, como alternativa a --session-ids ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--since 2026-09-10)
assert_contains_all \
    "--since selecciona por rango de tiempo" \
    0 \
    "3 sesion(es) incluida(s) de 5 totales"

# --- Test 6: --session-ids y --since son mutuamente excluyentes ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u1,u2 --since 2026-09-01)
assert_contains_all \
    "--session-ids y --since juntos fallan explícitamente" \
    1 \
    "mutuamente excluyentes"

# --- Test 7: session_id inexistente en --session-ids falla explícito, no en silencio ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u1,no-existe)
assert_contains_all \
    "session_id inexistente en --session-ids falla explícitamente" \
    1 \
    "no encontrado(s)" \
    "no-existe"

# --- Test 8: listado por sesión incluye el session_id y marca el resultado como no rastreado ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--session-ids u1)
assert_contains_all \
    "listado por sesión incluye session_id y nota de resultado no disponible" \
    0 \
    "### Sesiones incluidas" \
    "u1" \
    "resultado: no disponible en sessions.jsonl"

# --- Test 9: sin --session-ids ni --since, procesa todas las filas ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=()
assert_contains_all \
    "sin flags, procesa todas las filas" \
    0 \
    "5 sesion(es) incluida(s) de 5 totales"

# --- Test 10: archivo de entrada inexistente sale limpio (exit 0, sin datos) ---
export LOOP_SUMMARY_INPUT="$FIXTURES_DIR/no-existe-este-archivo.jsonl"
EXTRA_ARGS=()
assert_contains_all \
    "archivo de entrada inexistente sale limpio sin datos" \
    0 \
    "sin datos"

unset LOOP_SUMMARY_INPUT

echo ""
echo "Total: $test_count, Pass: $pass_count, Fail: $fail_count"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
