#!/bin/bash
#
# process-session.sh
#
# Procesa entradas de .agent/memory/observability/sessions-index.jsonl:
# - Lee cada entrada (session_id, transcript_path, ended_at)
# - Si ya fue procesada (session_id existe en sessions.jsonl), la salta
# - Si el transcript_path no existe, emite error a stderr y continúa
# - Parsea el transcript JSONL y calcula:
#   * output_tokens: suma de message.usage.output_tokens de todos los mensajes assistant
#   * tool_uses: conteo por tipo (llm: Edit/Write/Read; script_command: Bash/PowerShell;
#                agent_delegated: Agent; other: todo lo demás)
#   * duration_ms: diferencia entre primer y último timestamp ISO en el transcript
#   * delegation_rate: ver .aura/rules/subagent-dispatch.md (Issue #179) — {a, b, rate}
#       a = triggers de protocols/router.md detectados mecánicamente por keyword-matching
#           contra el texto de la sesión (ambiguo → se excluye, no se infiere)
#       b = invocaciones del Agent tool cuya notificación de finalización registra
#           tool_uses > 3 (evita contar delegación cosmética de bajo volumen)
#       rate = b/a, o null si a == 0
# - Appendea resultado a .agent/memory/observability/sessions.jsonl
#
# Idempotente: mantiene registro interno de qué session_id ya procesó (leyendo sessions.jsonl)
#

set -o pipefail

# Detectar directorio del proyecto
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "ERROR: No se pudo detectar PROJECT_ROOT (no es un repo git)" >&2
    exit 1
}

SESSIONS_INDEX="$PROJECT_ROOT/.agent/memory/observability/sessions-index.jsonl"
SESSIONS_OUTPUT="$PROJECT_ROOT/.agent/memory/observability/sessions.jsonl"
ROUTER_MD="$PROJECT_ROOT/protocols/router.md"

# Crear directorio de observability si no existe
mkdir -p "$(dirname "$SESSIONS_OUTPUT")"

# Cargar session_ids ya procesados en un archivo temporal para comparación
PROCESSED_FILE=$(mktemp)
trap "rm -f $PROCESSED_FILE" EXIT

if [[ -f "$SESSIONS_OUTPUT" ]]; then
    python3 << EOPYTHON
import json
try:
    with open('$SESSIONS_OUTPUT') as f:
        for line in f:
            if line.strip():
                entry = json.loads(line)
                print(entry.get('session_id', ''))
except:
    pass
EOPYTHON
fi > "$PROCESSED_FILE"

# Función para calcular métricas del transcript
calculate_metrics() {
    local transcript_path="$1"

    if [[ ! -f "$transcript_path" ]]; then
        echo "ERROR: transcript_path no existe: $transcript_path" >&2
        return 1
    fi

    # Usar Python para procesar el JSONL
    python3 << EOPYTHON
import json
import sys
from datetime import datetime

output_tokens = 0
tool_uses = {'llm': 0, 'script_command': 0, 'agent_delegated': 0, 'other': 0}
timestamps = []

try:
    with open('$transcript_path', encoding='utf-8', errors='replace') as f:
        for line in f:
            if not line.strip():
                continue
            try:
                entry = json.loads(line)

                # Contar output_tokens
                if entry.get('type') == 'assistant' and 'message' in entry:
                    msg = entry['message']
                    if 'usage' in msg:
                        output_tokens += msg['usage'].get('output_tokens', 0)

                    # Contar tool_uses
                    if 'content' in msg:
                        for content_item in msg['content']:
                            if content_item.get('type') == 'tool_use':
                                tool_name = content_item.get('name', 'unknown')
                                if tool_name in ('Edit', 'Write', 'Read'):
                                    tool_uses['llm'] += 1
                                elif tool_name in ('Bash', 'PowerShell'):
                                    tool_uses['script_command'] += 1
                                elif tool_name == 'Agent':
                                    tool_uses['agent_delegated'] += 1
                                else:
                                    tool_uses['other'] += 1

                # Recolectar timestamps
                if 'timestamp' in entry:
                    timestamps.append(entry['timestamp'])
            except json.JSONDecodeError:
                pass  # Skip malformed lines

    # Calcular duration_ms
    duration_ms = None
    if len(timestamps) > 1:
        # Parse ISO 8601 timestamps and calculate difference
        ts_list = sorted(timestamps)
        first = ts_list[0].replace('Z', '+00:00')
        last = ts_list[-1].replace('Z', '+00:00')
        try:
            dt_first = datetime.fromisoformat(first)
            dt_last = datetime.fromisoformat(last)
            duration_ms = int((dt_last - dt_first).total_seconds() * 1000)
        except:
            duration_ms = None
    elif len(timestamps) == 1:
        duration_ms = 0

    result = {
        'output_tokens': output_tokens,
        'tool_uses': tool_uses,
        'duration_ms': duration_ms
    }
    print(json.dumps(result))
except Exception as e:
    sys.stderr.write(f"Error processing transcript: {e}\\n")
    sys.exit(1)
EOPYTHON
}

# Función para calcular delegation_rate (Issue #179 / .aura/rules/subagent-dispatch.md)
calculate_delegation_rate() {
    local transcript_path="$1"

    if [[ ! -f "$transcript_path" ]]; then
        echo '{"a":0,"b":0,"rate":null}'
        return 0
    fi

    python3 << EOPYTHON
import json
import re

ROUTER_MD = r'''$ROUTER_MD'''
TRANSCRIPT = r'''$transcript_path'''

# --- Denominador a: triggers de router.md detectados mecánicamente ---
# Palabras genéricas frecuentes en las columnas de router.md que, solas, no distinguen
# ningún trigger en particular (verbos comunes, conectores, metadata de la tabla misma).
STOPWORDS = {
    'situacion', 'archivos', 'cargar', 'trigger', 'archivo', 'protocols',
    'session', 'skills', 'agents', 'existe', 'plan', 'nuevo', 'nueva',
    'antes', 'despues', 'cuando', 'donde', 'usuario', 'quiere', 'primera',
    'interaccion', 'menciona', 'seguimos', 'continuemos', 'describe',
    'trabajo', 'completa', 'revision', 'sesion', 'inicio', 'proyecto',
    'cambiar', 'quiere', 'pide', 'avisa', 'cualquier', 'define', 'corresponde',
    'sobre', 'esta', 'tabla', 'terminamos', 'cerramos', 'trabajo',
}

# Requiere >=2 keywords específicos co-ocurriendo en el mismo texto de sesión — un solo
# verbo genérico ("seguimos", "crear") no alcanza para afirmar que el trigger aplicó.
MIN_KEYWORDS_PER_ROW = 2

def keywords(text):
    words = re.findall(r"[a-záéíóúñü]{6,}", text.lower())
    return sorted(set(w for w in words if w not in STOPWORDS))

def row_matches(row_keywords, haystack):
    if len(row_keywords) < MIN_KEYWORDS_PER_ROW:
        return False  # ambiguo (muy pocas señales específicas) → se excluye, no se infiere
    return all(w in haystack for w in row_keywords)

rows = []
try:
    with open(ROUTER_MD, encoding='utf-8') as f:
        in_table = False
        for line in f:
            line = line.rstrip('\\n')
            if line.strip().startswith('| Situación'):
                in_table = True
                continue
            if in_table:
                if not line.strip().startswith('|'):
                    if line.strip() == '':
                        continue
                    in_table = False
                    continue
                if set(line.strip()) <= set('|-: '):
                    continue  # separator row
                cells = [c.strip() for c in line.strip().strip('|').split('|')]
                if len(cells) < 3:
                    continue
                trigger_text = cells[2]
                row_keywords = keywords(trigger_text)
                if row_keywords:
                    rows.append({'situacion': cells[0], 'keywords': row_keywords})
except FileNotFoundError:
    pass

SYSTEM_BLOCK_RE = re.compile(
    r'<system-reminder>.*?</system-reminder>|<claude-md-context>.*?</claude-md-context>',
    re.DOTALL,
)

def strip_injected_context(text):
    # Excluye bloques inyectados por el sistema (ej. dump de CLAUDE.md/AGENTS.md/router.md
    # como contexto) — sin esto, el propio texto de router.md aparece verbatim en el
    # transcript y matchea trivialmente contra sí mismo (falso positivo ~100%).
    return SYSTEM_BLOCK_RE.sub(' ', text)

haystack = ''
try:
    with open(TRANSCRIPT, encoding='utf-8', errors='replace') as f:
        for line in f:
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = entry.get('message', {})
            content = msg.get('content')
            if isinstance(content, str):
                haystack += ' ' + strip_injected_context(content).lower()
            elif isinstance(content, list):
                for item in content:
                    if isinstance(item, dict) and item.get('type') == 'text':
                        haystack += ' ' + strip_injected_context(item.get('text', '')).lower()
except FileNotFoundError:
    pass

a = sum(1 for row in rows if row_matches(row['keywords'], haystack))

# --- Numerador b: invocaciones del Agent tool con tool_uses > 3 ---
# Cada notificación de finalización puede aparecer más de una vez en el transcript
# (se re-escribe cuando se re-muestra como contexto) — deduplicar por task-id, no por
# ocurrencia cruda del tag, o se cuenta la misma delegación varias veces.
b = 0
try:
    with open(TRANSCRIPT, encoding='utf-8', errors='replace') as f:
        full_text = f.read()
    seen_task_ids = set()
    for block in re.finditer(
        r'<task-notification>(.*?)</task-notification>', full_text, re.DOTALL
    ):
        block_text = block.group(1)
        id_match = re.search(r'<task-id>(.*?)</task-id>', block_text)
        uses_match = re.search(r'<tool_uses>(\\d+)</tool_uses>', block_text)
        if not id_match or not uses_match:
            continue
        task_id = id_match.group(1)
        if task_id in seen_task_ids:
            continue
        seen_task_ids.add(task_id)
        if int(uses_match.group(1)) > 3:
            b += 1
except FileNotFoundError:
    pass

rate = round(b / a, 4) if a > 0 else None

print(json.dumps({'a': a, 'b': b, 'rate': rate}))
EOPYTHON
}

# Procesar índice
entries_processed=0
entries_skipped=0
entries_failed=0

if [[ ! -f "$SESSIONS_INDEX" ]]; then
    echo "WARN: No se encontró sessions-index.jsonl en $SESSIONS_INDEX" >&2
    exit 0
fi

while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        continue
    fi

    # Parsear entrada del índice usando Python
    read session_id transcript_path ended_at <<< $(python3 << EOPYTHON
import json
try:
    entry = json.loads('''$line''')
    session_id = entry.get('session_id', '')
    transcript_path = entry.get('transcript_path', '')
    ended_at = entry.get('ended_at', '')
    print(f"{session_id} {transcript_path} {ended_at}")
except json.JSONDecodeError:
    print(" ")
EOPYTHON
)

    if [[ -z "$session_id" ]] || [[ -z "$transcript_path" ]]; then
        echo "WARN: Entrada inválida en sessions-index.jsonl (faltan session_id o transcript_path): $line" >&2
        ((entries_failed++))
        continue
    fi

    # Chequear si ya fue procesada
    if grep -q "^$session_id$" "$PROCESSED_FILE" 2>/dev/null; then
        ((entries_skipped++))
        continue
    fi

    # Calcular métricas
    metrics=$(calculate_metrics "$transcript_path")
    if [[ $? -ne 0 ]]; then
        echo "ERROR: No se pudieron calcular métricas para session_id=$session_id, transcript=$transcript_path" >&2
        ((entries_failed++))
        continue
    fi

    # Delegation rate (Issue #179)
    delegation=$(calculate_delegation_rate "$transcript_path")

    # Timestamp de procesamiento
    processed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Construir entrada de salida usando Python
    output_entry=$(python3 << EOPYTHON
import json
metrics = json.loads('''$metrics''')
delegation = json.loads('''$delegation''')
entry = {
    'session_id': '$session_id',
    'transcript_path': '$transcript_path',
    'ended_at': '$ended_at',
    'processed_at': '$processed_at',
    'output_tokens': metrics['output_tokens'],
    'tool_uses': metrics['tool_uses'],
    'duration_ms': metrics['duration_ms'],
    'delegation_rate': delegation
}
print(json.dumps(entry, separators=(',', ':')))
EOPYTHON
)

    if [[ -z "$output_entry" ]]; then
        echo "ERROR: No se pudo construir output_entry para session_id=$session_id" >&2
        ((entries_failed++))
        continue
    fi

    # Appendear a sessions.jsonl
    echo "$output_entry" >> "$SESSIONS_OUTPUT"

    ((entries_processed++))
done < "$SESSIONS_INDEX"

# Log de resumen (silencioso si todo OK)
if [[ $entries_processed -gt 0 ]] || [[ $entries_failed -gt 0 ]]; then
    echo "INFO: process-session.sh: processed=$entries_processed, skipped=$entries_skipped, failed=$entries_failed" >&2
fi

# Exit code: 0 si se procesó al menos 1 entrada o no hay nuevas entradas, 1 si hubo fallos
if [[ $entries_failed -gt 0 ]]; then
    exit 1
else
    exit 0
fi
