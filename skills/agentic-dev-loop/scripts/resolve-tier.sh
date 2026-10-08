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

if echo "$body" | grep -qi '\*\*Complejidad:\*\* media'; then
  echo "sonnet"
  exit 0
fi

# Escalamiento reactivo (Issue #352): se cuenta el marcador que reject-review.sh publica en cada
# rechazo del verifier -- NO se interpreta prosa libre. Una regex sobre el vocabulario del
# verifier ("bloqueado|fallo", etc.) nunca matcheo "BLOQUEANTE"/"NO PASA", y cualquier
# vocabulario fijo vuelve a romperse con el siguiente texto que genere el LLM. El contrato es
# explicito entre los dos scripts; no "simplificar" de vuelta a matchear prosa.
REJECT_MARKER='<!-- aura:verifier-reject -->'

comment_bodies=$(gh issue view "$ISSUE" --repo "$REPO" --json comments --jq '.comments[].body')
fail_comments=$(printf '%s
' "$comment_bodies" | grep -c "^$REJECT_MARKER" || true)

if [ "$fail_comments" -ge 2 ]; then
  echo "opus"
elif [ "$fail_comments" -ge 1 ]; then
  echo "sonnet"
else
  echo "haiku"
fi
