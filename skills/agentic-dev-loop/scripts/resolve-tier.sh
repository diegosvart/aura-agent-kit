#!/usr/bin/env bash
# Fase 1, Paso 3 del skill agentic-dev-loop: resuelve el tier de modelo sin razonamiento
# de agente. Imprime a stdout uno de: haiku | sonnet | opus.
set -euo pipefail

REPO="${1:?Uso: resolve-tier.sh <owner>/<repo> <issue>}"
ISSUE="${2:?Uso: resolve-tier.sh <owner>/<repo> <issue>}"

body=$(gh issue view "$ISSUE" --repo "$REPO" --json body --jq '.body')

if echo "$body" | grep -qi '\*\*Complejidad:\*\* alta'; then
  echo "sonnet"
  exit 0
fi

fail_comments=$(gh issue view "$ISSUE" --repo "$REPO" --json comments \
  --jq '[.comments[] | select(.body | test("(?i)bloqueado|fall[oó]"))] | length')

if [ "$fail_comments" -ge 2 ]; then
  echo "opus"
elif [ "$fail_comments" -ge 1 ]; then
  echo "sonnet"
else
  echo "haiku"
fi
