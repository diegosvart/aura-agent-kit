#!/usr/bin/env bash
# verify-install.Tests.sh — Tests para verify-install.sh
#
# TDD: escribe tests primero (RED), luego implementa el script (GREEN)
# Crea fixtures temporales (repo git fake, settings.json, hooks, submodule),
# corre verify-install.sh contra ellas, y compara output esperado línea por línea.

set -uo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_count=0
pass_count=0
fail_count=0

# Helper: crear fixture en directorio temporal
setup_fixture() {
    local test_name=$1
    local fixture_dir=$(mktemp -d)
    echo "$fixture_dir"
}

# Helper: cleanup
cleanup_fixture() {
    local fixture_dir=$1
    rm -rf "$fixture_dir"
}

# Resolver path al script una sola vez al inicio
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify-install.sh"

# Helper: correr test
run_test() {
    local test_name=$1
    local fixture_setup_fn=$2
    local expected_output=$3
    local expected_exit_code=${4:-0}

    test_count=$((test_count + 1))

    # Validar que el script existe antes de correr tests
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}✗ FAIL${NC} — $test_name (script not found: $SCRIPT_PATH)"
        fail_count=$((fail_count + 1))
        return 1
    fi

    # Setup fixture en subshell para no contaminar el cwd actual
    fixture_dir=$(mktemp -d)
    trap "cleanup_fixture '$fixture_dir'" RETURN

    (
        cd "$fixture_dir"

        # Inicializar repo git mínimo
        git init > /dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"

        # Ejecutar setup personalizado de la fixture
        $fixture_setup_fn "$fixture_dir"

        # Correr el script a testear (usa ruta absoluta)
        # Capturar output Y exit code en dos operaciones separadas
        "$SCRIPT_PATH" > /tmp/verify_install_output_$$ 2>&1
        actual_exit_code=$?
        output=$(cat /tmp/verify_install_output_$$)
        rm -f /tmp/verify_install_output_$$

        # Comparar output
        if [ "$output" = "$expected_output" ] && [ "$actual_exit_code" = "$expected_exit_code" ]; then
            echo -e "${GREEN}✓ PASS${NC} — $test_name"
        else
            echo -e "${RED}✗ FAIL${NC} — $test_name"
            echo "  Expected output:"
            echo "$expected_output" | sed 's/^/    /'
            echo "  Got output:"
            echo "$output" | sed 's/^/    /'
            echo "  Expected exit code: $expected_exit_code"
            echo "  Got exit code: $actual_exit_code"
            exit 1
        fi
    )

    if [ $? -eq 0 ]; then
        pass_count=$((pass_count + 1))
    else
        fail_count=$((fail_count + 1))
    fi
}

# Test 1: settings.json vacío o sin hooks — OK
fixture_empty_settings() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.claude"
    echo '{}' > "$fixture_dir/.claude/settings.json"
}

run_test "empty settings.json should report OK" \
    "fixture_empty_settings" \
    "Verificación post-instalación: OK" \
    0

# Test 2: hook referenciado existe y está trackeado — OK
fixture_hook_exists_tracked() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.claude/hooks"

    # settings.json con un hook
    cat > "$fixture_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/test-hook.ps1"
          }
        ]
      }
    ]
  }
}
EOF

    # Crear el hook
    echo '# Test hook' > "$fixture_dir/.claude/hooks/test-hook.ps1"

    # Trackearlo en git
    git add ".claude/hooks/test-hook.ps1"
    git commit -m "Add test hook" > /dev/null 2>&1 || true
}

run_test "hook exists and is tracked should report OK" \
    "fixture_hook_exists_tracked" \
    "Verificación post-instalación: OK" \
    0

# Test 3: hook referenciado NO existe en disco — MISSING_FILE
fixture_hook_missing() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.claude"

    cat > "$fixture_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/missing-hook.ps1"
          }
        ]
      }
    ]
  }
}
EOF
}

run_test "missing hook file should report MISSING_FILE" \
    "fixture_hook_missing" \
    "MISSING_FILE: .claude/hooks/missing-hook.ps1
Sugerencia para corregir: copiar desde .aura/.claude/hooks/missing-hook.ps1 (si existe)" \
    1

# Test 4: hook existe pero NO está trackeado — NOT_TRACKED
fixture_hook_not_tracked() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.claude/hooks"

    cat > "$fixture_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/untracked.ps1"
          }
        ]
      }
    ]
  }
}
EOF

    echo '# Untracked hook' > "$fixture_dir/.claude/hooks/untracked.ps1"
    # NO lo trackeamos intencionalmente
}

run_test "hook exists but not tracked should report NOT_TRACKED" \
    "fixture_hook_not_tracked" \
    "NOT_TRACKED: .claude/hooks/untracked.ps1
Sugerencia para corregir: git add .claude/hooks/untracked.ps1" \
    1

# Test 5: múltiples hooks, uno falta, uno no está trackeado
fixture_multiple_issues() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.claude/hooks"

    cat > "$fixture_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/hook1.ps1"
          },
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/hook2.ps1"
          },
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/hook3.ps1"
          }
        ]
      }
    ]
  }
}
EOF

    # hook1: existe y trackeado
    echo '# Hook 1' > "$fixture_dir/.claude/hooks/hook1.ps1"
    git add ".claude/hooks/hook1.ps1"
    git commit -m "Add hook1" > /dev/null 2>&1 || true

    # hook2: existe pero NO trackeado
    echo '# Hook 2' > "$fixture_dir/.claude/hooks/hook2.ps1"

    # hook3: no existe
}

run_test "multiple hooks with multiple issues should report all" \
    "fixture_multiple_issues" \
    "MISSING_FILE: .claude/hooks/hook3.ps1
Sugerencia para corregir: copiar desde .aura/.claude/hooks/hook3.ps1 (si existe)
NOT_TRACKED: .claude/hooks/hook2.ps1
Sugerencia para corregir: git add .claude/hooks/hook2.ps1" \
    1

# Test 6: submodule no inicializado
fixture_submodule_not_init() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.aura"
    # Simular submodule no inicializado creando un archivo .git instead of directorio
    echo "gitdir: ../.git/modules/.aura" > "$fixture_dir/.aura/.git"

    mkdir -p "$fixture_dir/.git/modules/.aura"

    # Crear .gitmodules
    cat > "$fixture_dir/.gitmodules" << 'EOF'
[submodule ".aura"]
	path = .aura
	url = https://github.com/diegosvart/aura-agent-kit.git
EOF

    git add ".gitmodules"
    git commit -m "Add submodule config" > /dev/null 2>&1 || true
}

# Este test va a fallar inicialmente porque git submodule status requiere un estado especifico.
# Ajustaremos el test si es necesario después de implementar.

# Test 7: submodule inicializado y OK
fixture_submodule_ok() {
    local fixture_dir=$1
    mkdir -p "$fixture_dir/.claude/hooks"

    cat > "$fixture_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NonInteractive -File .claude/hooks/hook.ps1"
          }
        ]
      }
    ]
  }
}
EOF

    # Crear y trackear hook
    echo '# Hook' > "$fixture_dir/.claude/hooks/hook.ps1"
    git add ".claude/hooks/hook.ps1"
    git commit -m "Add hook" > /dev/null 2>&1 || true
}

run_test "all hooks ok should report OK" \
    "fixture_submodule_ok" \
    "Verificación post-instalación: OK" \
    0

# Resumen
echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
