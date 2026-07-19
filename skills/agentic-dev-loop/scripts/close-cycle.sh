#!/usr/bin/env bash
# Fase 1, Paso 5 del skill agentic-dev-loop: cierra el ciclo del dev-runner sin razonamiento
# de agente. Detecta si hay PR abierto con "Closes #<issue>" y aplica el label correspondiente.
#
# Hipotesis (P4, 2026-07-19): si este script solo confia en el keyword "Closes #N", cualquier
# discrepancia (el dev-runner lo tradujo, typo, orden distinto) hace que un PR real y abierto se
# trate como inexistente y el issue se devuelva a `ready` encima de un PR legitimo en curso.
# Caso real: Issue #28 / PR #41 (memo-digital), el dev-runner escribio "Cierra #28" en vez de
# "Closes #28". find-pr-for-issue.sh ya mitiga esto con un fallback por headRefName; se aplica el
# mismo fallback aqui sin cambiar el contrato del script (sigue devolviendo review/ready).
set -euo pipefail

REPO="${1:?Uso: close-cycle.sh <owner>/<repo> <issue>}"
ISSUE="${2:?Uso: close-cycle.sh <owner>/<repo> <issue>}"

open_pr=$(gh pr list --repo "$REPO" --search "Closes #$ISSUE" --state open --json number --jq '.[0].number // empty')

if [ -z "$open_pr" ]; then
  open_pr=$(gh pr list --repo "$REPO" --json number,headRefName,state \
    --jq ".[] | select(.headRefName | test(\"^feature/issue-$ISSUE-\")) | select(.state==\"OPEN\") | .number" | head -1)
  if [ -n "$open_pr" ]; then
    echo "PR #$open_pr encontrado por headRefName, no por keyword \"Closes #$ISSUE\" — revisar el body del PR, GitHub no lo autocerrara al mergear." >&2
  fi
fi

if [ -n "$open_pr" ]; then
  gh issue edit "$ISSUE" --repo "$REPO" --remove-label in-progress --add-label review
  echo "PR #$open_pr encontrado — Issue #$ISSUE marcado review."
  exit 0
fi

# Ausencia de PR abierto no basta: si el issue ya se cerró en un ciclo previo (con default
# branch != rama de integración, ver "Errores Comunes" de SKILL.md), su PR aparece como merged,
# no como open. Devolver el issue a `ready` en ese caso corrompe el estado (queda con dos
# labels de flujo a la vez) — se descubrió corriendo close-cycle.sh sobre el Issue #27 real.
merged_pr=$(gh pr list --repo "$REPO" --search "Closes #$ISSUE" --state merged --json number --jq '.[0].number // empty')

if [ -n "$merged_pr" ]; then
  echo "Issue #$ISSUE ya tiene un PR mergeado (#$merged_pr) con \"Closes #$ISSUE\" — no se toca ningún label. close-cycle.sh no debería correr sobre un issue ya resuelto; revisar por qué se re-ejecutó." >&2
  exit 1
fi

gh issue edit "$ISSUE" --repo "$REPO" --remove-label in-progress --add-label ready
echo "No se encontró PR (abierto ni mergeado) con \"Closes #$ISSUE\" — Issue #$ISSUE devuelto a ready. Confirmar que el dev-runner dejó comentario de bloqueo." >&2
