#!/usr/bin/env bash
# save-plan.Tests.sh — Tests para save-plan.sh (Issue #362)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/save-plan.sh"
ORIG_CWD="$(pwd)"
FIXTURES=()

cleanup() {
    cd "$ORIG_CWD" 2>/dev/null || true
    for d in "${FIXTURES[@]:-}"; do
        [ -n "$d" ] && rm -rf "$d"
    done
}
trap cleanup EXIT

new_repo() {
    local d
    d="$(mktemp -d "$SCRIPT_DIR/.tmp-test-save-plan-XXXXXX")"
    FIXTURES+=("$d")
    git -C "$d" init -q
    NEW_REPO="$d"
}

check() {
    test_count=$((test_count + 1))
    if [ "$2" = "0" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $1"; pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $1"; fail_count=$((fail_count + 1))
        [ -n "${3:-}" ] && echo "    detalle: $3"
    fi
}

# expect_error <descripcion> <patron-en-salida> <fecha> <slug> <issue> <archivo>
expect_error() {
    local desc="$1" pattern="$2"; shift 2
    local out rc
    out=$(bash "$SCRIPT_PATH" "$@" 2>&1); rc=$?
    if [ $rc -ne 0 ] && printf '%s' "$out" | grep -q -- "$pattern"; then
        check "$desc" 0
    else
        check "$desc" 1 "rc=$rc out=$out"
    fi
}

new_repo; R="$NEW_REPO"; cd "$R"
printf 'test\n' > content.md

echo "--- Camino feliz ---"
printf '## Contexto\nplan\n\n\n' > happy.md
out=$(bash "$SCRIPT_PATH" 2026-10-10 test-plan 362 happy.md 2>"$R/err.txt"); rc=$?
f="$R/.agent/memory/plans/2026-10-10-test-plan.md"
check "exit 0 y archivo creado" "$([ $rc -eq 0 ] && [ -f "$f" ]; echo $?)" "rc=$rc out=$out"
check "frontmatter correcto" "$(grep -q '^status: approved$' "$f" && grep -q '^issue: 362$' "$f" && grep -q '^date: 2026-10-10$' "$f"; echo $?)"
check "preserva saltos finales del contenido" "$([ "$(tail -c 3 "$f" | od -An -c | tr -d ' ')" = '\n\n\n' ]; echo $?)"
check "stderr recuerda barrido de datos sensibles" "$(grep -q 'sensitive-data-safety' "$R/err.txt"; echo $?)"

echo "--- Fechas imposibles ---"
expect_error "rechaza 2026-13-45" "fecha" 2026-13-45 p1 362 content.md
expect_error "rechaza 2026-02-30" "fecha" 2026-02-30 p2 362 content.md
expect_error "rechaza 2026-00-10" "fecha" 2026-00-10 p3 362 content.md
expect_error "rechaza 2026-04-31" "fecha" 2026-04-31 p4 362 content.md
expect_error "rechaza 2026-10" "fecha" 2026-10 p5 362 content.md
out=$(bash "$SCRIPT_PATH" 2024-02-29 bisiesto 362 content.md 2>&1); check "acepta 2024-02-29 (bisiesto)" "$?" "$out"
expect_error "rechaza 2026-02-29 (no bisiesto)" "fecha" 2026-02-29 p6 362 content.md
out=$(bash "$SCRIPT_PATH" 2000-02-29 siglo400 362 content.md 2>&1); check "acepta 2000-02-29" "$?" "$out"
expect_error "rechaza 1900-02-29" "fecha" 1900-02-29 p7 362 content.md

echo "--- Otras validaciones ---"
expect_error "rechaza slug con mayusculas" "slug" 2026-10-10 Test-Plan 362 content.md
expect_error "rechaza issue no numerico" "issue" 2026-10-10 test-plan abc content.md
expect_error "rechaza archivo inexistente" "no existe" 2026-10-10 test-plan 362 /nonexistent/file.md

echo "--- Sobreescritura ---"
mkdir -p "$R/.agent/memory/plans"
echo "old content" > "$R/.agent/memory/plans/2026-10-10-existing.md"
expect_error "rechaza slug existente" "ya existe" 2026-10-10 existing 362 content.md
check "no modifica el existente" "$([ "$(cat "$R/.agent/memory/plans/2026-10-10-existing.md")" = "old content" ]; echo $?)"
mkdir -p "$R/.agent/memory/plans/2026-10-10-dir.md"
expect_error "rechaza destino que es un directorio" "ya existe" 2026-10-10 dir 362 content.md

echo "--- Fuera de repo git ---"
NR="$(mktemp -d)"; FIXTURES+=("$NR"); cd "$NR"
printf 'x\n' > c.md
expect_error "mensaje propio fuera de repo git" "repositorio git" 2026-10-10 test-plan 362 c.md

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

[ $fail_count -eq 0 ]
