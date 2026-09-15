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
# Se recolectan TODAS las referencias de todos los commits exclusivos (no solo la primera) —
# una rama puede referenciar un issue reciente abierto y, en un commit mas viejo, un issue ya
# cerrado sin PR mergeada; mirar solo el primer match dejaba ese caso sin detectar (Issue #285).
issues=$(git log "develop..$BRANCH" --format=%B \
  | grep -oiE '(closes|fixes|resolves) #[0-9]+' \
  | grep -oE '#[0-9]+' | tr -d '#' | awk '!seen[$0]++' || true)

if [ -z "$issues" ]; then
  echo "CLEAN:no-issue-ref"
  exit 0
fi

# Paso D — PR mergeada hacia develop con head == la rama candidata (chequeo por rama, no por
# issue: si la rama ya se mergeo, cualquier issue que cierre cubre esa referencia).
merged_pr=$(gh pr list --repo "$REPO" --head "$BRANCH" --state merged \
  --json number,baseRefName --jq '.[] | select(.baseRefName=="develop") | .number' | head -1)

first_open=""
first_closed=""

for issue in $issues; do
  # Paso C — estado del issue referenciado
  state=$(gh issue view "$issue" --repo "$REPO" --json state -q '.state' 2>/dev/null) || {
    echo "No se pudo consultar el Issue #$issue en $REPO (404 o error de red)." >&2
    continue
  }

  if [ "$state" != "CLOSED" ]; then
    [ -z "$first_open" ] && first_open="$issue"
    continue
  fi

  [ -z "$first_closed" ] && first_closed="$issue"

  if [ -z "$merged_pr" ]; then
    echo "STRANDED:$issue"
    exit 0
  fi
done

if [ -n "$first_closed" ]; then
  echo "CLEAN:merged:$first_closed:$merged_pr"
  exit 0
fi

if [ -n "$first_open" ]; then
  echo "CLEAN:issue-open:$first_open"
  exit 0
fi

echo "CLEAN:no-issue-ref"
