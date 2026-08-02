#!/usr/bin/env bash
# Pasos B, C y D del algoritmo de deteccion de skills/repo-integrity/SKILL.md: clasifica una
# rama candidata sin razonamiento de agente. Corre hasta 10 veces por sesion (una por rama
# candidata detectada en protocols/session_start.md Paso 3) — es el de mayor volumen del
# barrido de scripting deterministico (idea [016]).
set -euo pipefail

REPO="${1:?Uso: classify-branch.sh <owner>/<repo> <branch>}"
BRANCH="${2:?Uso: classify-branch.sh <owner>/<repo> <branch>}"

# Paso B — commits exclusivos de la rama que referencien Closes/Fixes/Resolves #N.
# Usa el mensaje completo (%B), no --oneline: el keyword suele ir en el body, no en el subject
# (ej. commit 21fd2e8 real de este repo — "Closes #66" en el body, subject sin la referencia).
issue=$(git log "develop..$BRANCH" --format=%B \
  | grep -m1 -iE '(closes|fixes|resolves) #[0-9]+' \
  | grep -oE '#[0-9]+' | head -1 | tr -d '#' || true)

if [ -z "$issue" ]; then
  echo "CLEAN:no-issue-ref"
  exit 0
fi

# Paso C — estado del issue referenciado
state=$(gh issue view "$issue" --repo "$REPO" --json state -q '.state' 2>/dev/null) || {
  echo "No se pudo consultar el Issue #$issue en $REPO (404 o error de red)." >&2
  echo "CLEAN:no-issue-ref"
  exit 0
}

if [ "$state" != "CLOSED" ]; then
  echo "CLEAN:issue-open:$issue"
  exit 0
fi

# Paso D — PR mergeada hacia develop con head == la rama candidata
merged_pr=$(gh pr list --repo "$REPO" --head "$BRANCH" --state merged \
  --json number,baseRefName --jq '.[] | select(.baseRefName=="develop") | .number' | head -1)

if [ -n "$merged_pr" ]; then
  echo "CLEAN:merged:$issue:$merged_pr"
  exit 0
fi

echo "STRANDED:$issue"
