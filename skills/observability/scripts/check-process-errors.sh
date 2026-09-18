#!/usr/bin/env bash
# check-process-errors.sh — Detecta patrones repetidos en process-errors.jsonl (Issue #206,
# idea [021]). Fail-open, mismo patron que process-session.sh en session_start.md Paso 3.5:
# si no hay datos o el chequeo falla, no bloquea el resto del protocolo.
#
# Uso: check-process-errors.sh (sin argumentos), cwd en cualquier parte del repo.
# Exit code: siempre 0 (chequeo informativo, no bloqueante).
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
JSONL="$REPO_ROOT/.agent/memory/observability/process-errors.jsonl"

[ -f "$JSONL" ] || exit 0

python3 << EOPYTHON
import json

lines = []
with open(r"$JSONL", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            lines.append(json.loads(line))
        except json.JSONDecodeError:
            continue

# Ultimas 10 session_id distintas, por orden de aparicion mirando desde el final del archivo.
recent_sessions = []
for entry in reversed(lines):
    sid = entry.get("session_id")
    if sid not in recent_sessions:
        recent_sessions.append(sid)
    if len(recent_sessions) >= 10:
        break

recent_set = set(recent_sessions)
counts = {}
for entry in lines:
    if entry.get("session_id") in recent_set:
        tipo = entry.get("tipo")
        counts[tipo] = counts.get(tipo, 0) + 1

for tipo, count in counts.items():
    if count >= 3:
        print(f"PROCESS-ERROR-PATTERN: {tipo} aparecio {count} veces en las ultimas 10 sesiones -- considerar /auto-research")
EOPYTHON

exit 0
