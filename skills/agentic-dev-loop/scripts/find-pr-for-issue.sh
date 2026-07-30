#!/usr/bin/env bash
# Fase 2, Paso 2 del skill agentic-dev-loop: ubica el PR asociado a un issue sin razonamiento
# de agente. Imprime a stdout el número de PR (falla con exit 1 si no encuentra ninguno).
set -euo pipefail

REPO="${1:?Uso: find-pr-for-issue.sh <owner>/<repo> <issue>}"
ISSUE="${2:?Uso: find-pr-for-issue.sh <owner>/<repo> <issue>}"

pr_number=$(gh pr list --repo "$REPO" --search "Closes #$ISSUE" --state all --json number --jq '.[0].number // empty')

if [ -z "$pr_number" ]; then
  pr_number=$(gh pr list --repo "$REPO" --json number,headRefName \
    --jq ".[] | select(.headRefName | test(\"^feature/issue-$ISSUE-\")) | .number" | head -1)
fi

if [ -z "$pr_number" ]; then
  echo "No se encontró PR para el Issue #$ISSUE." >&2
  exit 1
fi

echo "$pr_number"
