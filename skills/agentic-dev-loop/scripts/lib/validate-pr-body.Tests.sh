#!/usr/bin/env bash
# validate-pr-body.Tests.sh — Issue #301
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPEN_PR="$SCRIPT_DIR/../open-pr.sh"
LIB="$SCRIPT_DIR/validate-pr-body.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
check() {
  if [ "$2" = "0" ]; then echo "✓ PASS — $1"; pass=$((pass + 1))
  else echo "✗ FAIL — $1"; [ -n "${3:-}" ] && echo "    detalle: $3"; fail=$((fail + 1)); fi
}

valid_body() {
  cat <<'B'
# Titulo

## Qué
Cambio concreto.

## Beneficio
Valor para el usuario.

## Por qué
Razon.

## Cómo
Enfoque.

## Testing
bash run-all-tests.sh: 0 fallidas.
B
}

# shellcheck source=/dev/null
source "$LIB" 2>/dev/null || { echo "✗ FAIL — no se pudo cargar $LIB"; exit 1; }

valid_body > "$TMP/ok.md"
out=$(validate_pr_body "$TMP/ok.md" 2>&1); rc=$?
check "body con todas las secciones requeridas pasa" "$rc" "$out"

printf '## Resumen\nx\n\n## Plan de pruebas\ny\n' > "$TMP/legacy.md"
out=$(validate_pr_body "$TMP/legacy.md" 2>&1); rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q "## Beneficio"
check "body '## Resumen / ## Plan de pruebas' (caso PR #300) es rechazado y nombra lo que falta" "$?" "$out"

valid_body | grep -v '^## Testing' > "$TMP/notest.md"
out=$(validate_pr_body "$TMP/notest.md" 2>&1); rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q "## Testing"
check "falta '## Testing' es rechazado" "$?" "$out"

valid_body | sed 's/^## Beneficio/## Beneficios extra/' > "$TMP/prefix.md"
validate_pr_body "$TMP/prefix.md" >/dev/null 2>&1
[ $? -ne 0 ]
check "'## Beneficios extra' no cuenta como '## Beneficio'" "$?"

{ valid_body; echo; echo '## Notas para el reviewer'; echo 'x'; } > "$TMP/extra.md"
out=$(validate_pr_body "$TMP/extra.md" 2>&1); rc=$?
check "secciones extra no afectan" "$rc" "$out"

{ valid_body; echo; echo "🤖 Generated with [Claude Code](x)"; } > "$TMP/footer.md"
out=$(validate_pr_body "$TMP/footer.md" 2>&1); rc=$?
check "el validador no exige ni prohibe el footer de atribucion" "$rc" "$out"

valid_body | sed 's/$/\r/' > "$TMP/crlf.md"
out=$(validate_pr_body "$TMP/crlf.md" 2>&1); rc=$?
check "headings con CRLF pasan" "$rc" "$out"

mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<G
#!/usr/bin/env bash
echo called >> "$TMP/gh.calls"
echo "https://github.com/o/r/pull/9"
G
chmod +x "$TMP/bin/gh"

out=$(PATH="$TMP/bin:$PATH" bash "$OPEN_PR" o/r 301 fix/x "t" "$TMP/legacy.md" 2>&1); rc=$?
[ $rc -ne 0 ] && [ ! -f "$TMP/gh.calls" ] && echo "$out" | grep -q "## Beneficio"
check "open-pr.sh rechaza body invalido sin invocar gh" "$?" "$out"

out=$(PATH="$TMP/bin:$PATH" bash "$OPEN_PR" o/r 301 fix/x "t" "$TMP/ok.md" 2>&1); rc=$?
[ $rc -eq 0 ] && [ "$out" = "9" ]
check "open-pr.sh con body valido crea el PR y devuelve el numero" "$?" "$out"

echo "---"; echo "$pass pasaron, $fail fallaron"
[ "$fail" -eq 0 ]
