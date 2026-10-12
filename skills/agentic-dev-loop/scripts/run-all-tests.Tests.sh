#!/usr/bin/env bash
# run-all-tests.Tests.sh — Tests para run-all-tests.sh (Issue #351)
#
# run-all-tests.sh acepta un root_dir opcional (default: raiz del repo) justamente para que
# estos tests puedan apuntarlo a un fixture aislado en vez de escanear el repo real -- evita
# que la suite sea lenta y evita falsos negativos si alguna suite real del repo cambia de
# estado entre corridas.
#
# Fixtures bash: un ".Tests.sh" fake que siempre pasa (exit 0) y uno que siempre falla
# (exit 1), para probar que el exit code agregado refleja "hubo al menos un fallo" --
# el bug que un `find -exec ... \;` ingenuo comete (devuelve el exit code del ULTIMO -exec,
# perdiendo un fallo que no sea el ultimo).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-all-tests.sh"
trap 'rm -rf "$(dirname "$SCRIPT_PATH")"/.tmp-test-runalltests-*' EXIT

write_passing_suite() {
    local target="$1"
    cat > "$target" << 'SUITE_END'
#!/usr/bin/env bash
echo "fixture suite OK"
echo "Fail: 0"
exit 0
SUITE_END
    chmod +x "$target"
}

write_failing_suite() {
    local target="$1"
    cat > "$target" << 'SUITE_END'
#!/usr/bin/env bash
echo "fixture suite FAIL"
echo "Fail: 1"
exit 1
SUITE_END
    chmod +x "$target"
}

write_hanging_suite() {
    local target="$1"
    cat > "$target" << 'SUITE_END'
#!/usr/bin/env bash
sleep 30
echo "nunca deberia llegar aca"
exit 0
SUITE_END
    chmod +x "$target"
}

assert_exit() {
    local label="$1" expected="$2" actual="$3"
    test_count=$((test_count + 1))
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $label"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $label"
        echo "  Expected exit $expected, got $actual"
        fail_count=$((fail_count + 1))
    fi
}

echo ""
echo "--- Dos suites pasando -> exit 0 agregado ---"
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-ok-$$"
mkdir -p "$fixture_dir"
write_passing_suite "$fixture_dir/one.Tests.sh"
write_passing_suite "$fixture_dir/two.Tests.sh"
output=$(NO_PWSH=1 bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
assert_exit "dos suites OK -> exit 0" "0" "$actual_exit"

echo ""
echo "--- Una suite pasa y otra falla -> exit 1 agregado (no se pierde el fallo) ---"
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-mixed-$$"
mkdir -p "$fixture_dir"
write_passing_suite "$fixture_dir/one.Tests.sh"
write_failing_suite "$fixture_dir/two.Tests.sh"
output=$(NO_PWSH=1 bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
actual_exit=$?
test_count=$((test_count + 1))
if [ "$actual_exit" -ne 0 ] && echo "$output" | grep -q "two.Tests.sh"; then
    echo -e "${GREEN}✓ PASS${NC} — mix OK/FAIL -> exit != 0 y menciona la suite fallida"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — mix OK/FAIL -> exit != 0 y menciona la suite fallida"
    echo "  Got exit $actual_exit"
    echo "$output" | tail -20
    fail_count=$((fail_count + 1))
fi
rm -r "$fixture_dir"

echo ""
echo "--- Fallo en la PRIMERA suite no se pierde aunque haya mas suites despues (orden) ---"
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-order-$$"
mkdir -p "$fixture_dir"
write_failing_suite "$fixture_dir/a-first.Tests.sh"
write_passing_suite "$fixture_dir/z-last.Tests.sh"
output=$(NO_PWSH=1 bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
assert_exit "fallo en la primera suite -> exit 1 pese a que la ultima pasa" "1" "$actual_exit"

echo ""
echo "--- Sin pwsh en PATH: suites .Tests.ps1 se saltean con SKIP visible, no fallan el gate ---"
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-nopwsh-$$"
mkdir -p "$fixture_dir"
write_passing_suite "$fixture_dir/one.Tests.sh"
touch "$fixture_dir/fake.Tests.ps1"
output=$(NO_PWSH=1 bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
test_count=$((test_count + 1))
if [ "$actual_exit" -eq 0 ] && echo "$output" | grep -qi "SKIP.*pwsh"; then
    echo -e "${GREEN}✓ PASS${NC} — sin pwsh -> SKIP visible, exit 0 (no rompe el gate por una herramienta ausente)"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — sin pwsh -> SKIP visible, exit 0"
    echo "  Got exit $actual_exit"
    echo "$output" | tail -20
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Suite colgada -> timeout por suite la reporta FAIL en vez de bloquear el gate (Issue #351, hallazgo real con session-end-gather.Tests.ps1) ---"
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-hang-$$"
mkdir -p "$fixture_dir"
write_hanging_suite "$fixture_dir/hang.Tests.sh"
write_passing_suite "$fixture_dir/ok.Tests.sh"
output=$(NO_PWSH=1 SUITE_TIMEOUT_SECONDS=2 timeout 20 bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
test_count=$((test_count + 1))
if [ "$actual_exit" -ne 0 ] && echo "$output" | grep -q "timeout" && echo "$output" | grep -q "hang.Tests.sh"; then
    echo -e "${GREEN}✓ PASS${NC} — suite colgada -> FAIL por timeout, no bloquea el gate para siempre"
    pass_count=$((pass_count + 1))
else
    echo -e "${RED}✗ FAIL${NC} — suite colgada -> FAIL por timeout, no bloquea el gate para siempre"
    echo "  Got exit $actual_exit"
    echo "$output" | tail -20
    fail_count=$((fail_count + 1))
fi

echo ""
echo "--- Fixture huerfano .tmp-test-* dentro del root no se ejecuta como suite ---"
fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-leak-$$"
mkdir -p "$fixture_dir/.tmp-test-leak"
write_passing_suite "$fixture_dir/ok.Tests.sh"
write_failing_suite "$fixture_dir/.tmp-test-leak/x.Tests.sh"
output=$(NO_PWSH=1 bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
actual_exit=$?
rm -r "$fixture_dir"
assert_exit "suite en .tmp-test-* excluida -> exit 0" "0" "$actual_exit"

write_passing_ps1_suite() {
    local target="$1"
    cat > "$target" << 'SUITE_END'
Describe "fixture passing" {
    It "pasa" {
        $true | Should Be $true
    }
}
SUITE_END
}

write_failing_ps1_suite() {
    local target="$1"
    cat > "$target" << 'SUITE_END'
Describe "fixture failing" {
    It "falla" {
        $true | Should Be $false
    }
}
SUITE_END
}

if command -v pwsh >/dev/null 2>&1; then
    echo ""
    echo "--- pwsh real disponible: suite .Tests.ps1 que pasa -> exit 0 (prueba la conversion de path) ---"
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-ps1ok-$$"
    mkdir -p "$fixture_dir"
    write_passing_ps1_suite "$fixture_dir/fixture.Tests.ps1"
    output=$(bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
    actual_exit=$?
    rm -r "$fixture_dir"
    test_count=$((test_count + 1))
    if [ "$actual_exit" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC} — suite .ps1 pasando -> exit 0"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — suite .ps1 pasando -> exit 0"
        echo "  Got exit $actual_exit"
        echo "$output" | tail -30
        fail_count=$((fail_count + 1))
    fi

    echo ""
    echo "--- pwsh real disponible: suite .Tests.ps1 que falla -> exit != 0 agregado ---"
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-ps1fail-$$"
    mkdir -p "$fixture_dir"
    write_failing_ps1_suite "$fixture_dir/fixture.Tests.ps1"
    output=$(bash "$SCRIPT_PATH" "$fixture_dir" 2>&1)
    actual_exit=$?
    rm -r "$fixture_dir"
    test_count=$((test_count + 1))
    if [ "$actual_exit" -ne 0 ] && echo "$output" | grep -q "fixture.Tests.ps1"; then
        echo -e "${GREEN}✓ PASS${NC} — suite .ps1 fallando -> exit != 0 y se reporta"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — suite .ps1 fallando -> exit != 0 y se reporta"
        echo "  Got exit $actual_exit"
        echo "$output" | tail -30
        fail_count=$((fail_count + 1))
    fi

    echo ""
    echo "--- pwsh real disponible: Invoke-Pester que falla sin asignar \$r -> exit != 0 agregado ---"
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-runalltests-pesterbroken-$$"
    mkdir -p "$fixture_dir/mods/Pester" "$fixture_dir/fx"
    echo 'function Invoke-Pester { Write-Error "pester roto" }' > "$fixture_dir/mods/Pester/Pester.psm1"
    echo "@{ ModuleVersion='99.0.0'; RootModule='Pester.psm1'; FunctionsToExport='Invoke-Pester'; GUID='11111111-2222-3333-4444-555555555555' }" > "$fixture_dir/mods/Pester/Pester.psd1"
    echo 'Describe "a" { It "b" { 1 | Should Be 1 } }' > "$fixture_dir/fx/f.Tests.ps1"
    path_sep="$(pwsh -NoProfile -Command '[IO.Path]::PathSeparator')"
    win_mods="$(cygpath -w "$fixture_dir/mods" 2>/dev/null || echo "$fixture_dir/mods")"
    output=$(PSModulePath="$win_mods$path_sep${PSModulePath:-}" bash "$SCRIPT_PATH" "$fixture_dir/fx" 2>&1)
    actual_exit=$?
    rm -r "$fixture_dir"
    test_count=$((test_count + 1))
    if [ "$actual_exit" -ne 0 ] && echo "$output" | grep -q "f.Tests.ps1"; then
        echo -e "${GREEN}✓ PASS${NC} — Invoke-Pester roto sin \$r -> exit != 0 y se reporta"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — Invoke-Pester roto sin \$r -> exit != 0 y se reporta"
        echo "  Got exit $actual_exit"
        echo "$output" | tail -30
        fail_count=$((fail_count + 1))
    fi
else
    echo ""
    echo "NOTA: pwsh no disponible en este entorno -- se omiten los 2 tests que ejercitan Invoke-Pester real."
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
