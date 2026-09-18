#!/usr/bin/env bash
# Detecta worktrees de Claude Code que quedaron huerfanos tras el cierre de una sesion:
# el lock queda con un PID que ya no existe (la sesion murio sin pasar por el flujo normal
# de ExitWorktree), o el worktree esta sin lock pero su rama ya esta mergeada/gone -- senal
# de que nadie lo va a seguir usando. Caso real que motivo este script: sesion 2026-09-02,
# 3 worktrees acumulados (agent-a98e7c9d88adbac4f, fix+issue-plugin-registration,
# docs+plan-skill-aura-marketplace) de sesiones ya cerradas, ninguno limpiado
# automaticamente por Claude Code pese a que la herramienta documenta que "el worktree
# puede eliminarse junto con la sesion".
#
# NO borra nada -- solo informa. La limpieza real (git worktree remove / git branch -d)
# la decide el usuario, con la salvedad de nunca tocar un worktree cuyo PID de lock sigue
# vivo (sesion activa real, no huerfana).
#
# Salida: una linea "ORPHANED-WORKTREE: ..." por cada candidato, vacio si no hay nada que
# reportar. Exit code: 0 siempre (informativo, nunca bloqueante).
#
# Diagnostico (Issue #318): cada vez que se clasifica un worktree como huerfano por lock
# muerto, ademas de la linea "ORPHANED-WORKTREE: ..." de siempre, se anexa una linea a
# .agent/memory/observability/worktree-orphan-diagnostics.jsonl (gitignored) con el `reason`
# crudo del lock, el PID extraido y la salida cruda de `tasklist` para ese PID -- evidencia
# para diagnosticar falsos positivos (caso real: PID 40036, sesion todavia activa,
# 2026-09-17) sin cambiar la logica de deteccion existente. Solo lectura + append, nunca
# destructivo.
set -uo pipefail

TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$TOPLEVEL" ] && exit 0

MAIN_WORKTREE=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')

DIAG_FILE="$TOPLEVEL/.agent/memory/observability/worktree-orphan-diagnostics.jsonl"

pid_alive() {
  local pid="$1"
  command -v tasklist >/dev/null 2>&1 || return 1
  tasklist //FI "PID eq $pid" 2>/dev/null | grep -q "$pid"
}

log_orphan_diagnostic() {
  local reason="$1" pid="$2"
  local tasklist_output=""
  if [ -n "$pid" ] && command -v tasklist >/dev/null 2>&1; then
    tasklist_output=$(tasklist //FI "PID eq $pid" 2>&1)
  fi
  mkdir -p "$(dirname "$DIAG_FILE")" 2>/dev/null || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  python3 -c '
import json, sys, datetime
reason, pid, tasklist_output = sys.argv[1:4]
line = json.dumps({
    "timestamp": datetime.datetime.now().astimezone().isoformat(),
    "reason": reason,
    "pid": pid,
    "tasklist_output": tasklist_output,
})
print(line)
' "$reason" "$pid" "$tasklist_output" >> "$DIAG_FILE" 2>/dev/null || true
}

branch_is_stale() {
  local branch="$1"
  [ -z "$branch" ] && return 1
  git merge-base --is-ancestor "$branch" develop 2>/dev/null && return 0
  git branch -vv 2>/dev/null | grep -F "$branch" | grep -q ": gone]" && return 0
  return 1
}

git worktree list --porcelain 2>/dev/null | awk '
  /^worktree / { if (path != "") print path "\t" branch "\t" locked "\t" reason; path=$2; branch=""; locked=""; reason="" }
  /^branch /   { b=$2; sub("refs/heads/", "", b); branch=b }
  /^locked/    { locked="1"; reason=substr($0, index($0, $2)) }
  END          { if (path != "") print path "\t" branch "\t" locked "\t" reason }
' | while IFS=$'\t' read -r path branch locked reason; do
  [ -z "$path" ] && continue
  [ "$path" = "$MAIN_WORKTREE" ] && continue
  [ -d "$path" ] || continue

  if [ "$locked" = "1" ]; then
    pid=$(echo "$reason" | grep -oE 'pid [0-9]+' | grep -oE '[0-9]+' | head -1)
    if [ -n "$pid" ] && pid_alive "$pid"; then
      continue
    fi
    log_orphan_diagnostic "$reason" "$pid"
    echo "ORPHANED-WORKTREE: $path (rama '$branch') -- lock huerfano ($reason), el proceso dueno ya no existe. Revisar y limpiar con: git worktree remove \"$path\""
    continue
  fi

  if branch_is_stale "$branch"; then
    echo "ORPHANED-WORKTREE: $path (rama '$branch') -- sin lock, rama ya mergeada/gone. Limpiar con: git worktree remove \"$path\" && git branch -d $branch"
  fi
done

exit 0
