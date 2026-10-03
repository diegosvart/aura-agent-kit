#!/usr/bin/env bash
# run-all-tests.sh — Issue #351
#
# Corre todas las suites de test reales del repo (bash "*.Tests.sh" + PowerShell/Pester
# "*.Tests.ps1") y agrega el resultado en un solo exit code, sin perder ningun fallo
# individual. Un `find ... -exec script \;` ingenuo NO sirve para esto: ese patron propaga
# el exit code del ULTIMO -exec, no "hubo al menos un fallo" -- un fallo en cualquier suite
# que no sea la ultima quedaria invisible. Este script acumula el resultado de cada suite en
# una variable y recien decide el exit code agregado al final.
#
# Uso: run-all-tests.sh [root_dir]
#   root_dir (opcional) — raiz desde la cual buscar "*.Tests.sh"/"*.Tests.ps1".
#   Default: raiz del repo (tres niveles arriba de este script). Parametrizable para que
#   run-all-tests.Tests.sh pueda apuntar a un fixture aislado en vez de escanear el repo real.
#
# Suites PowerShell (*.Tests.ps1, framework Pester 3.4.0): requieren "pwsh" en el PATH.
# Si no esta disponible, se SALTEAN con un SKIP visible (mismo criterio que el check de
# "lint" en session-stack.json, que ya degrada con "shellcheck no disponible, omitiendo" en
# vez de fallar duro) -- la ausencia de una herramienta del entorno no es lo mismo que un test
# rojo, y bloquear el gate completo por eso sería un fail-closed desproporcionado para algo
# que no es evidencia de una regresion real. NO_PWSH=1 fuerza esta rama para poder testearla
# de forma deterministica sin depender de que el entorno real tenga o no pwsh instalado.
#
# Timeout por suite (hallazgo real durante el desarrollo de Issue #351):
# ".claude/hooks/session-end-gather.Tests.ps1" invoca el entry point real del hook (no
# mockeado) en su ultimo test ("entry point emite JSON valido"), y ese entry point puede
# colgarse en este entorno (observado: varios minutos sin retornar). Sin un limite, una sola
# suite colgada bloquea el gate completo indefinidamente -- el peor escenario posible para un
# gate de CI. SUITE_TIMEOUT_SECONDS acota cada suite individual; si una se cuelga, se reporta
# como FAIL explicito (exit 124 de `timeout`), nunca se omite en silencio ni se excluye del
# scan.
#
# Por que la salida de pwsh se redirige a un ARCHIVO y no se captura con $(...) (hallazgo
# real, segunda vuelta): el entry-point test de arriba lanza un pwsh.exe NIETO (`& pwsh
# -NonInteractive -File $hookPath` dentro del propio test). Cuando `timeout` mata al pwsh
# HIJO directo, ese nieto queda huerfano y sigue corriendo en Windows -- y como hereda el
# extremo de escritura del pipe de stdout/stderr, `output=$(... 2>&1)` se queda esperando
# para siempre a que ese pipe se cierre, aunque el `timeout` ya haya "terminado" el hijo
# visible. Resultado observado: procesos pwsh.exe huerfanos corriendo minutos despues de que
# el `timeout` que los debia matar ya habia retornado. Redirigir a un archivo en vez de un
# pipe evita el problema por completo: escribir a un archivo no bloquea esperando que otros
# procesos cierren su copia del descriptor.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ROOT_DIR="${1:-$DEFAULT_ROOT}"
SUITE_TIMEOUT_SECONDS="${SUITE_TIMEOUT_SECONDS:-90}"

overall_status=0
total=0
failed=0
failed_suites=()

run_bash_suite() {
    local file="$1"
    total=$((total + 1))
    echo "--- bash: $file ---"
    local rc
    timeout -k 10 "$SUITE_TIMEOUT_SECONDS" bash "$file"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        :
    elif [ "$rc" -eq 124 ]; then
        echo "FAIL: $file (timeout tras ${SUITE_TIMEOUT_SECONDS}s, suite colgada)"
        failed=$((failed + 1))
        failed_suites+=("$file (timeout)")
        overall_status=1
    else
        echo "FAIL: $file"
        failed=$((failed + 1))
        failed_suites+=("$file")
        overall_status=1
    fi
}

to_windows_path() {
    # find (bajo Git Bash/MSYS) devuelve paths estilo "/c/Users/...". pwsh en Windows
    # resuelve ese formato de forma incorrecta (los antepone literal con "C:\", quedando
    # "C:\c\Users\..." -- ruta inexistente). Hallazgo real durante el desarrollo de este
    # script: sin esta conversion, Invoke-Pester fallaba en encontrar el archivo, $r quedaba
    # vacio y el exit code agregado era 0 EN SILENCIO -- exactamente el tipo de falso verde
    # que este issue busca eliminar. cygpath -w hace la conversion cuando esta disponible
    # (siempre lo esta en Git Bash); si no, se usa el path tal cual (entorno no-Windows).
    local p="$1"
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$p"
    else
        printf '%s' "$p"
    fi
}

run_ps1_suite() {
    local file="$1"
    local win_file
    win_file="$(to_windows_path "$file")"
    total=$((total + 1))
    echo "--- pwsh/Pester: $file ---"
    local tmp_out rc
    tmp_out="$(mktemp)"
    timeout -k 10 "$SUITE_TIMEOUT_SECONDS" pwsh -NoProfile -Command "\$r = Invoke-Pester -Script '$win_file' -PassThru; exit [int]\$r.FailedCount" > "$tmp_out" 2>&1
    rc=$?
    cat "$tmp_out"
    rm -f "$tmp_out"
    if [ "$rc" -eq 124 ]; then
        echo "FAIL: $file (timeout tras ${SUITE_TIMEOUT_SECONDS}s, suite colgada)"
        failed=$((failed + 1))
        failed_suites+=("$file (timeout)")
        overall_status=1
    elif [ "$rc" -ne 0 ]; then
        echo "FAIL: $file ($rc test(s) fallidos)"
        failed=$((failed + 1))
        failed_suites+=("$file")
        overall_status=1
    fi
}

while IFS= read -r f; do
    run_bash_suite "$f"
done < <(find "$ROOT_DIR" -name "*.Tests.sh" -not -path "*/node_modules/*" | sort)

if [ -z "${NO_PWSH:-}" ] && command -v pwsh >/dev/null 2>&1; then
    while IFS= read -r f; do
        run_ps1_suite "$f"
    done < <(find "$ROOT_DIR" -name "*.Tests.ps1" -not -path "*/node_modules/*" | sort)
else
    ps1_count=$(find "$ROOT_DIR" -name "*.Tests.ps1" -not -path "*/node_modules/*" | wc -l | tr -d ' ')
    if [ "$ps1_count" -gt 0 ]; then
        echo "SKIP suites PowerShell/Pester ($ps1_count encontradas): pwsh no disponible en PATH, omitiendo"
    fi
fi

echo ""
echo "=== Resumen run-all-tests ==="
echo "Suites corridas: $total, Fallidas: $failed"
if [ "$failed" -gt 0 ]; then
    echo "Suites con fallos:"
    for s in "${failed_suites[@]}"; do
        echo "  - $s"
    done
fi

exit $overall_status
