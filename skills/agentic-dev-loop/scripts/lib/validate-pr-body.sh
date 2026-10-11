#!/usr/bin/env bash
# validate-pr-body.sh — Issue #301, #382
#
# Hipotesis (P4): el PR #300 salio con "## Resumen / ## Plan de pruebas" porque el formato
# obligatorio vivia solo en prosa (agents/github.md) y el PR se creo sin pasar por open-pr.sh.
# Validar estructuralmente en open-pr.sh (#301) y en CI (#382, .github/workflows/pr-body.yml)
# convierte la regla en enforcement duro, tambien para PRs creados o editados a mano.
# Criterio observable: PRs nuevos cumplen las 5 secciones (linea base: 14/40).
#
# Formato vigente: template unificado de Issue #332 (ver skills/agentic-dev-loop/SKILL.md).
# Solo valida headings fuera de bloques de codigo (fences); no exige ni prohibe footers de
# atribucion ni "Closes #N" (lo inyecta open-pr.sh).

PR_BODY_REQUIRED_SECTIONS=("Qué" "Beneficio" "Por qué" "Cómo" "Testing")

# Emite solo las lineas fuera de fences (3+ backticks o 3+ tildes, hasta 3 espacios de
# indentacion; cierra con el mismo caracter y longitud >=). Fence sin cerrar: lo posterior se
# ignora (fail-closed).
strip_fenced_blocks() {
  tr -d '\r' | awk '
    function fence_run(line,   m) {
      if (match(line, /^ ? ? ?(```+|~~~+)/)) {
        m = substr(line, RSTART, RLENGTH)
        sub(/^ +/, "", m)
        return m
      }
      return ""
    }
    {
      f = fence_run($0)
      if (!in_fence) {
        if (f != "") { in_fence = 1; ch = substr(f, 1, 1); len = length(f); next }
        print
      } else if (f != "" && substr(f, 1, 1) == ch && length(f) >= len) {
        rest = substr($0, index($0, f) + length(f))
        if (rest ~ /^[ \t]*$/) in_fence = 0
      }
    }'
}

validate_pr_body() {
  local file="$1" section missing=() visible
  if [ ! -f "$file" ]; then
    echo "El archivo del body del PR no existe: $file" >&2
    return 1
  fi
  visible="$(strip_fenced_blocks < "$file")"
  for section in "${PR_BODY_REQUIRED_SECTIONS[@]}"; do
    if ! printf '%s\n' "$visible" | grep -Eq "^## ${section}[[:space:]]*\$"; then
      missing+=("## ${section}")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "El body del PR no sigue el formato obligatorio (agents/github.md > Formato de PR body)." >&2
    echo "Secciones faltantes: ${missing[*]}" >&2
    echo "Requeridas: ## Qué, ## Beneficio, ## Por qué, ## Cómo, ## Testing (opcionales: ## Criterios de Aceptación, ## Notas para el reviewer, ## Decisiones)." >&2
    return 1
  fi
  return 0
}
