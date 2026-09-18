#!/usr/bin/env bash
# parse-pr-number.Tests.sh — Tests para lib/parse-pr-number.sh (Issue #285, bug #8)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

LIB_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/parse-pr-number.sh"
# shellcheck source=./parse-pr-number.sh
source "$LIB_PATH"

run_test() {
    local test_name=$1
    local input=$2
    local expected=$3

    test_count=$((test_count + 1))
    actual=$(printf '%s' "$input" | parse_pr_number)

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        fail_count=$((fail_count + 1))
    fi
}

run_test "URL tipica de gh pr create" \
    "https://github.com/diegosvart/aura-agent-kit/pull/285" \
    "285"

run_test "output con lineas extra antes de la URL" \
    "Creating pull request for feature/issue-285 into develop
https://github.com/diegosvart/aura-agent-kit/pull/285" \
    "285"

run_test "sin URL reconocible devuelve vacio" \
    "algo salio mal, no hay URL aca" \
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
