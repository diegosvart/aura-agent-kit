#!/usr/bin/env bash
# cut-release.Tests.sh — Tests para cut-release.sh (Issue #285, bug #5, Issue #328)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cut-release.sh"

# write_fake_gh -- fixture de "gh" de alta fidelidad, reutilizado por el test de Issue #328 y
# por el test de mock-hardening (hallazgo no bloqueante del verifier de PR #331).
#
# A diferencia de un catch-all "exit 0" para cualquier invocacion no reconocida, este fake:
#   - Reconoce explicitamente las unicas dos invocaciones que cut-release.sh (subcomando "tag")
#     puede legitimamente hacer: "gh pr view ..." y "gh release create ...".
#   - Valida forma basica de los argumentos de cada una ($EXPECTED_* via entorno) y falla con
#     exit 1 + mensaje a stderr si algo no matchea (PR equivocado, --repo faltante/incorrecto,
#     --jq inesperado, version incorrecta en "release create", o cualquiera de --repo/--title/
#     --generate-notes ausente).
#   - Cualquier otra invocacion de "gh" (subcomando no esperado) tambien falla ruidosamente en
#     vez de devolver exit 0 en silencio -- ese catch-all silencioso era el hallazgo del
#     verifier: ocultaria un "gh release create" con argumentos rotos o una invocacion
#     inesperada de gh.
#
# Sigue logueando cada invocacion completa a "$GH_LOG_FILE" (las aserciones existentes hacen
# grep sobre ese log).
#
# Variables de entorno esperadas en tiempo de ejecucion del fake (no en tiempo de escritura):
#   GH_LOG_FILE, EXPECTED_REPO, EXPECTED_VERSION, EXPECTED_RELEASE_PR, EXPECTED_COMMIT_HASH,
#   FAKE_RELEASE_EXISTS (opcional, "true"/"false", default "false" -- usado por "gh release
#   view" para simular si el Release ya existe en GitHub; hallazgo de reintentabilidad, PR #331)
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

if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    pr_arg="$3"
    if [ "$pr_arg" != "$EXPECTED_RELEASE_PR" ]; then
        fail "gh pr view recibio PR inesperado: '$pr_arg' (esperado '$EXPECTED_RELEASE_PR')"
    fi
    shift 3
    repo_ok=0
    jq_filter=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)
                shift
                [ "${1:-}" = "$EXPECTED_REPO" ] && repo_ok=1
                ;;
            --json)
                shift
                ;;
            --jq)
                shift
                jq_filter="${1:-}"
                ;;
        esac
        shift
    done
    if [ "$repo_ok" -ne 1 ]; then
        fail "gh pr view sin --repo '$EXPECTED_REPO' valido"
    fi
    case "$jq_filter" in
        .state)
            echo "MERGED"
            ;;
        .mergeCommit.oid)
            echo "$EXPECTED_COMMIT_HASH"
            ;;
        *)
            fail "gh pr view con --jq inesperado: '$jq_filter'"
            ;;
    esac
    exit 0
fi

if [ "$1" = "release" ] && [ "$2" = "view" ]; then
    version_arg="$3"
    if [ "$version_arg" != "$EXPECTED_VERSION" ]; then
        fail "gh release view recibio version inesperada: '$version_arg' (esperado '$EXPECTED_VERSION')"
    fi
    shift 3
    repo_ok=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)
                shift
                [ "${1:-}" = "$EXPECTED_REPO" ] && repo_ok=1
                ;;
        esac
        shift
    done
    if [ "$repo_ok" -ne 1 ]; then
        fail "gh release view sin --repo '$EXPECTED_REPO' valido"
    fi
    if [ "${FAKE_RELEASE_EXISTS:-false}" = "true" ]; then
        exit 0
    else
        exit 1
    fi
fi

if [ "$1" = "release" ] && [ "$2" = "create" ]; then
    version_arg="$3"
    if [ "$version_arg" != "$EXPECTED_VERSION" ]; then
        fail "gh release create con version inesperada: '$version_arg' (esperado '$EXPECTED_VERSION')"
    fi
    shift 3
    has_repo=0
    has_title=0
    has_generate_notes=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)
                shift
                [ "${1:-}" = "$EXPECTED_REPO" ] && has_repo=1
                ;;
            --title)
                shift
                [ "${1:-}" = "$EXPECTED_VERSION" ] && has_title=1
                ;;
            --generate-notes)
                has_generate_notes=1
                ;;
        esac
        shift
    done
    if [ "$has_repo" -ne 1 ]; then
        fail "gh release create sin --repo '$EXPECTED_REPO' valido"
    fi
    if [ "$has_title" -ne 1 ]; then
        fail "gh release create sin --title '$EXPECTED_VERSION' valido"
    fi
    if [ "$has_generate_notes" -ne 1 ]; then
        fail "gh release create sin --generate-notes"
    fi
    exit 0
fi

fail "invocacion de gh no esperada (subcomando no reconocido)"
FAKE_GH_END
    chmod +x "$target"
}

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
echo "--- Issue #328: cut-release.sh tag debe crear el GitHub Release ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-cutrelease-tag-$$"
mkdir -p "$fixture_dir"
fake_bin_dir="$fixture_dir/fake_bin"
mkdir -p "$fake_bin_dir"

(
    cd "$fixture_dir"
    # Crear un repo remoto bare
    origin_dir="$fixture_dir/origin.git"
    mkdir -p "$origin_dir"
    git init -q --bare "$origin_dir"

    # Crear repo de trabajo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    git remote add origin "$origin_dir"

    # Crear rama main
    git checkout -q -b main
    echo "initial" > README.md
    git add README.md
    git commit -q -m "initial commit"
    git push -q -u origin main

    # Crear rama develop
    git checkout -q -b develop
    echo "develop" > develop.md
    git commit -q -m "develop commit"
    git push -q -u origin develop

    # Volver a main
    git checkout -q main

    # Obtener el hash real del último commit en main para que el fake gh lo devuelva
    real_commit_hash=$(git rev-parse HEAD)
    export GH_LOG_FILE="$fixture_dir/gh.log"
    touch "$GH_LOG_FILE"

    # Fake gh de alta fidelidad (ver write_fake_gh mas arriba): valida forma de argumentos y
    # falla ruidosamente ante cualquier invocacion no reconocida o mal formada.
    mkdir -p "$fake_bin_dir"
    write_fake_gh "$fake_bin_dir/gh"
    export EXPECTED_REPO="fake/repo"
    export EXPECTED_VERSION="v9.9.9"
    export EXPECTED_RELEASE_PR="999"
    export EXPECTED_COMMIT_HASH="$real_commit_hash"

    # Crear un fake git que ignora "git pull"
    real_git_path=$(which git)
    cat > "$fake_bin_dir/git" << FAKE_GIT_END
#!/usr/bin/env bash
if [ "\$1" = "pull" ]; then
  exit 0
fi
exec "$real_git_path" "\$@"
FAKE_GIT_END
    chmod +x "$fake_bin_dir/git"

    # Usar el fake git y fake gh en el PATH
    export PATH="$fake_bin_dir:$PATH"

    # Ejecutar cut-release.sh tag. Importante: NO usar "|| true" aca -- eso enmascararia el
    # exit code real del script (siempre quedaria en 0), que es justo lo que la asercion de
    # abajo necesita para distinguir una invocacion valida de una que el mock estricto
    # rechazo. El script bajo test corre con su propio "set -euo pipefail" interno; este
    # archivo de test corre con "set -uo pipefail" (sin -e), asi que un exit != 0 aca no
    # aborta el test runner.
    "$SCRIPT_PATH" tag "fake/repo" "v9.9.9" "999" > "$fixture_dir/output.txt" 2>&1
    echo $? > "$fixture_dir/script_exit_code.txt"
) > "$fixture_dir/full_output.txt" 2>&1
actual_exit_code=$(cat "$fixture_dir/script_exit_code.txt" 2>/dev/null || echo "unknown")
output=$(cat "$fixture_dir/output.txt")
full_output=$(cat "$fixture_dir/full_output.txt")
gh_log=$(cat "$fixture_dir/gh.log" 2>/dev/null || echo "")
rm -rf "$fixture_dir"

# Verificar que gh.log contiene "release create" (fix aplicado) Y que el script termino en
# exit 0 -- el fake gh loguea la invocacion ANTES de validarla, asi que solo el exit code
# distingue una invocacion valida de una que el mock estricto rechazo.
if echo "$gh_log" | grep -q "release create" && [ "$actual_exit_code" = "0" ]; then
    echo -e "${GREEN}✓ PASS${NC} (GREEN) — fix verificado: cut-release.sh tag SÍ invoca gh release create con argumentos validos"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} (GREEN) — fix no funciona, falta release create en el log o el mock estricto lo rechazo"
    echo "  Expected: gh.log con 'release create v9.9.9 ... --generate-notes', exit 0"
    echo "  Got exit: $actual_exit_code"
    echo "  Got gh.log: $gh_log"
    if [ ! -z "$output" ]; then
      echo "  Script output: $output"
    fi
    if [ ! -z "$full_output" ]; then
      echo "  Full output (first 500 chars): $(echo "$full_output" | head -c 500)"
    fi
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Hallazgo code-review PR #331: cut-release.sh tag debe ser reintentable si 'gh release create' fallo tras crear el tag ---"
test_count=$((test_count + 1))
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-cutrelease-retry-$$"
mkdir -p "$fixture_dir"
fake_bin_dir="$fixture_dir/fake_bin"
mkdir -p "$fake_bin_dir"

(
    cd "$fixture_dir"
    # Crear un repo remoto bare
    origin_dir="$fixture_dir/origin.git"
    mkdir -p "$origin_dir"
    git init -q --bare "$origin_dir"

    # Crear repo de trabajo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config core.autocrlf false
    git remote add origin "$origin_dir"

    # Crear rama main
    git checkout -q -b main
    echo "initial" > README.md
    git add README.md
    git commit -q -m "initial commit"
    git push -q -u origin main

    # Crear rama develop
    git checkout -q -b develop
    echo "develop" > develop.md
    git commit -q -m "develop commit"
    git push -q -u origin develop

    # Volver a main
    git checkout -q main

    real_commit_hash=$(git rev-parse HEAD)

    # Simular el escenario del bug: un run anterior murio DESPUES de crear+pushear el tag
    # pero ANTES de "gh release create" -- el tag ya existe localmente, apuntando al mismo
    # merge commit que devolveria "gh pr view".
    git tag -a "v9.9.9" -m "v9.9.9" "$real_commit_hash"
    git push -q origin "refs/tags/v9.9.9"

    export GH_LOG_FILE="$fixture_dir/gh.log"
    touch "$GH_LOG_FILE"

    mkdir -p "$fake_bin_dir"
    write_fake_gh "$fake_bin_dir/gh"
    export EXPECTED_REPO="fake/repo"
    export EXPECTED_VERSION="v9.9.9"
    export EXPECTED_RELEASE_PR="999"
    export EXPECTED_COMMIT_HASH="$real_commit_hash"
    # El Release NUNCA se llego a crear en el run anterior -- esto es lo que dispara el bug.
    export FAKE_RELEASE_EXISTS="false"

    real_git_path=$(which git)
    cat > "$fake_bin_dir/git" << FAKE_GIT_END
#!/usr/bin/env bash
if [ "\$1" = "pull" ]; then
  exit 0
fi
exec "$real_git_path" "\$@"
FAKE_GIT_END
    chmod +x "$fake_bin_dir/git"

    export PATH="$fake_bin_dir:$PATH"

    "$SCRIPT_PATH" tag "fake/repo" "v9.9.9" "999" > "$fixture_dir/output.txt" 2>&1
    echo $? > "$fixture_dir/script_exit_code.txt"
) > "$fixture_dir/full_output.txt" 2>&1
actual_exit_code=$(cat "$fixture_dir/script_exit_code.txt" 2>/dev/null || echo "unknown")
output=$(cat "$fixture_dir/output.txt")
gh_log=$(cat "$fixture_dir/gh.log" 2>/dev/null || echo "")
rm -rf "$fixture_dir"

# Comportamiento esperado (post-fix): el script detecta que el tag ya existe localmente, NO
# lo vuelve a crear, pero SI invoca "gh release create" (porque el Release todavia no existe
# en GitHub) y termina en exit 0.
if echo "$gh_log" | grep -q "release create" && [ "$actual_exit_code" = "0" ]; then
    echo -e "${GREEN}✓ PASS${NC} — reintento tras tag-ya-creado-pero-sin-release SI invoca gh release create y sale exit 0"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — reintento tras tag-ya-creado-pero-sin-release no invoco gh release create o no salio exit 0"
    echo "  Expected: gh.log con 'release create v9.9.9 ...', exit 0"
    echo "  Got exit: $actual_exit_code"
    echo "  Got gh.log: $gh_log"
    if [ ! -z "$output" ]; then
      echo "  Script output: $output"
    fi
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Mock hardening: fake gh debe rechazar 'release create' mal formado (sin --generate-notes) ---"
test_count=$((test_count + 1))
mock_fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-cutrelease-mockcheck-$$"
mkdir -p "$mock_fixture_dir"
(
    export GH_LOG_FILE="$mock_fixture_dir/gh.log"
    touch "$GH_LOG_FILE"
    write_fake_gh "$mock_fixture_dir/gh"
    export EXPECTED_REPO="fake/repo"
    export EXPECTED_VERSION="v9.9.9"
    export EXPECTED_RELEASE_PR="999"
    export EXPECTED_COMMIT_HASH="deadbeef"

    # Invocacion deliberadamente mal formada: falta --generate-notes.
    "$mock_fixture_dir/gh" release create "v9.9.9" --repo "fake/repo" --title "v9.9.9" \
        > "$mock_fixture_dir/stdout.txt" 2> "$mock_fixture_dir/stderr.txt"
    echo $? > "$mock_fixture_dir/exit_code.txt"
) > /dev/null 2>&1
mock_exit_code=$(cat "$mock_fixture_dir/exit_code.txt" 2>/dev/null || echo "unknown")
mock_stderr=$(cat "$mock_fixture_dir/stderr.txt" 2>/dev/null || echo "")
rm -rf "$mock_fixture_dir"

if [ "$mock_exit_code" = "1" ] && echo "$mock_stderr" | grep -qF "FAKE_GH_ERROR" && echo "$mock_stderr" | grep -qF "generate-notes"; then
    echo -e "${GREEN}✓ PASS${NC} — el mock endurecido detecta y rechaza 'gh release create' sin --generate-notes"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — el mock endurecido no rechazo una invocacion mal formada de 'gh release create'"
    echo "  Expected: exit 1 y stderr mencionando 'FAKE_GH_ERROR' y 'generate-notes'"
    echo "  Got exit: $mock_exit_code"
    echo "  Got stderr: $mock_stderr"
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
