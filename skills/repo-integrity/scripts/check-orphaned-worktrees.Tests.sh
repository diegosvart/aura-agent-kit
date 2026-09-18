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

echo ""
echo "--- Issue #318: worktree huerfano por lock muerto debe anexar diagnostico JSONL ---"
test_count=$((test_count + 1))

fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue318-$$"
mkdir -p "$fixture_dir"
(
    set -e
    cd "$fixture_dir"
    git init -q main
    cd main
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    echo base > base.txt
    git add base.txt
    git commit -q -m base
    git branch -q develop

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
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
