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
echo "--- Issue #344: --delete debe usar origin/develop en vez de develop local stale ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue344-$$"
mkdir -p "$fixture_dir/bin" "$fixture_dir/origin"
setup_fake_gh "$fixture_dir/bin" "feature-delete-stale"
(
    set -e
    # Configurar repositorio remoto (origin)
    cd "$fixture_dir/origin"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    echo base > base.txt
    git add base.txt
    git commit -q -m base
    git branch -q develop

    # Crear rama de feature y mergearla en origin/develop
    git checkout -q -b feature-delete-stale
    echo "feature content" > feature.txt
    git add feature.txt
    git commit -q -m "feature commit"

    git checkout -q develop
    git merge -q --no-ff feature-delete-stale -m "merge feature-delete-stale"

    # Clonar a local
    cd "$fixture_dir"
    git clone -q "$fixture_dir/origin" local

    cd "$fixture_dir/local"
    # Crear rama local desde origin
    git checkout -q -b feature-delete-stale origin/feature-delete-stale

    # Resetear develop local para que esté stale
    git checkout -q develop
    git reset -q --hard HEAD~1

    # Volver a la rama feature para simular el escenario real
    git checkout -q feature-delete-stale

    # Ahora origin/develop tiene el merge pero develop local no
    # Cuando el script hace git checkout origin/develop, debería funcionar correctamente

    # Ejecutar el script con --delete
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "4" --delete

    # Hallazgo 3 (PR #350): el script debe dejar el checkout en una rama real, nunca en
    # detached HEAD, en el caso comun (no-worktree). `git symbolic-ref -q HEAD` tiene exito
    # solo si HEAD apunta a una rama (falla en detached HEAD).
    if git symbolic-ref -q HEAD > /dev/null; then
        echo "HEAD_DETACHED=no"
    else
        echo "HEAD_DETACHED=yes"
    fi
    echo "CURRENT_BRANCH=$(git branch --show-current)"
) > "$fixture_dir/output.txt" 2>&1
# Capturar el exit code del subshell INMEDIATAMENTE -- Hallazgo 2 (PR #350): leerlo despues de
# `cat` captura el exit code de `cat`, no el del subshell, y la aserción de abajo queda muerta
# (siempre 0).
actual_exit=$?
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir"

if [ $actual_exit -eq 0 ] \
    && echo "$output" | grep -q "Rama local 'feature-delete-stale' borrada" \
    && echo "$output" | grep -q "HEAD_DETACHED=no" \
    && echo "$output" | grep -q "CURRENT_BRANCH=develop"; then
    echo -e "${GREEN}✓ PASS${NC} — --delete usa origin/develop, rama borrada exitosamente, y el checkout queda en 'develop' (no detached HEAD)"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — --delete debe usar origin/develop cuando develop local está stale, y dejar el checkout en 'develop' (no detached HEAD)"
    echo "  Expected: salida con 'Rama local' ... 'borrada', HEAD_DETACHED=no, CURRENT_BRANCH=develop"
    echo "  Got:      $output (exit=$actual_exit)"
    fail_count=$((fail_count + 1))
fi

# Issue #353: `git branch -d` compara ancestria, asi que rechaza una rama squash-mergeada aunque
# la validacion de contenido del script ya la haya certificado. Fixture: origin con develop y la
# rama; `mode` = squash (un commit nuevo en develop, la rama original nunca entra) o merge (--no-ff).
# Deja la rama local checkouteada en develop, sin rama remota (auto-delete de GitHub) y devuelve
# en $fixture_dir/branch_sha el SHA original de la rama.
build_353_fixture() {
    local fixture_dir=$1 branch=$2 mode=$3
    mkdir -p "$fixture_dir/bin" "$fixture_dir/origin"
    setup_fake_gh "$fixture_dir/bin" "$branch"
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
        git branch -q -M develop
        git checkout -q -b "$branch"
        echo "feature content" > feature.txt
        git add feature.txt
        git commit -q -m "feature commit"
        git rev-parse HEAD > "$fixture_dir/branch_sha"
        git checkout -q develop
        if [ "$mode" = "squash" ]; then
            git merge -q --squash "$branch"
            git commit -q -m "feat: squash de $branch"
        else
            git merge -q --no-ff "$branch" -m "merge $branch"
        fi
        cd "$fixture_dir"
        git clone -q "$fixture_dir/origin" local
        cd "$fixture_dir/local"
        git config user.email "test@example.com"
        git config user.name "Test User"
        git checkout -q -b "$branch" "origin/$branch"
        git checkout -q develop
        git -C "$fixture_dir/origin" branch -q -D "$branch"
        git fetch -q --prune origin
    )
}

echo ""
echo "--- Issue #353: --delete borra una rama squash-mergeada sin rama remota y avisa con el SHA original ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-squash-$$"
build_353_fixture "$fixture_dir" "feature-squash-353" "squash" > "$fixture_dir.setup.txt" 2>&1
original_sha=$(cat "$fixture_dir/branch_sha" 2>/dev/null)
(
    cd "$fixture_dir/local"
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "5" --delete
    echo "EXIT=$?"
    if git show-ref --verify --quiet "refs/heads/feature-squash-353"; then echo "BRANCH_EXISTS=yes"; else echo "BRANCH_EXISTS=no"; fi
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir" "$fixture_dir.setup.txt"

if echo "$output" | grep -q "BRANCH_EXISTS=no" \
    && echo "$output" | grep -q "EXIT=0" \
    && echo "$output" | grep -q "AVISO: rama squash-mergeada" \
    && [ -n "$original_sha" ] && echo "$output" | grep -q "$original_sha"; then
    echo -e "${GREEN}✓ PASS${NC} — squash + remota borrada: rama borrada, AVISO con el SHA original"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — squash + remota borrada: rama borrada, AVISO con el SHA original"
    echo "  Expected: BRANCH_EXISTS=no, EXIT=0, 'AVISO: rama squash-mergeada' y el SHA $original_sha"
    echo "  Got:      $output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue #353: merge real se borra con -d, sin pasar por el camino -D ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-merge-$$"
build_353_fixture "$fixture_dir" "feature-merge-353" "merge" > "$fixture_dir.setup.txt" 2>&1
(
    cd "$fixture_dir/local"
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "6" --delete
    echo "EXIT=$?"
    if git show-ref --verify --quiet "refs/heads/feature-merge-353"; then echo "BRANCH_EXISTS=yes"; else echo "BRANCH_EXISTS=no"; fi
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir" "$fixture_dir.setup.txt"

if echo "$output" | grep -q "BRANCH_EXISTS=no" \
    && echo "$output" | grep -q "EXIT=0" \
    && ! echo "$output" | grep -q "AVISO: rama squash-mergeada"; then
    echo -e "${GREEN}✓ PASS${NC} — merge real: borrada con -d, sin AVISO de -D"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — merge real: borrada con -d, sin AVISO de -D"
    echo "  Expected: BRANCH_EXISTS=no, EXIT=0 y sin 'AVISO: rama squash-mergeada'"
    echo "  Got:      $output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue #353 (seguridad): contenido divergente NO se borra ni con -d ni con -D ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-diverge-$$"
build_353_fixture "$fixture_dir" "feature-diverge-353" "squash" > "$fixture_dir.setup.txt" 2>&1
(
    cd "$fixture_dir/local"
    git checkout -q develop
    echo "contenido distinto, nunca mergeado" > feature.txt
    git add feature.txt
    git commit -q -m "divergencia en develop local"
    git checkout -q feature-diverge-353
    echo "trabajo extra sin mergear" >> feature.txt
    git add feature.txt
    git commit -q -m "trabajo extra en la rama"
    git checkout -q develop
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "7" --delete
    echo "EXIT=$?"
    if git show-ref --verify --quiet "refs/heads/feature-diverge-353"; then echo "BRANCH_EXISTS=yes"; else echo "BRANCH_EXISTS=no"; fi
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir" "$fixture_dir.setup.txt"

if echo "$output" | grep -q "BRANCH_EXISTS=yes" \
    && ! echo "$output" | grep -q "EXIT=0" \
    && ! echo "$output" | grep -q "AVISO: rama squash-mergeada"; then
    echo -e "${GREEN}✓ PASS${NC} — contenido divergente: la rama sigue existiendo y no hay AVISO de -D"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — contenido divergente: la rama sigue existiendo y no hay AVISO de -D"
    echo "  Expected: BRANCH_EXISTS=yes, exit distinto de 0 y sin 'AVISO: rama squash-mergeada'"
    echo "  Got:      $output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue #353 (endurecimiento): un PR cuya rama head es develop o main nunca se borra ---"
for protected in develop main; do
    test_count=$((test_count + 1))
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-protected-$protected-$$"
    mkdir -p "$fixture_dir/bin" "$fixture_dir/repo"
    setup_fake_gh "$fixture_dir/bin" "$protected"
    (
        cd "$fixture_dir/repo"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        echo base > base.txt
        git add base.txt
        git commit -q -m base
        git branch -q -M "$protected"
        PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "8" --delete
        echo "EXIT=$?"
        if git show-ref --verify --quiet "refs/heads/$protected"; then echo "BRANCH_EXISTS=yes"; else echo "BRANCH_EXISTS=no"; fi
    ) > "$fixture_dir/output.txt" 2>&1
    output=$(cat "$fixture_dir/output.txt")
    rm -rf "$fixture_dir"

    if echo "$output" | grep -q "BRANCH_EXISTS=yes" \
        && ! echo "$output" | grep -q "EXIT=0" \
        && echo "$output" | grep -q "rama protegida"; then
        echo -e "${GREEN}✓ PASS${NC} — head '$protected': rechazada con 'rama protegida', la rama sigue existiendo"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — head '$protected': rechazada con 'rama protegida', la rama sigue existiendo"
        echo "  Expected: BRANCH_EXISTS=yes, exit distinto de 0 y mensaje 'rama protegida'"
        echo "  Got:      $output"
        fail_count=$((fail_count + 1))
    fi
done

echo ""
echo "--- Issue #353 (endurecimiento): un rename no incorporado en develop no se confunde con contenido idéntico ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-rename-$$"
mkdir -p "$fixture_dir/bin" "$fixture_dir/origin"
setup_fake_gh "$fixture_dir/bin" "feature-rename-353"
(
    set -e
    cd "$fixture_dir/origin"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    printf 'linea 1\nlinea 2\nlinea 3\nlinea 4\n' > a.txt
    git add a.txt
    git commit -q -m base
    git branch -q -M develop
    git checkout -q -b feature-rename-353
    git mv a.txt b.txt
    git commit -q -m "rename a -> b"
    git checkout -q develop
    cp a.txt b.txt
    git add b.txt
    git commit -q -m "develop copia b pero conserva a"
    cd "$fixture_dir"
    git clone -q "$fixture_dir/origin" local
    cd "$fixture_dir/local"
    git config user.email "test@example.com"
    git config user.name "Test User"
    git checkout -q -b feature-rename-353 origin/feature-rename-353
    git checkout -q develop
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "9"
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir"

if echo "$output" | grep -q "NO aparece como mergeada"; then
    echo -e "${GREEN}✓ PASS${NC} — rename sin borrar el original en develop se detecta como NO mergeado"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — rename sin borrar el original en develop se detecta como NO mergeado"
    echo "  Expected: salida que contenga 'NO aparece como mergeada'"
    echo "  Got:      $output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue #353 (endurecimiento): si git fetch falla, el script avisa en vez de seguir en silencio ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-fetchfail-$$"
build_353_fixture "$fixture_dir" "feature-fetchfail-353" "merge" > "$fixture_dir.setup.txt" 2>&1
(
    cd "$fixture_dir/local"
    git remote set-url origin "$fixture_dir/no-existe"
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "10"
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir" "$fixture_dir.setup.txt"

if echo "$output" | grep -q "AVISO: no se pudo actualizar origin/develop"; then
    echo -e "${GREEN}✓ PASS${NC} — fallo de git fetch se reporta con AVISO"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — fallo de git fetch se reporta con AVISO"
    echo "  Expected: salida que contenga 'AVISO: no se pudo actualizar origin/develop'"
    echo "  Got:      $output"
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Issue #353 (endurecimiento): si -d falla en una rama que SÍ es ancestro, nunca se escala a -D ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-issue353-nodescalate-$$"
build_353_fixture "$fixture_dir" "feature-noescalate-353" "merge" > "$fixture_dir.setup.txt" 2>&1
(
    cd "$fixture_dir/local"
    git worktree add -q "$fixture_dir/otro-worktree" feature-noescalate-353
    PATH="$fixture_dir/bin:$PATH" "$SCRIPT_PATH" "fake/repo" "11" --delete
    echo "EXIT=$?"
    if git show-ref --verify --quiet "refs/heads/feature-noescalate-353"; then echo "BRANCH_EXISTS=yes"; else echo "BRANCH_EXISTS=no"; fi
) > "$fixture_dir/output.txt" 2>&1
output=$(cat "$fixture_dir/output.txt")
rm -rf "$fixture_dir" "$fixture_dir.setup.txt"

if echo "$output" | grep -q "BRANCH_EXISTS=yes" \
    && ! echo "$output" | grep -q "EXIT=0" \
    && ! echo "$output" | grep -q "AVISO: rama squash-mergeada"; then
    echo -e "${GREEN}✓ PASS${NC} — rama ancestro con -d fallido: sigue existiendo, sin escalar a -D"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — rama ancestro con -d fallido: sigue existiendo, sin escalar a -D"
    echo "  Expected: BRANCH_EXISTS=yes, exit distinto de 0 y sin 'AVISO: rama squash-mergeada'"
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
