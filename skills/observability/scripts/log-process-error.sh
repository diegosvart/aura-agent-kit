#!/usr/bin/env bash
# log-process-error.sh — Registra un error de proceso del agente (Issue #206, idea [021])
#
# Uso: log-process-error.sh <owner>/<repo> <tipo> "<descripcion>" ["<afectado>"]
#
# Autodeclarado por el agente en el momento en que detecta/corrige el error -- no inferido
# post-hoc del transcript (a diferencia de delegation_rate, un error de proceso ya es un
# evento discreto observable en el momento). Appendea una linea JSON a
# .agent/memory/observability/process-errors.jsonl (gitignored, relativo a la raiz del repo).
#
# Taxonomia cerrada de <tipo> (no lista abierta):
#   branch-wrong-base       -- rama creada desde el HEAD equivocado
#   merge-order              -- orden de merge incorrecto
#   no-retry-after-rejection -- no se reintento una accion tras un rechazo
#   other                    -- cualquier otro caso, obliga a descripcion libre
set -uo pipefail

TAXONOMY=("branch-wrong-base" "merge-order" "no-retry-after-rejection" "other")

if [ "$#" -lt 3 ]; then
  echo "Uso: log-process-error.sh <owner>/<repo> <tipo> \"<descripcion>\" [\"<afectado>\"]" >&2
  echo "Taxonomia cerrada de <tipo>: ${TAXONOMY[*]}" >&2
  exit 1
fi

repo_slug="$1"
tipo="$2"
descripcion="$3"
afectado="${4:-}"

is_valid_tipo=0
for t in "${TAXONOMY[@]}"; do
  if [ "$t" = "$tipo" ]; then
    is_valid_tipo=1
    break
  fi
done

if [ "$is_valid_tipo" -ne 1 ]; then
  echo "ERROR: tipo '$tipo' no esta en la taxonomia cerrada. Valores validos: ${TAXONOMY[*]}" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
OUT_DIR="$REPO_ROOT/.agent/memory/observability"
OUT_FILE="$OUT_DIR/process-errors.jsonl"
mkdir -p "$OUT_DIR"

session_id="${CLAUDE_SESSION_ID:-unknown}"
logged_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

REPO_SLUG="$repo_slug" TIPO="$tipo" DESCRIPCION="$descripcion" AFECTADO="$afectado" \
SESSION_ID="$session_id" LOGGED_AT="$logged_at" python3 << 'EOPYTHON' >> "$OUT_FILE"
import json
import os

entry = {
    "logged_at": os.environ["LOGGED_AT"],
    "session_id": os.environ["SESSION_ID"],
    "tipo": os.environ["TIPO"],
    "descripcion": os.environ["DESCRIPCION"],
    "afectado": os.environ["AFECTADO"],
    "corregido": True,
}
print(json.dumps(entry, ensure_ascii=False))
EOPYTHON

exit 0
