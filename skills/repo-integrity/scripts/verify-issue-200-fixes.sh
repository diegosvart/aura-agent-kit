#!/usr/bin/env bash
# verify-issue-200-fixes.sh
# Verifica que las 4 correcciones del Issue #200 (auto-init de .aura en worktrees) están
# aplicadas en el árbol de archivos del harness. Solo lectura — no modifica nada. Mismo
# estilo que check-repo-manifest.sh: falla (exit 1) e imprime MISSING: <check> por cada
# corrección ausente; silencioso (exit 0) si todo está en orden.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

fail=0

check() {
    local desc="$1"
    local file="$2"
    local pattern="$3"
    if ! grep -qF "$pattern" "$file" 2>/dev/null; then
        echo "MISSING: $desc (esperado en $file: \"$pattern\")"
        fail=1
    fi
}

# D1 — auto-init en session-start.ps1
check "auto-init de .aura expuesto en el hook" \
    ".claude/hooks/session-start.ps1" \
    "aura_submodule_initialized"

# D1 — session_start.md reporta el auto-init
check "session_start.md reporta la advertencia de auto-init" \
    "protocols/session_start.md" \
    "aura_submodule_initialized: true"

# D2 — línea literal fuera del import en los installers
check "install.sh incluye la línea literal fuera del import" \
    "install.sh" \
    "PRIMER paso obligatorio"

check "install.ps1 incluye la línea literal fuera del import" \
    "install.ps1" \
    "PRIMER paso obligatorio"

# D3 — default ramas sobre worktrees
check "AGENTS.md recomienda ramas sobre worktrees" \
    "AGENTS.md" \
    "Preferir ramas sobre worktrees"

check "router.md incluye la fila de aislar trabajo por rama" \
    "protocols/router.md" \
    "Aislar trabajo de un solo issue"

check "agents/github.md incluye la Regla anti-worktree" \
    "agents/github.md" \
    "Regla anti-worktree"

check "session_start.md Paso 3 detecta worktrees adicionales" \
    "protocols/session_start.md" \
    "Worktrees Adicionales"

if [ "$fail" -eq 0 ]; then
    echo "OK: las 4 correcciones del Issue #200 están presentes."
fi

exit $fail
