#!/usr/bin/env bash
# Encapsula el bloque de creacion de rama de agents/github.md (tabla de prefijos + comando de
# checkout) para trabajo manual fuera del loop de agentic-dev-loop.
set -euo pipefail

REPO="${1:?Uso: new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>}"
ISSUE="${2:?Uso: new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>}"
TYPE="${3:?Uso: new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>}"
SLUG="${4:?Uso: new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>}"

case "$TYPE" in
  feature|fix|chore)
    base="develop"
    ;;
  hotfix)
    base="main"
    ;;
  *)
    echo "Tipo de rama desconocido: '$TYPE'. Valores válidos: feature, fix, chore, hotfix." >&2
    exit 1
    ;;
esac

branch="$TYPE/issue-$ISSUE-$SLUG"

if git show-ref --verify --quiet "refs/heads/$branch"; then
  echo "La rama '$branch' ya existe localmente." >&2
  exit 1
fi

if ! git fetch origin "$base"; then
  echo "No se pudo hacer fetch de '$base' en $REPO." >&2
  exit 1
fi

if ! git checkout "$base"; then
  echo "No se pudo cambiar a la rama base '$base'." >&2
  exit 1
fi

if ! git pull origin "$base"; then
  echo "No se pudo actualizar '$base' desde origin." >&2
  exit 1
fi

if ! git checkout -b "$branch"; then
  echo "No se pudo crear la rama '$branch'." >&2
  exit 1
fi

echo "$branch"
