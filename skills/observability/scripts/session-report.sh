#!/bin/bash
#
# session-report.sh
#
# Informe agregado BAJO DEMANDA sobre .agent/memory/observability/sessions.jsonl
# (a diferencia de process-session.sh, que calcula métricas por sesión individual y corre
# automáticamente desde session_start.md Paso 3.5). Ver
# docs/aura/specs/2026-09-13-session-behavior-report-design.md — Issue #265.
#
# Uso:
#   session-report.sh [--since <ISO date>] [--since-session <session_id>]
#   (sin flags: procesa todas las filas de sessions.jsonl)
#   --since y --since-session son MUTUAMENTE EXCLUYENTES.
#
# Solo lectura: nunca modifica sessions.jsonl ni process-session.sh. La salida se imprime a
# stdout — nunca se escribe a un archivo versionado (ver AGENTS.md → "Qué se Versiona":
# análisis/informes ad-hoc son NO versionables, mismo motivo que el índice de observability
# en sí: expone patrón de comportamiento del agente).
#
# Responsabilidad de QUIEN INVOCA este script (no de este script): guardar la sección
# "Conclusiones" del informe en Engram con mem_save (topic_key: harness/session-behavior-report,
# ver skills/observability/SKILL.md). Engram es un tool MCP, no invocable desde bash — este
# script no llama a mem_save ni puede hacerlo.
#
# NOTA (mismo bug real documentado en process-session.sh, Issue #205): todas las rutas y
# valores que cruzan hacia los bloques Python embebidos van vía variable de entorno, nunca
# interpolados como literal dentro del heredoc — un heredoc de bash SIN comillas en el
# delimitador colapsa "\\" -> "\" antes de que Python lo vea, corrompiendo rutas de Windows
# (ej. transcript_path con backslashes). Por eso todo delimitador de heredoc acá va entre
# comillas simples ('EOPYTHON').
#

set -o pipefail

SINCE_DATE=""
SINCE_SESSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since)
            SINCE_DATE="$2"
            shift 2
            ;;
        --since-session)
            SINCE_SESSION="$2"
            shift 2
            ;;
        *)
            echo "ERROR: argumento desconocido: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -n "$SINCE_DATE" && -n "$SINCE_SESSION" ]]; then
    echo "ERROR: --since y --since-session son mutuamente excluyentes" >&2
    exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: No se pudo detectar PROJECT_ROOT (no es un repo git)" >&2
    exit 1
}

# SESSION_REPORT_INPUT permite overridear la ruta de entrada en tests (session-report.Tests.sh)
# sin tocar el sessions.jsonl real del repo. En uso normal no se define y se usa la ruta real.
SESSIONS_FILE="${SESSION_REPORT_INPUT:-$PROJECT_ROOT/.agent/memory/observability/sessions.jsonl}"

if [[ ! -f "$SESSIONS_FILE" ]]; then
    echo "INFO: no existe $SESSIONS_FILE — sin datos para el informe" >&2
    exit 0
fi

SESSIONS_FILE="$SESSIONS_FILE" SINCE_DATE="$SINCE_DATE" SINCE_SESSION="$SINCE_SESSION" python3 << 'EOPYTHON'
import json
import os
import re
import statistics
import sys
from datetime import datetime

# Forzar UTF-8 en stdout: en Windows (Git Bash / PowerShell) la consola puede quedar en
# un codepage distinto (cp1252) y mojibaguear caracteres no-ASCII (ej. "—", tildes).
try:
    sys.stdout.reconfigure(encoding='utf-8')
except AttributeError:
    pass

SESSIONS_FILE = os.environ['SESSIONS_FILE']
SINCE_DATE = os.environ.get('SINCE_DATE', '')
SINCE_SESSION = os.environ.get('SINCE_SESSION', '')

MIN_SAMPLE = 5          # Issue #231: umbral de muestra mínima para delegation_rate
THRESHOLD_RATE = 0.25   # Issue #231: umbral de delegation_rate (25%)


def parse_ts(raw):
    """Parsea un timestamp ISO 8601, tolerando 'Z' y fracciones de segundo >6 dígitos
    (formato real observado en sessions.jsonl, ej. '...4947602-04:00', 7 dígitos, que
    datetime.fromisoformat no acepta directo en todas las versiones de Python)."""
    if not raw:
        return None
    s = raw.replace('Z', '+00:00')
    s = re.sub(r'(\.\d{6})\d+', r'\1', s)
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        # Fallback: solo fecha (ej. --since 2026-09-10)
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
    print("## Informe de Comportamiento de Sesiones\n\nSin filas en sessions.jsonl — nada que informar.")
    sys.exit(0)

# --- Resolver rango (included) y rango anterior de igual tamaño (prior) ---
range_desc = "todas las filas"
if SINCE_SESSION:
    idx = None
    for i, r in enumerate(rows):
        if r.get('session_id') == SINCE_SESSION:
            idx = i
            break
    if idx is None:
        sys.stderr.write(f"ERROR: session_id no encontrado en sessions.jsonl: {SINCE_SESSION}\n")
        sys.exit(1)
    included = rows[idx:]
    prior_available = rows[:idx]
    range_desc = f"desde session_id={SINCE_SESSION} (inclusive)"
elif SINCE_DATE:
    since_dt = parse_ts(SINCE_DATE)
    if since_dt is None:
        sys.stderr.write(f"ERROR: --since no es una fecha ISO válida: {SINCE_DATE}\n")
        sys.exit(1)
    idx = len(rows)
    for i, r in enumerate(rows):
        ts = parse_ts(r.get('ended_at', ''))
        if ts is not None:
            # Comparar solo la parte naive si una de las dos carece de tz, para tolerar
            # --since sin offset (ej. solo fecha) contra filas con offset real.
            ts_cmp = ts.replace(tzinfo=None) if ts.tzinfo else ts
            since_cmp = since_dt.replace(tzinfo=None) if since_dt.tzinfo else since_dt
            if ts_cmp >= since_cmp:
                idx = i
                break
    included = rows[idx:]
    prior_available = rows[:idx]
    range_desc = f"desde {SINCE_DATE}"
else:
    included = rows
    prior_available = []

prior = prior_available[-len(included):] if len(prior_available) >= len(included) and included else []

# --- delegation_rate agregado ---
with_field = [r for r in included if isinstance(r.get('delegation_rate'), dict) and 'a' in r['delegation_rate']]
excluded_no_field = len(included) - len(with_field)

sum_a = sum(r['delegation_rate'].get('a', 0) or 0 for r in with_field)
sum_b = sum(r['delegation_rate'].get('b', 0) or 0 for r in with_field)
rows_with_a_positive = sum(1 for r in with_field if (r['delegation_rate'].get('a') or 0) > 0)
agg_rate = round(sum_b / sum_a, 4) if sum_a > 0 else None
insufficient_sample = rows_with_a_positive < MIN_SAMPLE


# --- tokens / duration: promedio, mediana, comparación con rango anterior ---
def stats_for(field, dataset):
    values = [r[field] for r in dataset if r.get(field) is not None]
    if not values:
        return None
    return {
        'n': len(values),
        'mean': round(statistics.mean(values), 2),
        'median': round(statistics.median(values), 2),
    }


tokens_stats = stats_for('output_tokens', included)
duration_stats = stats_for('duration_ms', included)
tokens_stats_prior = stats_for('output_tokens', prior) if prior else None
duration_stats_prior = stats_for('duration_ms', prior) if prior else None


def trend_line(label, cur, prev):
    if cur is None:
        return f"- {label}: sin datos en el rango pedido."
    if not prev:
        return (f"- {label}: promedio={cur['mean']}, mediana={cur['median']} (n={cur['n']}). "
                f"Sin rango anterior de igual tamaño disponible para comparar tendencia — "
                f"dato insuficiente.")
    delta = round(cur['mean'] - prev['mean'], 2)
    pct = round((delta / prev['mean']) * 100, 1) if prev['mean'] else None
    direction = "sin cambio" if delta == 0 else ("subió" if delta > 0 else "bajó")
    pct_txt = f" ({pct:+}%)" if pct is not None else ""
    return (f"- {label}: promedio={cur['mean']}, mediana={cur['median']} (n={cur['n']}) vs. "
            f"rango anterior promedio={prev['mean']}, mediana={prev['median']} (n={prev['n']}) "
            f"→ {direction}{pct_txt}.")


# --- distribución de tool_uses como proporciones ---
categories = ['llm', 'script_command', 'agent_delegated', 'other']
totals = {c: 0 for c in categories}
tool_uses_rows = 0
for r in included:
    tu = r.get('tool_uses')
    if isinstance(tu, dict):
        tool_uses_rows += 1
        for c in categories:
            totals[c] += tu.get(c, 0) or 0
grand_total = sum(totals.values())
proportions = {
    c: (round(totals[c] / grand_total, 4) if grand_total > 0 else None)
    for c in categories
}

# --- Reporte ---
lines = []
lines.append("## Informe de Comportamiento de Sesiones")
lines.append("")
lines.append(f"Rango: {range_desc} — {len(included)} fila(s) incluida(s) de {len(rows)} totales en sessions.jsonl.")
if malformed:
    lines.append(f"ADVERTENCIA: {malformed} línea(s) malformada(s) en sessions.jsonl fueron ignoradas.")
lines.append("")

lines.append("### delegation_rate agregado (Issue #231)")
lines.append(f"- Filas en el rango CON campo `delegation_rate`: {len(with_field)}")
lines.append(f"- Filas en el rango SIN campo `delegation_rate` (formato pre-migración, excluidas del cálculo): {excluded_no_field}")
lines.append(f"- Filas con a>0 (tamaño de muestra real): {rows_with_a_positive}")
if agg_rate is None:
    lines.append("- delegation_rate agregado: sin datos (sum(a)=0 en el rango).")
else:
    lines.append(f"- delegation_rate agregado: sum(b)={sum_b} / sum(a)={sum_a} = {agg_rate} ({round(agg_rate * 100, 2)}%)")
if insufficient_sample:
    lines.append(f"- MUESTRA INSUFICIENTE: {rows_with_a_positive} fila(s) con a>0 (< {MIN_SAMPLE} requeridas por Issue #231/subagent-dispatch.md). No se puede declarar el umbral cumplido con esta muestra.")
else:
    lines.append(f"- Muestra suficiente: {rows_with_a_positive} fila(s) con a>0 (>= {MIN_SAMPLE}).")
lines.append("")

lines.append("### Tokens y duración")
lines.append(trend_line("output_tokens", tokens_stats, tokens_stats_prior))
lines.append(trend_line("duration_ms", duration_stats, duration_stats_prior))
lines.append("")

lines.append("### Distribución de tool_uses (proporciones)")
if grand_total == 0:
    lines.append("- Sin datos de tool_uses en el rango.")
else:
    for c in categories:
        lines.append(f"- {c}: {totals[c]} ({round(proportions[c] * 100, 1)}%)")
    lines.append(f"- Total tool_uses en el rango: {grand_total} (sobre {tool_uses_rows} fila(s))")
lines.append("")

lines.append("### Conclusiones")
if insufficient_sample:
    lines.append(f"- El criterio de cierre del Issue #231 (delegation_rate >= {int(THRESHOLD_RATE*100)}% en >= {MIN_SAMPLE} sesiones) NO puede evaluarse todavía con este rango: muestra insuficiente ({rows_with_a_positive} fila(s) con a>0).")
elif agg_rate is not None and agg_rate >= THRESHOLD_RATE:
    lines.append(f"- El criterio de cierre del Issue #231 SE CUMPLE en este rango: delegation_rate={round(agg_rate*100,2)}% con {rows_with_a_positive} fila(s) con a>0 (>= {MIN_SAMPLE}).")
elif agg_rate is not None:
    lines.append(f"- Muestra suficiente ({rows_with_a_positive} filas con a>0), pero delegation_rate={round(agg_rate*100,2)}% NO alcanza el umbral del {int(THRESHOLD_RATE*100)}% del Issue #231.")
else:
    lines.append("- No hay datos suficientes de delegation_rate en este rango para evaluar el Issue #231.")

if tokens_stats_prior and tokens_stats:
    delta_pct = round(((tokens_stats['mean'] - tokens_stats_prior['mean']) / tokens_stats_prior['mean']) * 100, 1) if tokens_stats_prior['mean'] else None
    if delta_pct is not None and abs(delta_pct) >= 10:
        direction = "una suba" if delta_pct > 0 else "una baja"
        lines.append(f"- output_tokens muestra {direction} notable ({delta_pct:+}%) respecto al rango anterior de igual tamaño.")
    else:
        lines.append("- output_tokens no muestra una tendencia clara respecto al rango anterior (variación < 10%).")
else:
    lines.append("- output_tokens: dato insuficiente para afirmar tendencia (sin rango anterior de igual tamaño disponible).")

if duration_stats_prior and duration_stats:
    delta_pct = round(((duration_stats['mean'] - duration_stats_prior['mean']) / duration_stats_prior['mean']) * 100, 1) if duration_stats_prior['mean'] else None
    if delta_pct is not None and abs(delta_pct) >= 10:
        direction = "una suba" if delta_pct > 0 else "una baja"
        lines.append(f"- duration_ms muestra {direction} notable ({delta_pct:+}%) respecto al rango anterior de igual tamaño.")
    else:
        lines.append("- duration_ms no muestra una tendencia clara respecto al rango anterior (variación < 10%).")
else:
    lines.append("- duration_ms: dato insuficiente para afirmar tendencia (sin rango anterior de igual tamaño disponible).")

lines.append("")
lines.append("> Responsabilidad de quien invoca este informe: guardar esta sección de Conclusiones en")
lines.append("> Engram con mem_save (topic_key: harness/session-behavior-report). Este script no")
lines.append("> llama a Engram — es un tool MCP, no invocable desde este script bash.")

print("\n".join(lines))
EOPYTHON
exit $?
