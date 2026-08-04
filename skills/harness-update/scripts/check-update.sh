#!/usr/bin/env bash
# Compara el tag local de .aura/ contra el remoto.
# Salida: versión nueva si hay disponible, vacío si ya está al día.
# Uso: check-update.sh [aura_path]
# Exit code: 0 siempre (salvo error de setup fatal)
set -uo pipefail

AURA_PATH="${1:-.aura}"

# Validar que .aura existe y es un directorio
if [ ! -d "$AURA_PATH" ]; then
  exit 0  # No es un error — simplemente sin .aura no hay update que detectar
fi

if [ ! -e "$AURA_PATH/.git" ]; then
  exit 0  # No es un checkout git — sin update que detectar
fi
# $AURA_PATH/.git es directorio en un checkout normal, pero un ARCHIVO
# (gitlink "gitdir: ...") cuando .aura/ está montado como git submodule
# (caso real: crawler-mcp-diagram) — -e cubre ambos, -d rompía submodules.

# Obtener el tag local actual (la rama está en un tag después de checkout)
local_tag=$(git -C "$AURA_PATH" describe --tags --exact-match 2>/dev/null || echo "")

# Si no está en un tag exacto, obtener el tag más cercano — pero el resultado puede ser
# enganoso: si .aura esta en una rama (ej. develop actualizada via submodule update en vez
# de apply-update.sh), el tag "mas cercano" puede quedar desactualizado si esa rama no tiene
# el ultimo tag como ancestro (ver agents/github.md -> "Proceso de Release", caso real: PR #119
# de aura-agent-kit, tag v2.2.0 fuera de la ancestria de develop por falta de sync-back).
if [ -z "$local_tag" ]; then
  local_tag=$(git -C "$AURA_PATH" describe --tags --abbrev=0 2>/dev/null || echo "")
  if [ -n "$local_tag" ]; then
    branch_name=$(git -C "$AURA_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "desconocida")
    echo "ADVERTENCIA: .aura esta en la rama '$branch_name', no en un tag exacto. La version detectada ('$local_tag') puede ser incorrecta si esa rama no tiene el ultimo release como ancestro. Usar /harness-update (checkout de tag exacto) en vez de actualizar el submodulo directo a una rama." >&2
  fi
fi

# Fetch tags del remoto (con timeout de 5s para no bloquear si no hay red)
timeout 5s git -C "$AURA_PATH" fetch --tags origin >/dev/null 2>&1 || true

# Obtener el tag más reciente del remoto
# Usa python3 para parseo de semver simple (v1.2.3 > v1.2.2, etc.)
remote_tag=$(git -C "$AURA_PATH" tag -l --sort=-version:refname --merged origin/main 2>/dev/null | head -1 || echo "")

# Si no hay remote_tag, intentar sin --merged (repo podría no tener main)
if [ -z "$remote_tag" ]; then
  remote_tag=$(git -C "$AURA_PATH" tag -l --sort=-version:refname 2>/dev/null | head -1 || echo "")
fi

# Comparar
if [ -z "$remote_tag" ]; then
  # Sin tags remotos, no hay update
  exit 0
fi

if [ -z "$local_tag" ]; then
  # .aura no está en un tag — hay un mismatch, reportar remote
  echo "$remote_tag"
  exit 0
fi

if [ "$local_tag" != "$remote_tag" ]; then
  # Tags distintos
  echo "$remote_tag"
  exit 0
fi

# Tags iguales — no hay update
exit 0
