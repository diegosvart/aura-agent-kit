#!/usr/bin/env bash
# verify-issue-201-fixes.sh
# Verifica que las correcciones del Issue #201 (convencion de topics de GitHub +
# reporte en session_start + auditoria) estan aplicadas en el arbol de archivos del
# harness. Solo lectura — no modifica nada. Mismo estilo que
# verify-issue-200-fixes.sh / check-repo-manifest.sh: falla (exit 1) e imprime
# MISSING: <check> por cada correccion ausente; silencioso (exit 0) si todo esta en orden.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

fail=0

check_file() {
    local desc="$1"
    local file="$2"
    local pattern="$3"
    if ! grep -qF "$pattern" "$file" 2>/dev/null; then
        echo "MISSING: $desc (esperado en $file: \"$pattern\")"
        fail=1
    fi
}

check_exists() {
    local desc="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        echo "MISSING: $desc (esperado: $file)"
        fail=1
    fi
}

# D1 — documentacion de la convencion en agents/github.md
check_file "sección Convención de Topics de GitHub" \
    "agents/github.md" \
    "Convención de Topics de GitHub"

check_file "aclaración de diferencia con topic_key de Engram" \
    "agents/github.md" \
    "No confundir con \`topic_key\` de Engram"

# D2 — reporte en session-start.ps1 + session_start.md
check_file "hook expone repo_name/repo_topics" \
    ".claude/hooks/session-start.ps1" \
    "output.repo_topics"

check_file "session_start.md Paso 6 reporta nombre + topics" \
    "protocols/session_start.md" \
    "**Topics:**"

# D3 — script de auditoría
check_exists "script de auditoría de topics" \
    "skills/repo-integrity/scripts/audit-repo-topics.sh"

if [ "$fail" -eq 0 ]; then
    echo "OK: las correcciones del Issue #201 están presentes."
fi

exit $fail
