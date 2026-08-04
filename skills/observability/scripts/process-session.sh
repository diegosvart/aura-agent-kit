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

    # Timestamp de procesamiento
    processed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Construir entrada de salida usando Python
    output_entry=$(python3 << EOPYTHON
import json
metrics = json.loads('''$metrics''')
entry = {
    'session_id': '$session_id',
    'transcript_path': '$transcript_path',
    'ended_at': '$ended_at',
    'processed_at': '$processed_at',
    'output_tokens': metrics['output_tokens'],
    'tool_uses': metrics['tool_uses'],
    'duration_ms': metrics['duration_ms']
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
