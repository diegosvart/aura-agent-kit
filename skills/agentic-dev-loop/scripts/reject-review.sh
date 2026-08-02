#!/usr/bin/env bash
# Fase 2, Paso 4 (veredicto "No pasa") del skill agentic-dev-loop, sin gastar razonamiento de
# agente. Simétrico a close-cycle.sh: ejecuta la consecuencia mecánica de un veredicto ya
# decidido por el verifier (el juicio real -- qué falta, con evidencia -- se publica antes con
# `gh issue comment`, no lo hace este script).
set -euo pipefail

REPO="${1:?Uso: reject-review.sh <owner>/<repo> <issue>}"
ISSUE="${2:?Uso: reject-review.sh <owner>/<repo> <issue>}"

gh issue edit "$ISSUE" --repo "$REPO" --remove-label review --add-label changes-requested

state=$(gh issue view "$ISSUE" --repo "$REPO" --json state --jq '.state')

if [ "$state" = "CLOSED" ]; then
  gh issue reopen "$ISSUE" --repo "$REPO"
  echo "Issue #$ISSUE marcado changes-requested y reabierto (estaba CLOSED por un merge prematuro)."
else
  echo "Issue #$ISSUE marcado changes-requested."
fi
