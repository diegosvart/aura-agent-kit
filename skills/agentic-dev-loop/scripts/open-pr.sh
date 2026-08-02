#!/usr/bin/env bash
# Fase 1, Paso 4 (apertura de PR) del skill agentic-dev-loop, sin gastar razonamiento de agente.
# Imprime a stdout el número del PR creado.
#
# Hipotesis (P4): dos bugs reales motivan este script.
# 1. Un dev-runner corrio "gh pr create" sin --base explicito y el PR cayo al default branch
#    del repo (main) en vez de develop -- misma causa raiz que el gap de autoclose ya
#    documentado (default branch != rama de integracion). Caso real: Issues #75/#76 en otro
#    proyecto que usa este harness. Fix: --base develop queda hardcodeado en el script, nunca
#    es parametro ni decision del agente.
# 2. El keyword "Closes #N" ya se rompio una vez por traduccion (Issue #28/PR #41, "Cierra #28"
#    en vez de "Closes #28") pese a que el SKILL.md insistia explicitamente en el string exacto.
#    Fix: el script inyecta el keyword el mismo, el agente nunca lo escribe.
set -euo pipefail

REPO="${1:?Uso: open-pr.sh <owner>/<repo> <issue> <branch> <title> <body_file>}"
ISSUE="${2:?Uso: open-pr.sh <owner>/<repo> <issue> <branch> <title> <body_file>}"
BRANCH="${3:?Uso: open-pr.sh <owner>/<repo> <issue> <branch> <title> <body_file>}"
TITLE="${4:?Uso: open-pr.sh <owner>/<repo> <issue> <branch> <title> <body_file>}"
BODY_FILE="${5:?Uso: open-pr.sh <owner>/<repo> <issue> <branch> <title> <body_file>}"

if [ ! -f "$BODY_FILE" ]; then
  echo "No se encontró el archivo de resumen: $BODY_FILE" >&2
  exit 1
fi

tmp_body=$(mktemp)
trap 'rm -f "$tmp_body"' EXIT

{
  echo "Closes #$ISSUE"
  echo
  cat "$BODY_FILE"
} > "$tmp_body"

pr_output=$(gh pr create --repo "$REPO" --base develop --head "$BRANCH" --title "$TITLE" --body-file "$tmp_body" 2>&1) || {
  echo "$pr_output" >&2
  exit 1
}

pr_number=$(echo "$pr_output" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1)

if [ -z "$pr_number" ]; then
  echo "gh pr create no devolvió un número de PR reconocible. Output: $pr_output" >&2
  exit 1
fi

echo "$pr_number"
