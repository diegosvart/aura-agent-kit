#!/usr/bin/env bash
# Detecta PRs abiertas cuya rama base es 'main' cuando deberian apuntar a 'develop' -
# senal de que una rama/worktree se creo desde el default branch de GitHub (main) en vez
# de develop, como ocurre por defecto con worktree.baseRef:"fresh" de Claude Code.
# Caso real que motivo este script: PR #159 (feat/browser-control-and-version-check-fix)
# se ramifico y mergeo directo contra main, saltandose develop por completo -- ningun
# chequeo existente del harness lo detecto antes del merge. Ver
# docs/aura/specs/2026-08-29-claude-code-worktree-conflict-and-agent-browser.md.
#
# Excepcion legitima: el paso 'promote' de cut-release.sh abre PR base=main head=develop
# -- esa es la unica forma correcta de que una PR apunte a main.
#
# Requiere gh autenticado (usa el motor --jq embebido de gh, no depende del binario jq
# externo). Salida: una linea "BASE-BRANCH: ..." por cada PR sospechosa, vacio si no hay
# nada que reportar. Exit code: 0 siempre (informativo).
set -uo pipefail

command -v gh >/dev/null 2>&1 || exit 0
gh auth status >/dev/null 2>&1 || exit 0

gh pr list --state open --json number,baseRefName,headRefName \
  --jq '.[] | select(.baseRefName == "main" and .headRefName != "develop") | "\(.number)\t\(.headRefName)"' \
  2>/dev/null | while IFS=$'\t' read -r number head; do
    [ -z "$number" ] && continue
    echo "BASE-BRANCH: PR #$number ('$head' -> main) deberia apuntar a develop, no a main -- revisar si se creo desde un worktree/rama mal enraizada (ver agents/github.md -> tabla de prefijos)."
  done

exit 0
