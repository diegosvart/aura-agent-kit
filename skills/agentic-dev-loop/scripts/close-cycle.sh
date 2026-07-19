#!/usr/bin/env bash
# Fase 1, Paso 5 del skill agentic-dev-loop: cierra el ciclo del dev-runner sin razonamiento
# de agente. Detecta si hay PR abierto con "Closes #<issue>" y aplica el label correspondiente.
set -euo pipefail

REPO="${1:?Uso: close-cycle.sh <owner>/<repo> <issue>}"
ISSUE="${2:?Uso: close-cycle.sh <owner>/<repo> <issue>}"

pr_number=$(gh pr list --repo "$REPO" --search "Closes #$ISSUE" --state open --json number --jq '.[0].number // empty')

if [ -n "$pr_number" ]; then
  gh issue edit "$ISSUE" --repo "$REPO" --remove-label in-progress --add-label review
  echo "PR #$pr_number encontrado — Issue #$ISSUE marcado review."
else
  gh issue edit "$ISSUE" --repo "$REPO" --remove-label in-progress --add-label ready
  echo "No se encontró PR abierto con \"Closes #$ISSUE\" — Issue #$ISSUE devuelto a ready. Confirmar que el dev-runner dejó comentario de bloqueo." >&2
fi
