#!/usr/bin/env bash
# Dedupe de prosa duplicada en agents/github.md ("Al Mergear una PR a Develop") y
# protocols/session_end.md ("Post-merge a develop"): verifica que un PR esta mergeado hacia
# develop y cierra el issue asociado con el comentario estandar. Cubre el gap ya documentado
# varias veces en project-log.md: default branch != develop hace que gh no autocierre el issue.
set -euo pipefail

REPO="${1:?Uso: post-merge.sh <owner>/<repo> <issue_n> <pr_n>}"
ISSUE="${2:?Uso: post-merge.sh <owner>/<repo> <issue_n> <pr_n>}"
PR="${3:?Uso: post-merge.sh <owner>/<repo> <issue_n> <pr_n>}"

pr_state=$(gh pr view "$PR" --repo "$REPO" --json state --jq '.state') || {
  echo "No se pudo consultar el PR #$PR en $REPO." >&2
  exit 1
}
pr_base=$(gh pr view "$PR" --repo "$REPO" --json baseRefName --jq '.baseRefName')
pr_merged_at=$(gh pr view "$PR" --repo "$REPO" --json mergedAt --jq '.mergedAt')

if [ "$pr_state" != "MERGED" ]; then
  echo "PR #$PR no está mergeado (state=$pr_state) — no se toca el Issue #$ISSUE." >&2
  exit 1
fi

if [ "$pr_base" != "develop" ]; then
  echo "PR #$PR fue mergeado hacia '$pr_base', no hacia 'develop' — no se cierra el Issue #$ISSUE automáticamente." >&2
  exit 1
fi

issue_state=$(gh issue view "$ISSUE" --repo "$REPO" --json state -q '.state') || {
  echo "No se pudo consultar el Issue #$ISSUE en $REPO." >&2
  exit 1
}

if [ "$issue_state" == "CLOSED" ]; then
  echo "Issue #$ISSUE ya estaba cerrado — nada que hacer."
  exit 0
fi

gh issue close "$ISSUE" --repo "$REPO" --comment "Implementado en PR #$PR (merged a develop $pr_merged_at)"
echo "Issue #$ISSUE cerrado — PR #$PR mergeado a develop $pr_merged_at."
