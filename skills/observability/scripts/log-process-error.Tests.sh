#!/usr/bin/env bash
# log-process-error.Tests.sh — Tests para log-process-error.sh (Issue #206, idea [021])
# TDD: este archivo se escribe ANTES de que exista log-process-error.sh. Se espera que TODOS
# los tests fallen hasta que el script se implemente (fase RED).
#
# Contrato bajo test:
#   Uso: log-process-error.sh <owner>/<repo> <tipo> "<descripcion>" ["<afectado>"]
#   Taxonomia cerrada de <tipo>: branch-wrong-base | merge-order | no-retry-after-rejection | other
#   Efecto: appendea una linea JSON a .agent/memory/observability/process-errors.jsonl
#   (relativo a la raiz del repo, creando el directorio si no existe) con el schema:
#     {"logged_at","session_id","tipo","descripcion","afectado","corregido"}
#   - logged_at: timestamp ISO 8601 UTC
#   - session_id: de $CLAUDE_SESSION_ID si esta seteado, si no "unknown"
#   - afectado: "" si no se paso el 4to argumento
#   - corregido: true (siempre — el script se invoca en el momento en que ya se corrigio)
#   Exit code 0 en éxito, 1 con mensaje de error claro si <tipo> no está en la taxonomía
#   cerrada o si faltan argumentos obligatorios.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log-process-error.sh"

setup_fixture_repo() {
    local dir=$1
    mkdir -p "$dir"
    (
        cd "$dir"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
    )
}

assert_eq() {
    local test_name=$1
    local expected=$2
    local actual=$3

    test_count=$((test_count + 1))
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        fail_count=$((fail_count + 1))
    fi
}

assert_exit_code() {
    local test_name=$1
    local expected_code=$2
    local actual_code=$3

    test_count=$((test_count + 1))
    if [ "$expected_code" = "$actual_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected exit code: $expected_code"
        echo "  Got:                $actual_code"
        fail_count=$((fail_count + 1))
    fi
}

FIXTURE_DIR="$(dirname "$SCRIPT_PATH")/.tmp-test-fixture-log-process-error-$$"
setup_fixture_repo "$FIXTURE_DIR"
JSONL="$FIXTURE_DIR/.agent/memory/observability/process-errors.jsonl"

# --- Test 1: tipo valido con afectado -> appendea linea con schema completo -----------------
output=$(cd "$FIXTURE_DIR" && CLAUDE_SESSION_ID="sess-123" bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "branch-wrong-base" "descripcion de prueba" "feature/x" 2>&1)
exit_code=$?
assert_exit_code "tipo valido con afectado: exit 0" "0" "$exit_code"

line=$(tail -1 "$JSONL" 2>/dev/null)
tipo=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['tipo'])" 2>/dev/null)
assert_eq "tipo valido con afectado: campo tipo correcto" "branch-wrong-base" "$tipo"

session_id=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['session_id'])" 2>/dev/null)
assert_eq "tipo valido con afectado: session_id desde CLAUDE_SESSION_ID" "sess-123" "$session_id"

afectado=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['afectado'])" 2>/dev/null)
assert_eq "tipo valido con afectado: campo afectado correcto" "feature/x" "$afectado"

corregido=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['corregido'])" 2>/dev/null)
assert_eq "tipo valido con afectado: corregido siempre true" "True" "$corregido"

descripcion=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['descripcion'])" 2>/dev/null)
assert_eq "tipo valido con afectado: descripcion correcta" "descripcion de prueba" "$descripcion"

logged_at=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['logged_at'])" 2>/dev/null)
test_count=$((test_count + 1))
if [[ "$logged_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    echo -e "${GREEN}✓ PASS${NC} — tipo valido con afectado: logged_at es timestamp ISO 8601"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — tipo valido con afectado: logged_at es timestamp ISO 8601"
    echo "  Got: $logged_at"
    fail_count=$((fail_count + 1))
fi

# --- Test 2: sin afectado -> campo afectado vacio, sin CLAUDE_SESSION_ID -> "unknown" -------
rm -f "$JSONL"
output=$(cd "$FIXTURE_DIR" && unset CLAUDE_SESSION_ID; cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "merge-order" "otra descripcion" 2>&1)
exit_code=$?
assert_exit_code "sin afectado: exit 0" "0" "$exit_code"

line=$(tail -1 "$JSONL" 2>/dev/null)
afectado=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['afectado'])" 2>/dev/null)
assert_eq "sin afectado: campo afectado vacio" "" "$afectado"

session_id=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['session_id'])" 2>/dev/null)
assert_eq "sin afectado: session_id default 'unknown' sin CLAUDE_SESSION_ID" "unknown" "$session_id"

# --- Test 3: tipo fuera de la taxonomia cerrada -> rechazo claro, exit 1, sin appendear -----
rm -f "$JSONL"
output=$(cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "tipo-inventado" "descripcion" 2>&1)
exit_code=$?
assert_exit_code "tipo fuera de taxonomia: exit 1" "1" "$exit_code"

test_count=$((test_count + 1))
if echo "$output" | grep -qi "tipo-inventado"; then
    echo -e "${GREEN}✓ PASS${NC} — tipo fuera de taxonomia: mensaje de error menciona el tipo rechazado"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — tipo fuera de taxonomia: mensaje de error menciona el tipo rechazado"
    echo "  Got: $output"
    fail_count=$((fail_count + 1))
fi

test_count=$((test_count + 1))
if [ ! -f "$JSONL" ]; then
    echo -e "${GREEN}✓ PASS${NC} — tipo fuera de taxonomia: no se appendea nada al jsonl"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — tipo fuera de taxonomia: no se appendea nada al jsonl"
    fail_count=$((fail_count + 1))
fi

# --- Test 4: tipo 'other' es valido (parte de la taxonomia cerrada) -------------------------
rm -f "$JSONL"
output=$(cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "other" "descripcion libre obligatoria" 2>&1)
exit_code=$?
assert_exit_code "tipo 'other': exit 0" "0" "$exit_code"

# --- Test 5: faltan argumentos obligatorios -> exit 1 ---------------------------------------
output=$(cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "branch-wrong-base" 2>&1)
exit_code=$?
assert_exit_code "falta descripcion obligatoria: exit 1" "1" "$exit_code"

# --- Test 6: segunda invocacion appendea (no sobreescribe) ----------------------------------
rm -f "$JSONL"
cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "branch-wrong-base" "primero" >/dev/null 2>&1
cd "$FIXTURE_DIR" && bash "$SCRIPT_PATH" "diegosvart/aura-agent-kit" "merge-order" "segundo" >/dev/null 2>&1
line_count=$(wc -l < "$JSONL" 2>/dev/null | tr -d ' ')
assert_eq "invocaciones sucesivas appendean, no sobreescriben" "2" "$line_count"

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
