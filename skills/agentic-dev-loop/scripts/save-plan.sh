#!/usr/bin/env bash
# save-plan.sh — Guarda un plan aprobado al ledger de planes (.agent/memory/plans/)
# Uso: save-plan.sh <fecha YYYY-MM-DD> <slug> <issue_n> <archivo-contenido>

set -euo pipefail

FECHA="${1:?Uso: save-plan.sh <fecha YYYY-MM-DD> <slug> <issue_n> <archivo-contenido>}"
SLUG="${2:?Uso: save-plan.sh <fecha YYYY-MM-DD> <slug> <issue_n> <archivo-contenido>}"
ISSUE="${3:?Uso: save-plan.sh <fecha YYYY-MM-DD> <slug> <issue_n> <archivo-contenido>}"
ARCHIVO="${4:?Uso: save-plan.sh <fecha YYYY-MM-DD> <slug> <issue_n> <archivo-contenido>}"

# Validar fecha: YYYY-MM-DD
if ! [[ "$FECHA" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: fecha inválida '$FECHA'. Debe ser YYYY-MM-DD" >&2
    exit 1
fi

# Validar slug: empieza con [a-z0-9], contiene solo [a-z0-9-]
if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Error: slug inválido '$SLUG'. Debe empezar con [a-z0-9] y contener solo [a-z0-9-]" >&2
    exit 1
fi

# Validar issue: debe ser numérico
if ! [[ "$ISSUE" =~ ^[0-9]+$ ]]; then
    echo "Error: issue no numérico '$ISSUE'" >&2
    exit 1
fi

# Validar que el archivo existe
if [ ! -f "$ARCHIVO" ]; then
    echo "Error: archivo no existe '$ARCHIVO'" >&2
    exit 1
fi

# Resolver raíz del repo
REPO_ROOT=$(git rev-parse --show-toplevel)
PLANS_DIR="$REPO_ROOT/.agent/memory/plans"

# Crear directorio si falta
mkdir -p "$PLANS_DIR"

# Construir ruta de destino
DESTINO="$PLANS_DIR/$FECHA-$SLUG.md"

# Fallar si el archivo ya existe (nunca sobreescribir)
if [ -f "$DESTINO" ]; then
    echo "Error: plan ya existe en $DESTINO" >&2
    exit 1
fi

# Leer contenido del archivo
CONTENIDO=$(cat "$ARCHIVO")

# Escribir plan con frontmatter
cat > "$DESTINO" << EOF
---
status: approved
issue: $ISSUE
date: $FECHA
---

$CONTENIDO
EOF

# Imprimir ruta creada en stdout
echo "$DESTINO"
