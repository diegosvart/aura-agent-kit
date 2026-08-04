#!/usr/bin/env bash
# Detecta si el tag mas reciente alcanzable desde main dejo de ser ancestro de develop -
# senal de que falta el sync-back documentado en agents/github.md -> "Proceso de Release".
# Caso real que motivo este script: PR #119 (tag v2.2.0 quedo fuera de la ancestria de
# develop tras bookkeeping post-release sin sync-back, PRs #117/#118).
# Salida: linea "DRIFT: ..." si hay drift, vacio si no hay nada que reportar.
# Exit code: 0 siempre (chequeo informativo, nunca bloqueante).
set -uo pipefail

MAIN_REF=$(git rev-parse --verify main 2>/dev/null || git rev-parse --verify origin/main 2>/dev/null || echo "")
DEVELOP_REF=$(git rev-parse --verify develop 2>/dev/null || git rev-parse --verify origin/develop 2>/dev/null || echo "")

if [ -z "$MAIN_REF" ] || [ -z "$DEVELOP_REF" ]; then
  exit 0
fi

latest_tag=$(git tag -l --sort=-version:refname --merged "$MAIN_REF" 2>/dev/null | head -1)

if [ -z "$latest_tag" ]; then
  exit 0
fi

if git merge-base --is-ancestor "$latest_tag" "$DEVELOP_REF" 2>/dev/null; then
  exit 0
fi

echo "DRIFT: el tag '$latest_tag' (ultimo release en main) no es ancestro de develop. Falta sync-back (ver agents/github.md -> Proceso de Release)."
exit 0
