#!/usr/bin/env bash
# Wrapper de verificación resuelto vía .agent/memory/session-stack.json.
# Corre lint/typecheck/test y devuelve un resumen corto — no vuelca el output completo
# al contexto del agente salvo que algo falle (ahí sí, el fragmento relevante).
set -uo pipefail

STACK_FILE=".agent/memory/session-stack.json"

if [ ! -f "$STACK_FILE" ]; then
  echo "No existe $STACK_FILE — generarlo antes de correr el loop (Paso 0 del skill)." >&2
  exit 2
fi

# Evita depender de jq (no siempre disponible en el entorno del stack); usa python3, que
# ya suele estar presente para resolver stacks y es más portable en Windows/Linux/macOS.
read_field() {
  python3 -c "import json,sys; d=json.load(open('$STACK_FILE')); print(d.get('$1') or '')"
}

lint_cmd=$(read_field lint)
typecheck_cmd=$(read_field typecheck)
test_cmd=$(read_field test)

status=0

run_check() {
  local name="$1" cmd="$2"
  if [ -z "$cmd" ]; then
    return 0
  fi
  local output rc
  output=$(eval "$cmd" 2>&1)
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "OK $name — $(echo "$output" | tail -1)"
  else
    echo "FAIL $name (exit $rc)"
    echo "$output" | tail -30
    status=1
  fi
}

run_check "lint" "$lint_cmd"
run_check "typecheck" "$typecheck_cmd"
run_check "test" "$test_cmd"

exit $status
