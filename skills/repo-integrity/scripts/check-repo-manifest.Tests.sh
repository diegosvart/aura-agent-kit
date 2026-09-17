#!/usr/bin/env bash
# check-repo-manifest.Tests.sh — Tests para check-repo-manifest.sh (Issue #298)
# Cubre el chequeo de regresion nuevo: ningun CLAUDE.md fuera de la raiz del repo, excepto
# dentro de ./.aura/* (submodule fuente completo cuando el repo actua como Rol B consumidor).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-repo-manifest.sh"

# Fixture minima: git repo temporal con manifest.txt vacio (el script exige que exista el
# manifest para no salir temprano en la linea `[ -f "$MANIFEST" ] || exit 0`) mas los archivos
# CLAUDE.md que cada caso necesite.
run_test() {
    local test_name=$1
    local extra_claude_md_paths=$2  # lineas separadas por \n, vacio = ninguno
    local expected_grep=$3          # patron esperado en la salida (grep -F), vacio = salida vacia

    test_count=$((test_count + 1))

    local fixture_dir
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-fixture-$$-$test_count"
    mkdir -p "$fixture_dir/skills/repo-integrity"
    mkdir -p "$fixture_dir/.aura"

    : > "$fixture_dir/skills/repo-integrity/manifest.txt"
    echo "raiz" > "$fixture_dir/CLAUDE.md"
    echo "submodule" > "$fixture_dir/.aura/CLAUDE.md"  # nunca debe reportarse — excluido a proposito

    if [ -n "$extra_claude_md_paths" ]; then
        while IFS= read -r p; do
            [ -z "$p" ] && continue
            mkdir -p "$fixture_dir/$(dirname "$p")"
            echo "stray" > "$fixture_dir/$p"
        done <<< "$extra_claude_md_paths"
    fi

    (
        cd "$fixture_dir"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git config core.autocrlf false
        git add -A
        git commit -q -m "fixture"
        "$SCRIPT_PATH"
    ) > "$fixture_dir/output.txt" 2>&1
    output=$(cat "$fixture_dir/output.txt")
    rm -rf "$fixture_dir"

    local ok=1
    if [ -z "$expected_grep" ]; then
        [ -z "$output" ] || ok=0
    else
        echo "$output" | grep -qF "$expected_grep" || ok=0
    fi

    if [ "$ok" -eq 1 ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected (grep -F): ${expected_grep:-<salida vacia>}"
        echo "  Got:      $output"
        fail_count=$((fail_count + 1))
    fi
}

run_test "sin CLAUDE.md fuera de raiz (solo raiz + .aura excluido) -> salida limpia" \
"" \
""

run_test "CLAUDE.md fuera de la raiz -> reportado" \
"sub/CLAUDE.md" \
"MISPLACED: sub/CLAUDE.md"

run_test "CLAUDE.md dentro de .aura/anidado -> excluido, no reportado" \
".aura/nested/CLAUDE.md" \
""

run_test "CLAUDE.md dentro de integrations/claude-code -> excluido, no reportado" \
"integrations/claude-code/CLAUDE.md" \
""

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
