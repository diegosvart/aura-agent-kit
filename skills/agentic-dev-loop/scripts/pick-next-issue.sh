#!/usr/bin/env bash
# Fase 1, Paso 1 del skill agentic-dev-loop, sin gastar razonamiento de agente.
# Imprime a stdout el número del issue elegido (o nada si no hay ninguno apto).
# Diagnósticos y correcciones de label van a stderr.
set -euo pipefail

REPO="${1:?Uso: pick-next-issue.sh <owner>/<repo>}"

in_progress_count=$(gh issue list --repo "$REPO" --label in-progress --state open --json number --jq 'length')
if [ "$in_progress_count" -gt 0 ]; then
  echo "Ya hay un issue in-progress — no se toma ninguno nuevo." >&2
  exit 0
fi

# Recorre una lista de números de issue (ya ordenada) y devuelve el primero sin dependencias
# abiertas, corrigiendo a `blocked` los que sí las tienen. Se usa dos veces: primero sobre los
# issues `bug` (fix tiene prioridad sobre feat), luego sobre el resto.
try_pick_from() {
  local numbers="$1"
  local number body dep_line dep_num dep_gh_number dep_state dep_merged_prs

  for number in $numbers; do
    body=$(gh issue view "$number" --repo "$REPO" --json body --jq '.body')

    dep_line=$(echo "$body" | grep -m1 -i "Depende de:" || true)

    if [ -z "$dep_line" ] || echo "$dep_line" | grep -qi "nada"; then
      echo "$number"
      return 0
    fi

    dep_num=$(echo "$dep_line" | grep -oE 'Issue [0-9]+' | head -1 | grep -oE '[0-9]+' || true)

    if [ -z "$dep_num" ]; then
      echo "Issue #$number tiene dependencia no parseable (\"$dep_line\") — se omite, revisar manualmente." >&2
      continue
    fi

    dep_gh_number=$(gh issue list --repo "$REPO" --state all --json number,title \
      --jq ".[] | select(.title | test(\"^Issue $dep_num \")) | .number" | head -1)

    if [ -z "$dep_gh_number" ]; then
      echo "Issue #$number depende de \"Issue $dep_num\" pero no se encontró un issue de GitHub con ese prefijo de título — se omite." >&2
      continue
    fi

    # No usar solo el estado del issue: en un flujo con default branch != rama de integración
    # (ej. default=main, PRs mergean a develop), "Closes #N" no autocierra el issue al mergear,
    # así que un issue resuelto puede quedar OPEN indefinidamente. La señal real de "resuelto" es
    # que exista un PR mergeado con "Closes #<dep_gh_number>".
    dep_state=$(gh issue view "$dep_gh_number" --repo "$REPO" --json state --jq '.state')
    dep_merged_prs=$(gh pr list --repo "$REPO" --search "Closes #$dep_gh_number" --state merged --json number --jq 'length')

    if [ "$dep_state" != "CLOSED" ] && [ "$dep_merged_prs" -eq 0 ]; then
      echo "Issue #$number depende de #$dep_gh_number, que sigue $dep_state sin PR mergeado — corrigiendo label a blocked." >&2
      gh issue edit "$number" --repo "$REPO" --remove-label ready --add-label blocked >&2
      continue
    fi

    echo "$number"
    return 0
  done

  return 1
}

# Prioridad fix > feat: un issue `ready` con label `bug` se toma antes que cualquier `ready`
# sin ese label, aunque tenga número más alto. Sin ningún `bug` en `ready` hoy, fix_numbers
# queda vacío y el comportamiento es idéntico al de antes (orden ascendente por número).
fix_numbers=$(gh issue list --repo "$REPO" --label ready --label bug --state open --json number --jq 'sort_by(.number) | .[].number')
all_numbers=$(gh issue list --repo "$REPO" --label ready --state open --json number --jq 'sort_by(.number) | .[].number')
rest_numbers=$(comm -23 <(echo "$all_numbers" | sort) <(echo "$fix_numbers" | sort))

try_pick_from "$fix_numbers" && exit 0
try_pick_from "$rest_numbers" && exit 0

echo "No hay ningún issue ready sin dependencias abiertas." >&2
exit 0
