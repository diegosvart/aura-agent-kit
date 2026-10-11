#!/usr/bin/env bash
# validate-pr-body.sh — Issue #301
#
# Hipotesis (P4): el PR #300 salio con "## Resumen / ## Plan de pruebas" porque el formato
# obligatorio vivia solo en prosa (agents/github.md) y el PR se creo sin pasar por open-pr.sh.
# Como open-pr.sh es la via unica del harness para abrir PRs, validar ahi estructuralmente
# convierte la regla en enforcement duro sin un hook de texto sobre `gh pr create`.
# Criterio observable: PRs nuevos del loop cumplen las 5 secciones (linea base: 14/40).
#
# Formato vigente: template unificado de Issue #332 (ver skills/agentic-dev-loop/SKILL.md).
# Solo valida headings; no exige ni prohibe footers de atribucion ni "Closes #N" (lo inyecta
# open-pr.sh).

PR_BODY_REQUIRED_SECTIONS=("Qué" "Beneficio" "Por qué" "Cómo" "Testing")

validate_pr_body() {
  local file="$1" section missing=()
  for section in "${PR_BODY_REQUIRED_SECTIONS[@]}"; do
    if ! tr -d '\r' < "$file" | grep -Eq "^## ${section}[[:space:]]*\$"; then
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
