#!/usr/bin/env bash
# cleanup-merged-branch.Tests.sh — Tests para cleanup-merged-branch.sh (Issue #285, bugs #3 y #6)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cleanup-merged-branch.sh"

setup_fake_gh() {
    local bin_dir=$1
    local branch=$2
    cat > "$bin_dir/gh" << FAKE_GH
#!/usr/bin/env bash
if [ "\$1" = "pr" ] && [ "\$2" = "view" ]; then
    for arg in "\$@"; do
        case "\$arg" in
            state) echo "MERGED" ;;
            baseRefName) echo "develop" ;;
            headRefName) echo "$branch" ;;
        esac
    done
    exit 0
fi
exit 1
FAKE_GH
    chmod +x "$bin_dir/gh"
}

# Bug #3 es un unit test sobre el idioma de matching, no sobre el script completo: el
# fallback de contenido (changed_files vacio cuando la rama es ancestro real) enmascara el
# efecto end-to-end del bug en el flujo feliz, pero el patrón de grep sigue siendo incorrecto
# para una rama activa — lo que este test verifica directamente.
echo ""
echo "--- Bug #3: el prefijo de rama activa ('* ') debe matchear igual que el de una no-activa ('  ') ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-bug3-$$"
mkdir -p "$fixture_dir"
(
    cd "$fixture_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    echo base > base.txt
    git add base.txt
    git commit -q -m base
    git branch -q develop
    git checkout -q -b feature-active

    branch="feature-active"
    old_match="no"
    git branch --merged develop | grep -qx "  $branch" && old_match="yes"
    new_match="no"
    git branch --merged develop | sed 's/^[* ] //' | grep -qx "$branch" && new_match="yes"
    echo "old=$old_match new=$new_match"
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir"

expected="old=no new=yes"
uses_fixed_pattern="no"
grep -qF 'sed '"'"'s/^[* ] //'"'"'' "$SCRIPT_PATH" && uses_fixed_pattern="yes"

if [ "$output" = "$expected" ] && [ "$uses_fixed_pattern" = "yes" ]; then
    echo -e "${GREEN}✓ PASS${NC} — patrón viejo no matchea rama activa, patrón nuevo sí, y el script usa el patrón nuevo"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — patrón viejo no matchea rama activa, patrón nuevo sí, y el script usa el patrón nuevo"
    echo "  Expected: $expected (uses_fixed_pattern=yes)"
    echo "  Got:      $output (uses_fixed_pattern=$uses_fixed_pattern)"
    fail_count=$((fail_count + 1))
fi

# Bug #6: contenido DIVERGENTE entre develop y la rama para el archivo con espacio en el
# nombre — el script debe detectar la diferencia real y reportar que NO está mergeada. La
# version con word-splitting pasa "my" y "file.txt" como pathspecs separados, ninguno
# matchea el archivo real "my file.txt", git diff --quiet no encuentra nada que comparar y
# reporta (incorrectamente) que no hay diferencias — falso positivo peligroso: dejaría
# borrar una rama con contenido que en realidad nunca llegó a develop.
echo ""
echo "--- Bug #6: archivo con espacio en el nombre y contenido DIVERGENTE debe detectarse como NO mergeado ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-bug6-$$"
mkdir -p "$fixture_dir/bin"
setup_fake_gh "$fixture_dir/bin" "feature-squash"
(
    cd "$fixture_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    git remote add origin "$(pwd)"
    echo base > base.txt
    git add base.txt
    git commit -q -m base
    git branch -q develop

    git checkout -q -b feature-squash
    echo "contenido de la rama, nunca llego a develop" > "my file.txt"
    git add "my file.txt"
    git commit -q -m "feature commit"

    git checkout -q develop
    echo "contenido distinto en develop" > "my file.txt"
    git add "my file.txt"
    git commit -q -m "otro cambio en develop"

    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "2"
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
actual_exit=$?
rm -rf "$fixture_dir"

if echo "$output" | grep -q "NO aparece como mergeada"; then
    echo -e "${GREEN}✓ PASS${NC} — contenido divergente en archivo con espacio se detecta correctamente (no falso positivo)"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — contenido divergente en archivo con espacio se detecta correctamente"
    echo "  Expected: salida que contenga 'NO aparece como mergeada'"
    echo "  Got:      $output"
    fail_count=$((fail_count + 1))
fi

# Issue #317: el script compara contra la referencia local `develop` en vez de
# `origin/develop`. Cuando la sesion activa corre en un checkout cuyo `develop` local esta
# desactualizado (no se puede `git checkout develop` ahi, ej. un worktree distinto), pero
# `origin/develop` YA tiene el merge (fetcheado), el script reporta un falso negativo: dice
# que la rama NO esta mergeada cuando en realidad si lo esta en el remoto.
echo ""
echo "--- Issue #317: develop local desactualizada respecto a origin/develop con el merge ya aplicado debe detectarse como mergeada ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue317-$$"
mkdir -p "$fixture_dir/bin" "$fixture_dir/origin"
setup_fake_gh "$fixture_dir/bin" "feature-stale-local-develop"
(
    set -e
    cd "$fixture_dir/origin"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    echo base > base.txt
    git add base.txt
    git commit -q -m base
    git branch -q develop

    git checkout -q -b feature-stale-local-develop
    echo "feature change" > feature.txt
    git add feature.txt
    git commit -q -m "feature commit"

    git checkout -q develop
    git merge -q --no-ff feature-stale-local-develop -m "merge feature-stale-local-develop"

    cd "$fixture_dir"
    git clone -q "$fixture_dir/origin" local

    cd "$fixture_dir/local"
    git checkout -q develop
    # Local develop queda desactualizada (antes del merge) aunque origin/develop (ya
    # fetcheado por el clone) SI tiene el merge — este es el escenario real del Issue #317.
    git reset -q --hard HEAD~1
    git branch -q feature-stale-local-develop origin/feature-stale-local-develop

    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "3"
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir"

if echo "$output" | grep -q "está mergeada en develop y lista para borrar"; then
    echo -e "${GREEN}✓ PASS${NC} — develop local desactualizada no genera falso negativo, el script usa origin/develop"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — develop local desactualizada no genera falso negativo, el script usa origin/develop"
    echo "  Expected: salida que contenga 'está mergeada en develop y lista para borrar'"
    echo "  Got:      $output"
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
