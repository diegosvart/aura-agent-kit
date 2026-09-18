#!/usr/bin/env bash
# session-report.Tests.sh — Tests para session-report.sh (Issue #265)
#
# TDD: fixtures de sessions.jsonl bajo skills/observability/scripts/fixtures/, nunca tocan
# .agent/memory/observability/ real. El script bajo test lee SESSION_REPORT_INPUT (env var)
# en vez de la ruta real cuando está definida — ver session-report.sh.
#
# Precedente de bug a evitar (Issue #205, mismo dominio de datos): un heredoc de bash sin
# comillas en el delimitador corrompía rutas de Windows con backslashes. session-report.sh
# usa 'EOPYTHON' (comillas simples) igual que process-session.sh — este test no ejercita ese
# path directamente (no arma transcripts), pero corre contra rutas reales de Windows vía
# SESSION_REPORT_INPUT, lo que sí ejercitaría un problema equivalente si existiera.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/session-report.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo -e "${RED}✗ FAIL${NC} — script no encontrado: $SCRIPT_PATH"
    exit 1
fi

# Helper: correr session-report.sh contra un fixture, aseverando que TODOS los patrones
# esperados (uno por línea en $3, separados por el caracter de newline real) aparecen en el
# output, y que el exit code coincide.
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

# --- Test 1: fila sin campo delegation_rate se excluye explícitamente, nunca cuenta como a=0 ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/no-delegation-field.jsonl"
EXTRA_ARGS=()
assert_contains_all \
    "fila sin delegation_rate se excluye del cálculo (no cuenta como a=0)" \
    0 \
    "Filas en el rango SIN campo \`delegation_rate\` (formato pre-migración, excluidas del cálculo): 1" \
    "Filas con a>0 (tamaño de muestra real): 5" \
    "sum(a)=5" \
    "Muestra suficiente"

# --- Test 2: rango con <5 filas con a>0 declara muestra insuficiente ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/small-sample.jsonl"
EXTRA_ARGS=()
assert_contains_all \
    "rango con <5 filas a>0 declara muestra insuficiente y nunca afirma el umbral" \
    0 \
    "MUESTRA INSUFICIENTE" \
    "NO puede evaluarse todavía"

# --- Test 3: rango con >=5 filas a>0 calcula el agregado normal ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=()
assert_contains_all \
    "rango con >=5 filas a>0 calcula agregado y no declara muestra insuficiente" \
    0 \
    "Filas con a>0 (tamaño de muestra real): 5" \
    "Muestra suficiente"

# --- Test 4: --since filtra correctamente ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--since 2026-09-01)
assert_contains_all \
    "--since filtra filas anteriores a la fecha" \
    0 \
    "3 fila(s) incluida(s) de 5 totales"

# --- Test 5: --since-session filtra correctamente (inclusive) ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--since-session u3)
assert_contains_all \
    "--since-session filtra desde el session_id dado (inclusive)" \
    0 \
    "3 fila(s) incluida(s) de 5 totales"

# --- Test 6: --since y --since-session son mutuamente excluyentes ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--since 2026-09-01 --since-session u3)
assert_contains_all \
    "--since y --since-session juntos fallan explícitamente" \
    1 \
    "mutuamente excluyentes"

# --- Test 7: --since-session con id inexistente falla explícito, no en silencio ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/since-filter.jsonl"
EXTRA_ARGS=(--since-session no-existe)
assert_contains_all \
    "--since-session con id inexistente falla explícitamente" \
    1 \
    "no encontrado"

# --- Test 8: distribución de tool_uses se expresa como proporciones (%) ---
export SESSION_REPORT_INPUT="$FIXTURES_DIR/no-delegation-field.jsonl"
EXTRA_ARGS=()
assert_contains_all \
    "distribución de tool_uses incluye proporciones porcentuales" \
    0 \
    "Distribución de tool_uses (proporciones)" \
    "%)"

unset SESSION_REPORT_INPUT

echo ""
echo "Total: $test_count, Pass: $pass_count, Fail: $fail_count"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
