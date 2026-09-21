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

    # Crear fake gh dentro de la subshell con variables disponibles
    mkdir -p "$fake_bin_dir"
    cat > "$fake_bin_dir/gh" << 'FAKE_GH_END'
#!/usr/bin/env bash
echo "$@" >> "$GH_LOG_FILE"

if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
  # Parsear los argumentos para encontrar --jq
  jq_filter=""
  for arg in "$@"; do
    if [ "$prev_was_jq" = "1" ]; then
      jq_filter="$arg"
      break
    fi
    if [ "$arg" = "--jq" ]; then
      prev_was_jq=1
    fi
  done

  if [ "$jq_filter" = ".state" ]; then
    echo "MERGED"
  elif [ "$jq_filter" = ".mergeCommit.oid" ]; then
    echo "REPLACE_COMMIT_HASH"
  else
    echo '{"state":"MERGED","mergeCommit":{"oid":"REPLACE_COMMIT_HASH"}}'
  fi
  exit 0
fi
exit 0
FAKE_GH_END
    # Reemplazar el placeholder con el hash real
    sed -i "s/REPLACE_COMMIT_HASH/$real_commit_hash/g" "$fake_bin_dir/gh"
    chmod +x "$fake_bin_dir/gh"

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

    # Ejecutar cut-release.sh tag
    "$SCRIPT_PATH" tag "fake/repo" "v9.9.9" "999" > "$fixture_dir/output.txt" 2>&1 || true
) > "$fixture_dir/full_output.txt" 2>&1
actual_exit_code=$?
output=$(cat "$fixture_dir/output.txt")
full_output=$(cat "$fixture_dir/full_output.txt")
gh_log=$(cat "$fixture_dir/gh.log" 2>/dev/null || echo "")
rm -rf "$fixture_dir"

# Verificar que gh.log contiene "release create" (fix aplicado)
if echo "$gh_log" | grep -q "release create"; then
    echo -e "${GREEN}✓ PASS${NC} (GREEN) — fix verificado: cut-release.sh tag SÍ invoca gh release create"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} (GREEN) — fix no funciona, falta release create en el log"
    echo "  Expected: gh.log con 'release create v9.9.9 ... --generate-notes'"
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
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
