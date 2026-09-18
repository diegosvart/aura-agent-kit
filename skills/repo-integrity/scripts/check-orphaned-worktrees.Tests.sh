#!/usr/bin/env bash
# check-orphaned-worktrees.Tests.sh — Tests para check-orphaned-worktrees.sh (Issue #318)
#
# Cubre el requisito de instrumentacion: cuando el script clasifica un worktree como
# huerfano por lock muerto, ademas de la linea ORPHANED-WORKTREE de siempre debe anexar una
# linea JSONL a .agent/memory/observability/worktree-orphan-diagnostics.jsonl con el reason
# crudo, el PID extraido y la salida cruda de tasklist para ese PID. Sin cambios de
# comportamiento en la deteccion existente (solo lectura + append).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-orphaned-worktrees.sh"

setup_fixture_repo() {
    git init -q main
    cd main
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    echo base > base.txt
    git add base.txt
    git commit -q -m base
    git branch -q develop
}

echo ""
echo "--- Issue #318: worktree huerfano por lock muerto debe anexar diagnostico JSONL ---"
test_count=$((test_count + 1))

fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue318-$$"
mkdir -p "$fixture_dir"
(
    set -e
    cd "$fixture_dir"
    setup_fixture_repo

    # Worktree secundario con lock "muerto" -- reason trae un PID que no corre en esta
    # maquina (999999), simulando una sesion que murio sin liberar el lock.
    git worktree add -q -b wt-branch "../wt" >/dev/null 2>&1
    git worktree lock "../wt" --reason "pid 999999 session-dead" >/dev/null 2>&1

    "$SCRIPT_PATH" > orphan-output.txt 2>&1

    diag_file=".agent/memory/observability/worktree-orphan-diagnostics.jsonl"
    if [ -f "$diag_file" ]; then
        cat "$diag_file" > diag-output.txt
    else
        echo "NO-DIAG-FILE" > diag-output.txt
    fi
    cat orphan-output.txt
    echo "---DIAG---"
    cat diag-output.txt
) > "$fixture_dir/combined-output.txt" 2>&1
output=$(cat "$fixture_dir/combined-output.txt")
rm -rf "$fixture_dir"

has_orphan_line="no"
echo "$output" | grep -q "ORPHANED-WORKTREE:" && has_orphan_line="yes"

has_diag_line="no"
echo "$output" | grep -q '"reason".*999999' && has_diag_line="yes"

has_pid_field="no"
echo "$output" | grep -q '"pid": "999999"' && has_pid_field="yes"

has_tasklist_field="no"
echo "$output" | grep -q '"tasklist_output"' && has_tasklist_field="yes"

if [ "$has_orphan_line" = "yes" ] && [ "$has_diag_line" = "yes" ] && [ "$has_pid_field" = "yes" ] && [ "$has_tasklist_field" = "yes" ]; then
    echo -e "${GREEN}✓ PASS${NC} — worktree huerfano detectado y diagnostico JSONL anexado con reason/pid/tasklist_output"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — worktree huerfano detectado y diagnostico JSONL anexado con reason/pid/tasklist_output"
    echo "  orphan_line=$has_orphan_line diag_line=$has_diag_line pid_field=$has_pid_field tasklist_field=$has_tasklist_field"
    echo "  Got:"
    echo "$output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Regresion: diagnostico de un worktree sin PID no debe arrastrar tasklist de otro worktree previo ---"
test_count=$((test_count + 1))

fixture_dir2="$(dirname "$SCRIPT_PATH")/.tmp-test-issue318-stale-$$"
mkdir -p "$fixture_dir2"
(
    set -e
    cd "$fixture_dir2"
    setup_fixture_repo

    # Worktree A: lock con PID vivo (el propio PID de este proceso de test) -- pid_alive()
    # corre tasklist para $$ y lo cachea, luego el script hace "continue" sin loggear.
    git worktree add -q -b wt-a-branch "../wt-a" >/dev/null 2>&1
    git worktree lock "../wt-a" --reason "pid $$ session-alive" >/dev/null 2>&1

    # Worktree B: lock sin PID extraible en el reason -- pid_alive() nunca se llama para B.
    # Si LAST_TASKLIST_OUTPUT no se resetea por iteracion, el diagnostico de B queda con la
    # salida de tasklist que en realidad pertenece al proceso de A.
    git worktree add -q -b wt-b-branch "../wt-b" >/dev/null 2>&1
    git worktree lock "../wt-b" --reason "session-dead-sin-pid" >/dev/null 2>&1

    "$SCRIPT_PATH" > orphan-output.txt 2>&1

    diag_file=".agent/memory/observability/worktree-orphan-diagnostics.jsonl"
    if [ -f "$diag_file" ]; then
        cat "$diag_file" > diag-output.txt
    else
        echo "NO-DIAG-FILE" > diag-output.txt
    fi
    echo "---DIAG---"
    cat diag-output.txt
) > "$fixture_dir2/combined-output.txt" 2>&1
output2=$(cat "$fixture_dir2/combined-output.txt")
rm -rf "$fixture_dir2"

# La linea de diagnostico de B es la que trae "session-dead-sin-pid" en el reason -- ahi es
# donde debe quedar pid vacio y tasklist_output vacio (nunca arrastrar la salida de A, vivo
# o no segun tasklist en este entorno -- eso es incidental, no lo que se prueba aca).
b_diag_line=$(echo "$output2" | grep '"reason": "session-dead-sin-pid"')

b_pid_empty="no"
echo "$b_diag_line" | grep -q '"pid": ""' && b_pid_empty="yes"

b_tasklist_empty="no"
echo "$b_diag_line" | grep -q '"tasklist_output": ""' && b_tasklist_empty="yes"

if [ -n "$b_diag_line" ] && [ "$b_pid_empty" = "yes" ] && [ "$b_tasklist_empty" = "yes" ]; then
    echo -e "${GREEN}✓ PASS${NC} — diagnostico sin PID no arrastra tasklist_output de un worktree previo"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — diagnostico sin PID no arrastra tasklist_output de un worktree previo"
    echo "  b_diag_line_found=$([ -n "$b_diag_line" ] && echo yes || echo no) pid_empty=$b_pid_empty tasklist_empty=$b_tasklist_empty"
    echo "  Got:"
    echo "$output2"
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
