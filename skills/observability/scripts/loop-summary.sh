#!/bin/bash
#
# loop-summary.sh
#
# Resumen agregado de un LOOP (batch de subagentes/forks) sobre
# .agent/memory/observability/sessions.jsonl — Modo 3 de skills/observability/SKILL.md
# (Issue #304, idea [032] Aura Control Panel, Enfoque C). A diferencia de session-report.sh
# (Modo 2, tendencia sobre un rango de tiempo genérico), este script está pensado para
# correr justo después de un batch de forks/subagentes y ver, de un vistazo, qué sesiones
# entraron en ese loop y cuánto costó en conjunto.
#
# Uso:
#   loop-summary.sh [--session-ids <id1,id2,...> | --since <ISO date>]
#   (sin flags: procesa todas las filas de sessions.jsonl)
#   --session-ids y --since son MUTUAMENTE EXCLUYENTES.
#
# Solo lectura: nunca modifica sessions.jsonl. La salida se imprime a stdout — nunca se
# escribe a un archivo versionado (ver AGENTS.md → "Qué se Versiona": el índice de
# observability y cualquier informe derivado de él son NO versionables, expone patrón de
# comportamiento del agente). Si se quiere conservar el resumen, publicarlo como Artifact
# (privado por defecto) o pegarlo en el chat — nunca commitearlo.
#
# Limitación conocida (documentada, no resuelta en este paso): sessions.jsonl no registra
# qué issue/PR quedó asociado a cada sesión — ese dato no se captura hoy en ningún punto del
# pipeline de observability. El listado por sesión lo señala explícitamente en vez de
# inventar o inferir un valor.
#
# NOTA (mismo bug real de Issue #205, ya evitado en process-session.sh y session-report.sh):
# heredoc sin comillas en el delimitador corrompe rutas de Windows con backslashes — por eso
# el delimitador va entre comillas simples ('EOPYTHON').
#

set -o pipefail

SESSION_IDS=""
SINCE_DATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-ids)
            SESSION_IDS="$2"
            shift 2
            ;;
        --since)
            SINCE_DATE="$2"
            shift 2
            ;;
        *)
            echo "ERROR: argumento desconocido: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -n "$SESSION_IDS" && -n "$SINCE_DATE" ]]; then
    echo "ERROR: --session-ids y --since son mutuamente excluyentes" >&2
    exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: No se pudo detectar PROJECT_ROOT (no es un repo git)" >&2
    exit 1
}

# LOOP_SUMMARY_INPUT permite overridear la ruta de entrada en tests (loop-summary.Tests.sh)
# sin tocar el sessions.jsonl real del repo. En uso normal no se define y se usa la ruta real.
SESSIONS_FILE="${LOOP_SUMMARY_INPUT:-$PROJECT_ROOT/.agent/memory/observability/sessions.jsonl}"

if [[ ! -f "$SESSIONS_FILE" ]]; then
    echo "INFO: no existe $SESSIONS_FILE — sin datos para el resumen" >&2
    exit 0
fi

SESSIONS_FILE="$SESSIONS_FILE" SESSION_IDS="$SESSION_IDS" SINCE_DATE="$SINCE_DATE" python3 << 'EOPYTHON'
import json
import os
import re
import sys
from datetime import datetime

# Forzar UTF-8 en stdout: en Windows (Git Bash / PowerShell) la consola puede quedar en un
# codepage distinto (cp1252) y mojibaguear caracteres no-ASCII (ej. "—", tildes).
try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

SESSIONS_FILE = os.environ['SESSIONS_FILE']
SESSION_IDS_RAW = os.environ.get('SESSION_IDS', '')
SINCE_DATE = os.environ.get('SINCE_DATE', '')

CATEGORIES = ['llm', 'script_command', 'agent_delegated', 'other']


def parse_ts(raw):
    """Parsea un timestamp ISO 8601, tolerando 'Z' y fracciones de segundo >6 dígitos
    (formato real observado en sessions.jsonl)."""
    if not raw:
        return None
    s = raw.replace('Z', '+00:00')
    s = re.sub(r'(\.\d{6})\d+', r'\1', s)
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        try:
            return datetime.fromisoformat(s[:10])
        except ValueError:
            return None


# --- Cargar todas las filas ---
rows = []
malformed = 0
with open(SESSIONS_FILE, encoding='utf-8', errors='replace') as f:
    for line in f:
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            malformed += 1

if not rows:
    print("## Resumen de Loop\n\nSin filas en sessions.jsonl — nada que resumir.")
    sys.exit(0)

# --- Resolver selección ---
if SESSION_IDS_RAW:
    requested = [s.strip() for s in SESSION_IDS_RAW.split(',') if s.strip()]
    by_id = {r.get('session_id'): r for r in rows if r.get('session_id')}
    missing = [s for s in requested if s not in by_id]
    if missing:
        sys.stderr.write(f"ERROR: session_id no encontrado(s) en sessions.jsonl: {', '.join(missing)}\n")
        sys.exit(1)
    # Preserva el orden en que aparecen en sessions.jsonl, no el orden pedido por el usuario.
    included = [r for r in rows if r.get('session_id') in set(requested)]
    selection_desc = f"lista de session_id ({len(requested)} pedido(s))"
elif SINCE_DATE:
    since_dt = parse_ts(SINCE_DATE)
    if since_dt is None:
        sys.stderr.write(f"ERROR: --since no es una fecha ISO válida: {SINCE_DATE}\n")
        sys.exit(1)
    idx = len(rows)
    for i, r in enumerate(rows):
        ts = parse_ts(r.get('ended_at', ''))
        if ts is not None:
            ts_cmp = ts.replace(tzinfo=None) if ts.tzinfo else ts
            since_cmp = since_dt.replace(tzinfo=None) if since_dt.tzinfo else since_dt
            if ts_cmp >= since_cmp:
                idx = i
                break
    included = rows[idx:]
    selection_desc = f"desde {SINCE_DATE}"
else:
    included = rows
    selection_desc = "todas las filas"

# --- Agregados ---
total_tokens = sum(r.get('output_tokens') or 0 for r in included)
total_duration = sum(r.get('duration_ms') or 0 for r in included)

totals = {c: 0 for c in CATEGORIES}
for r in included:
    tu = r.get('tool_uses')
    if isinstance(tu, dict):
        for c in CATEGORIES:
            totals[c] += tu.get(c, 0) or 0
grand_total_tool_uses = sum(totals.values())

with_field = [r for r in included if isinstance(r.get('delegation_rate'), dict) and 'a' in r['delegation_rate']]
sum_a = sum(r['delegation_rate'].get('a', 0) or 0 for r in with_field)
sum_b = sum(r['delegation_rate'].get('b', 0) or 0 for r in with_field)
agg_rate = round(sum_b / sum_a, 4) if sum_a > 0 else None

# --- Reporte ---
lines = []
lines.append("## Resumen de Loop")
lines.append("")
lines.append(f"Selección: {selection_desc} — {len(included)} sesion(es) incluida(s) de {len(rows)} totales en sessions.jsonl.")
if malformed:
    lines.append(f"ADVERTENCIA: {malformed} línea(s) malformada(s) en sessions.jsonl fueron ignoradas.")
lines.append("")

lines.append("### Agregados")
lines.append(f"- tokens totales: {total_tokens}")
lines.append(f"- duración total: {total_duration} ms (~{round(total_duration / 60000, 1)} min)")
if grand_total_tool_uses == 0:
    lines.append("- tool_uses: sin datos en la selección.")
else:
    for c in CATEGORIES:
        pct = round(totals[c] / grand_total_tool_uses * 100, 1) if grand_total_tool_uses else 0
        lines.append(f"- {c}: {totals[c]} ({pct}%)")
    lines.append(f"- total tool_uses: {grand_total_tool_uses}")
if agg_rate is None:
    lines.append("- delegation_rate agregado: sin datos (sum(a)=0 en la selección).")
else:
    lines.append(f"- delegation_rate agregado: sum(b)={sum_b} / sum(a)={sum_a} = {agg_rate} ({round(agg_rate * 100, 2)}%)")
lines.append("")

lines.append("### Sesiones incluidas")
for r in included:
    sid = r.get('session_id', '(sin session_id)')
    ended_at = r.get('ended_at', '(sin ended_at)')
    tokens = r.get('output_tokens', '—')
    duration = r.get('duration_ms', '—')
    lines.append(f"- `{sid}` — ended_at={ended_at}, tokens={tokens}, duration={duration}ms, resultado: no disponible en sessions.jsonl (buscar manualmente en Engram/transcript)")
lines.append("")

lines.append("> Este resumen se imprime a stdout — no se versiona (ver AGENTS.md → \"Qué se")
lines.append("> Versiona\"). Para conservarlo, publicarlo como Artifact (privado por defecto)")
lines.append("> o pegarlo en el chat.")

print("\n".join(lines))
EOPYTHON
exit $?
