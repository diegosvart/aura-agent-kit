#!/usr/bin/env bash
# resolve-tier.Tests.sh — Tests para resolve-tier.sh (Issue #332)
#
# Fixture: un "gh" fake en $PATH que loguea cada invocacion y devuelve JSON fijo para
# "gh issue view --json body" / "--json comments", siguiendo el mismo patron de alta
# fidelidad que cut-release.Tests.sh (write_fake_gh): reconoce explicitamente las unicas
# invocaciones que resolve-tier.sh puede legitimamente hacer y falla ruidosamente ante
# cualquier otra.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resolve-tier.sh"

# write_fake_gh -- fake de "gh" para resolve-tier.sh. Reconoce:
#   - "gh issue view <N> --repo <R> --json body --jq .body" -> imprime $FAKE_BODY
#   - "gh issue view <N> --repo <R> --json comments --jq ..." -> imprime $FAKE_FAIL_COMMENTS
#     (cantidad de comentarios de fallo/bloqueo, ya resuelta -- el jq real filtra y cuenta,
#     el fake devuelve directamente el numero esperado)
# Cualquier otra invocacion falla con exit 1 + mensaje a stderr.
write_fake_gh() {
    local target="$1"
    cat > "$target" << 'FAKE_GH_END'
#!/usr/bin/env bash
echo "$@" >> "$GH_LOG_FILE"

fail() {
    echo "FAKE_GH_ERROR: $1" >&2
    echo "FAKE_GH_ERROR: comando completo recibido: gh $*" >&2
    exit 1
}

if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
    issue_arg="$3"
    if [ "$issue_arg" != "$EXPECTED_ISSUE" ]; then
        fail "gh issue view recibio issue inesperado: '$issue_arg' (esperado '$EXPECTED_ISSUE')"
    fi
    shift 3
    repo_ok=0
    json_field=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)
                shift
                [ "${1:-}" = "$EXPECTED_REPO" ] && repo_ok=1
                ;;
            --json)
                shift
                json_field="${1:-}"
                ;;
            --jq)
                shift
                ;;
        esac
        shift
    done
    if [ "$repo_ok" -ne 1 ]; then
        fail "gh issue view sin --repo '$EXPECTED_REPO' valido"
    fi
    case "$json_field" in
        body)
            printf '%s' "$FAKE_BODY"
            ;;
        comments)
            printf '%s' "$FAKE_FAIL_COMMENTS"
            ;;
        *)
            fail "gh issue view con --json inesperado: '$json_field'"
            ;;
    esac
    exit 0
fi

fail "invocacion de gh no esperada (subcomando no reconocido)"
FAKE_GH_END
    chmod +x "$target"
}

run_resolve_tier() {
    local fixture_dir="$1"
    local fake_bin_dir="$fixture_dir/fake_bin"
    mkdir -p "$fake_bin_dir"
    write_fake_gh "$fake_bin_dir/gh"
    export GH_LOG_FILE="$fixture_dir/gh.log"
    touch "$GH_LOG_FILE"
    export EXPECTED_REPO="fake/repo"
    export EXPECTED_ISSUE="42"
    PATH="$fake_bin_dir:$PATH" "$SCRIPT_PATH" "fake/repo" "42"
}

echo ""
echo "--- Issue con **Complejidad:** alta -> sonnet ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-resolvetier-alta-$$"
mkdir -p "$fixture_dir"
export FAKE_BODY='## Descripcion

**Complejidad:** alta

algo mas'
export FAKE_FAIL_COMMENTS="0"
actual=$(run_resolve_tier "$fixture_dir" 2>"$fixture_dir/stderr.txt")
actual_exit=$?
stderr_out=$(cat "$fixture_dir/stderr.txt" 2>/dev/null || echo "")
rm -rf "$fixture_dir"
if [ "$actual" = "sonnet" ] && [ "$actual_exit" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — Complejidad alta -> sonnet"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — Complejidad alta -> sonnet"
    echo "  Expected: sonnet, exit 0"
    echo "  Got: '$actual', exit $actual_exit, stderr: $stderr_out"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue con **Complejidad:** media -> sonnet (Issue #332) ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-resolvetier-media-$$"
mkdir -p "$fixture_dir"
export FAKE_BODY='## Descripcion

**Complejidad:** media

algo mas'
export FAKE_FAIL_COMMENTS="0"
actual=$(run_resolve_tier "$fixture_dir" 2>"$fixture_dir/stderr.txt")
actual_exit=$?
stderr_out=$(cat "$fixture_dir/stderr.txt" 2>/dev/null || echo "")
rm -rf "$fixture_dir"
if [ "$actual" = "sonnet" ] && [ "$actual_exit" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — Complejidad media -> sonnet"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — Complejidad media -> sonnet"
    echo "  Expected: sonnet, exit 0"
    echo "  Got: '$actual', exit $actual_exit, stderr: $stderr_out"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue sin campo de Complejidad y sin comentarios de fallo -> haiku (default) ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-resolvetier-default-$$"
mkdir -p "$fixture_dir"
export FAKE_BODY='## Descripcion

sin campo de complejidad'
export FAKE_FAIL_COMMENTS="0"
actual=$(run_resolve_tier "$fixture_dir" 2>"$fixture_dir/stderr.txt")
actual_exit=$?
stderr_out=$(cat "$fixture_dir/stderr.txt" 2>/dev/null || echo "")
rm -rf "$fixture_dir"
if [ "$actual" = "haiku" ] && [ "$actual_exit" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — Sin complejidad, sin fallos -> haiku"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — Sin complejidad, sin fallos -> haiku"
    echo "  Expected: haiku, exit 0"
    echo "  Got: '$actual', exit $actual_exit, stderr: $stderr_out"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue sin campo de Complejidad con 2+ comentarios de fallo -> opus (escalamiento reactivo) ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-resolvetier-opus-$$"
mkdir -p "$fixture_dir"
export FAKE_BODY='## Descripcion

sin campo de complejidad'
export FAKE_FAIL_COMMENTS="2"
actual=$(run_resolve_tier "$fixture_dir" 2>"$fixture_dir/stderr.txt")
actual_exit=$?
stderr_out=$(cat "$fixture_dir/stderr.txt" 2>/dev/null || echo "")
rm -rf "$fixture_dir"
if [ "$actual" = "opus" ] && [ "$actual_exit" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} — Sin complejidad, 2+ fallos -> opus"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — Sin complejidad, 2+ fallos -> opus"
    echo "  Expected: opus, exit 0"
    echo "  Got: '$actual', exit $actual_exit, stderr: $stderr_out"
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
