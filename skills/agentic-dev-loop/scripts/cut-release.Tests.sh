#!/usr/bin/env bash
# cut-release.Tests.sh — Tests para cut-release.sh (Issue #285, bug #5)
# Bug: el chequeo "if [ $? -ne 0 ]" despues del heredoc de bump de plugin.json es
# inalcanzable bajo `set -euo pipefail` -- un heredoc que falla aborta el script antes de
# llegar a ese chequeo, y el diagnostico "ERROR: Bump de .claude-plugin/plugin.json fallo"
# nunca se imprime.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cut-release.sh"

echo ""
echo "--- Bug #5: bump de plugin.json fallido debe imprimir el diagnostico ERROR y salir 1 ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-cutrelease-$$"
mkdir -p "$fixture_dir"
(
    cd "$fixture_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    git checkout -q -b develop

    printf '%s\n' "## [1.0.0] - 2026-09-15" "- feat: inicial" > CHANGELOG.md
    git add CHANGELOG.md
    git commit -q -m "changelog inicial"

    mkdir -p .claude-plugin
    printf '%s' "{ esto no es json valido" > .claude-plugin/plugin.json
    git add .claude-plugin/plugin.json
    git commit -q -m "plugin.json invalido (fixture)"

    printf '%s\n' "## [1.0.0] - 2026-09-15" "- feat: inicial" "- fix: agregado en el bump" > CHANGELOG.md

    "$SCRIPT_PATH" changelog-pr "fake/repo" "v1.0.0"
) > "$fixture_dir/output.txt" 2>&1
actual_exit_code=$?
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir"

if echo "$output" | grep -qF "ERROR: Bump de .claude-plugin/plugin.json fallo" && [ "$actual_exit_code" -ne 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — diagnostico ERROR se imprime y el script sale con error"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — diagnostico ERROR se imprime y el script sale con error"
    echo "  Expected: output con 'ERROR: Bump de .claude-plugin/plugin.json fallo', exit != 0"
    echo "  Got exit: $actual_exit_code"
    echo "  Got output: $output"
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
