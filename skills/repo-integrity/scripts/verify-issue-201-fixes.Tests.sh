#!/usr/bin/env bash
# Test de verify-issue-201-fixes.sh: el self-check de D2 debe matchear el texto real
# vigente en protocols/session_start.md, no un literal obsoleto de una versión anterior
# del formato del resumen ejecutivo (Bug #4 de Issue #285).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/repo-integrity/scripts/verify-issue-201-fixes.sh"

pass=0
fail=0

assert_ok() {
  local desc="$1"
  shift
  if "$@" >/tmp/verify-201-out.txt 2>&1; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    cat /tmp/verify-201-out.txt
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local needle="$2"
  if grep -qF "$needle" protocols/session_start.md; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc — '$needle' no se encontró en protocols/session_start.md"
    fail=$((fail + 1))
  fi
}

cd "$ROOT"

assert_contains "session_start.md contiene el texto real de reporte de topics" \
  "topics: <lista o \"sin topics\">"

assert_ok "verify-issue-201-fixes.sh sale con éxito contra el árbol real" \
  bash "$SCRIPT"

echo ""
echo "Resultado: $pass PASS, $fail FAIL"
[ "$fail" -eq 0 ]
