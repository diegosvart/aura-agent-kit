#!/usr/bin/env bash
# with-checkout-lock.sh — Serializa el checkout compartido para agentic-dev-loop (Issue #217).
#
# Reemplaza `isolation:"worktree"` (roto en este harness -- Issues #213/#214/#205: worktrees
# nuevos no inicializan .aura, current-session.json queda stale en sesiones background, y un
# fix real quedo atrapado sin commitear en un worktree) por un lock de checkout explicito:
# nadie mas cambia el branch/working-tree mientras un dev-runner trabaja. El verdadero
# requisito nunca fue "un directorio fisicamente distinto", sino "nadie mas toca el checkout
# mientras yo trabajo" -- eso se logra con un mutex, no con aislamiento de filesystem.
#
# El lock se libera SIEMPRE al salir (exito o fallo), nunca a medias -- via trap EXIT.
#
# Uso:
#   with-checkout-lock.sh <issue_n> <agent_id> -- <comando...>
#
# El lock vive en .git/aura-checkout.lock/ (directorio -- mkdir es atomico, no hay carrera
# entre el check y la creacion). El archivo owner adentro registra quien lo tiene:
#   "<timestamp ISO8601> issue-<N> agent-<agent_id> session-<session_id>"
# session-<session_id> se toma de $CLAUDE_CODE_SESSION_ID si esta disponible (siempre lo
# esta dentro de una sesion de Claude Code) -- es lo que .claude/hooks/checkout-lock-guard.ps1
# usa para distinguir "el mismo proceso que sostiene el lock" de "otro agente/sesion
# concurrente", comparando contra el session_id que Claude Code inyecta en el JSON de cada
# hook PreToolUse.
#
# Lock stale (Issue #217, correccion 2): si el lock existe pero su timestamp supera
# AURA_LOCK_STALE_MINUTES (default 30), NO se libera automaticamente -- se informa al usuario
# y se exige confirmacion humana explicita (correr manualmente `rm -rf .git/aura-checkout.lock`
# tras verificar que el proceso dueno ya no corre). Mismo principio que
# check-orphaned-worktrees.sh: informar, nunca borrar sin confirmacion.
#
# Precondicion dura (Issue #217, alcance original): antes de ejecutar el comando envuelto,
# `git status --short` debe estar vacio. Si no lo esta, NO se auto-limpia ni auto-stashea --
# aborta con el detalle de que quedo sucio y en que rama, para que el usuario decida.
set -euo pipefail

if [ "$#" -lt 4 ] || [ "$3" != "--" ]; then
  echo "Uso: with-checkout-lock.sh <issue_n> <agent_id> -- <comando...>" >&2
  exit 1
fi

ISSUE="$1"
AGENT_ID="$2"
shift 3

STALE_THRESHOLD_MIN="${AURA_LOCK_STALE_MINUTES:-30}"
LOCK_DIR=".git/aura-checkout.lock"
OWNER_FILE="$LOCK_DIR/owner"
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  owner_line="$(cat "$OWNER_FILE" 2>/dev/null || echo "desconocido")"
  owner_ts="$(echo "$owner_line" | awk '{print $1}')"
  owner_epoch="$(date -d "$owner_ts" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"

  if [ "$owner_epoch" -ne 0 ]; then
    age_min=$(( (now_epoch - owner_epoch) / 60 ))
    if [ "$age_min" -ge "$STALE_THRESHOLD_MIN" ]; then
      echo "BLOCKED: lock de checkout STALE (${age_min} min, dueno: $owner_line)." >&2
      echo "No se libera automaticamente. Verificar que ese proceso ya no corre y, si es asi:" >&2
      echo "  rm -rf $LOCK_DIR" >&2
      exit 1
    fi
  fi

  echo "BLOCKED: checkout en uso (dueno: $owner_line), reintentar." >&2
  exit 1
fi

echo "$(date -Iseconds) issue-$ISSUE agent-$AGENT_ID session-$SESSION_ID" > "$OWNER_FILE"
trap 'rm -rf "$LOCK_DIR"' EXIT

if [ -n "$(git status --short)" ]; then
  echo "ABORT: working tree sucio antes de empezar (rama actual: $(git branch --show-current))." >&2
  git status --short >&2
  echo "No se auto-limpia ni auto-stashea -- decidir manualmente que hacer con estos cambios antes de reintentar." >&2
  exit 1
fi

"$@"
