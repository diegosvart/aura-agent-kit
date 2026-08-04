#!/usr/bin/env bash
# Completa el gap documentado en docs/aura/experiments/2026-08-04-limpieza-rama-local-post-merge.md:
# post-merge.sh cierra el issue asociado a un PR mergeado pero nunca toca la rama local — queda
# viva indefinidamente hasta una limpieza manual (ver protocols/session_start.md, Paso 3).
#
# Modo dry-run (default): reporta si hay una rama local a limpiar y el comando exacto para
# hacerlo. NO borra nada — el agente debe pedir confirmación al usuario antes de re-invocar con
# --delete (regla del harness: nunca ejecutar acciones destructivas sin aprobación).
set -euo pipefail

REPO="${1:?Uso: cleanup-merged-branch.sh <owner>/<repo> <pr_n> [--delete]}"
PR="${2:?Uso: cleanup-merged-branch.sh <owner>/<repo> <pr_n> [--delete]}"
MODE="${3:-}"

pr_state=$(gh pr view "$PR" --repo "$REPO" --json state --jq '.state') || {
  echo "No se pudo consultar el PR #$PR en $REPO." >&2
  exit 1
}
pr_base=$(gh pr view "$PR" --repo "$REPO" --json baseRefName --jq '.baseRefName')
branch=$(gh pr view "$PR" --repo "$REPO" --json headRefName --jq '.headRefName')

if [ "$pr_state" != "MERGED" ]; then
  echo "PR #$PR no está mergeado (state=$pr_state) — no se toca ninguna rama local." >&2
  exit 1
fi

if [ "$pr_base" != "develop" ]; then
  echo "PR #$PR fue mergeado hacia '$pr_base', no hacia 'develop' — no se asume que la rama esté segura para borrar." >&2
  exit 1
fi

if ! git show-ref --verify --quiet "refs/heads/$branch"; then
  echo "No existe rama local '$branch' — nada que limpiar."
  exit 0
fi

if ! git branch --merged develop | grep -qx "  $branch"; then
  echo "La rama local '$branch' existe pero NO aparece como mergeada en develop localmente (¿falta git fetch/pull?) — no se borra automáticamente." >&2
  echo "Sugerido: git fetch origin develop && git checkout develop && git pull, y volver a correr este script." >&2
  exit 1
fi

if [ "$MODE" == "--delete" ]; then
  current=$(git branch --show-current)
  if [ "$current" == "$branch" ]; then
    git checkout develop
  fi
  git branch -d "$branch"
  echo "Rama local '$branch' borrada (PR #$PR mergeado a develop)."
else
  echo "Rama local '$branch' está mergeada en develop y lista para borrar."
  echo "Confirmar con el usuario y volver a correr: cleanup-merged-branch.sh $REPO $PR --delete"
fi
