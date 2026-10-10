#!/usr/bin/env bash
# save-plan.Tests.sh — Tests para save-plan.sh (Issue #362)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/save-plan.sh"

# Test 1: Crea el archivo con frontmatter correcto
echo ""
echo "--- Test 1: Crea archivo con frontmatter correcto ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-save-plan-1-$$"
mkdir -p "$fixture_dir"
cd "$fixture_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

content_file="$fixture_dir/test-content.md"
cat > "$content_file" << 'EOF'
## Contexto
Test plan contexto

## Resultado
Test plan resultado
EOF

output=$("$SCRIPT_PATH" "2026-10-10" "test-plan" "362" "$content_file" 2>&1)
exit_code=$?

expected_file="$fixture_dir/.agent/memory/plans/2026-10-10-test-plan.md"
if [ -f "$expected_file" ]; then
    content=$(cat "$expected_file")
    if grep -q "^status: approved$" "$expected_file" && \
       grep -q "^issue: 362$" "$expected_file" && \
       grep -q "^date: 2026-10-10$" "$expected_file"; then
        echo -e "${GREEN}✓ PASS${NC} — archivo creado con frontmatter correcto"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — frontmatter incorrecto"
        echo "Content: $content"
        fail_count=$((fail_count + 1))
    fi
else
    echo -e "${RED}✗ FAIL${NC} — archivo no creado"
    echo "Output: $output"
    fail_count=$((fail_count + 1))
fi
rm -rf "$fixture_dir"

# Test 2: Rechaza slug ya existente sin modificarlo
echo ""
echo "--- Test 2: Rechaza slug existente sin modificar ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-save-plan-2-$$"
mkdir -p "$fixture_dir/.agent/memory/plans"
cd "$fixture_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

# Crear plan existente
existing_file="$fixture_dir/.agent/memory/plans/2026-10-10-existing.md"
echo "old content" > "$existing_file"

content_file="$fixture_dir/test-content.md"
echo "new content" > "$content_file"

output=$("$SCRIPT_PATH" "2026-10-10" "existing" "362" "$content_file" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ] && [ "$(cat "$existing_file")" = "old content" ]; then
    echo -e "${GREEN}✓ PASS${NC} — rechazó slug existente sin modificar"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — no rechazó slug existente o modificó el archivo"
    echo "Exit code: $exit_code, Content: $(cat "$existing_file")"
    fail_count=$((fail_count + 1))
fi
rm -rf "$fixture_dir"

# Test 3: Rechaza fecha inválida
echo ""
echo "--- Test 3: Rechaza fecha inválida ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-save-plan-3-$$"
mkdir -p "$fixture_dir"
cd "$fixture_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

content_file="$fixture_dir/test-content.md"
echo "test" > "$content_file"

output=$("$SCRIPT_PATH" "2026-10" "test-plan" "362" "$content_file" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — rechazó fecha inválida"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — no rechazó fecha inválida"
    fail_count=$((fail_count + 1))
fi
rm -rf "$fixture_dir"

# Test 4: Rechaza slug inválido
echo ""
echo "--- Test 4: Rechaza slug inválido ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-save-plan-4-$$"
mkdir -p "$fixture_dir"
cd "$fixture_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

content_file="$fixture_dir/test-content.md"
echo "test" > "$content_file"

output=$("$SCRIPT_PATH" "2026-10-10" "Test-Plan" "362" "$content_file" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — rechazó slug con mayúsculas"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — no rechazó slug inválido"
    fail_count=$((fail_count + 1))
fi
rm -rf "$fixture_dir"

# Test 5: Rechaza issue no numérico
echo ""
echo "--- Test 5: Rechaza issue no numérico ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-save-plan-5-$$"
mkdir -p "$fixture_dir"
cd "$fixture_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

content_file="$fixture_dir/test-content.md"
echo "test" > "$content_file"

output=$("$SCRIPT_PATH" "2026-10-10" "test-plan" "abc" "$content_file" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — rechazó issue no numérico"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — no rechazó issue no numérico"
    fail_count=$((fail_count + 1))
fi
rm -rf "$fixture_dir"

# Test 6: Rechaza archivo inexistente
echo ""
echo "--- Test 6: Rechaza archivo inexistente ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-save-plan-6-$$"
mkdir -p "$fixture_dir"
cd "$fixture_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

output=$("$SCRIPT_PATH" "2026-10-10" "test-plan" "362" "/nonexistent/file.md" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — rechazó archivo inexistente"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — no rechazó archivo inexistente"
    fail_count=$((fail_count + 1))
fi
rm -rf "$fixture_dir"

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
