#!/usr/bin/env bash
# extract-changelog-section.Tests.sh — Tests para extract-changelog-section.sh (Issue #285, bug #1)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/extract-changelog-section.sh"

run_test() {
    local test_name=$1
    local version_tag=$2
    local changelog_content=$3
    local expected_output=$4
    local expected_exit_code=${5:-0}

    test_count=$((test_count + 1))

    local fixture_dir
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-fixture-$$"
    mkdir -p "$fixture_dir"
    printf '%s' "$changelog_content" > "$fixture_dir/CHANGELOG.md"

    output=$("$SCRIPT_PATH" "$version_tag" "$fixture_dir/CHANGELOG.md" 2>&1)
    actual_exit_code=$?
    rm -rf "$fixture_dir"

    if [ "$output" = "$expected_output" ] && [ "$actual_exit_code" = "$expected_exit_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected output: $expected_output"
        echo "  Got output:      $output"
        echo "  Expected exit code: $expected_exit_code, got: $actual_exit_code"
        fail_count=$((fail_count + 1))
    fi
}

run_test "tag con prefijo v matchea header sin v" \
    "v2.7.0" \
    "## [2.7.0] - 2026-09-14
  - feat: algo nuevo

## [2.6.0] - 2026-08-01
  - feat: algo viejo
" \
    "    - feat: algo nuevo" \
    0

run_test "tag sin prefijo v matchea header sin v" \
    "2.7.0" \
    "## [2.7.0] - 2026-09-14
  - feat: algo nuevo
" \
    "    - feat: algo nuevo" \
    0

run_test "tag sin entrada correspondiente reporta mensaje" \
    "v9.9.9" \
    "## [2.7.0] - 2026-09-14
  - feat: algo nuevo
" \
    "  (No hay entradas para v9.9.9 en CHANGELOG.md)" \
    0

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
