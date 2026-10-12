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

ANIO=$((10#${FECHA:0:4})); MES=$((10#${FECHA:5:2})); DIA=$((10#${FECHA:8:2}))
case $MES in
    1|3|5|7|8|10|12) MAX_DIA=31 ;;
    4|6|9|11) MAX_DIA=30 ;;
    2)
        if (( ANIO % 400 == 0 || (ANIO % 4 == 0 && ANIO % 100 != 0) )); then MAX_DIA=29; else MAX_DIA=28; fi ;;
    *) MAX_DIA=0 ;;
esac
if (( DIA < 1 || DIA > MAX_DIA )); then
    echo "Error: fecha inválida '$FECHA'. Mes/día inexistente" >&2
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
if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "Error: no estás dentro de un repositorio git (cwd: $(pwd))" >&2
    exit 1
fi
PLANS_DIR="$REPO_ROOT/.agent/memory/plans"

# Crear directorio si falta
mkdir -p "$PLANS_DIR"

# Construir ruta de destino
DESTINO="$PLANS_DIR/$FECHA-$SLUG.md"

# Fallar si ya existe algo en esa ruta (nunca sobreescribir)
if [ -e "$DESTINO" ]; then
    echo "Error: plan ya existe en $DESTINO" >&2
    exit 1
fi

# Escritura exclusiva: noclobber hace fallar '>' si el destino ya existe
set -o noclobber
{
    printf -- '---\nstatus: approved\nissue: %s\ndate: %s\n---\n\n' "$ISSUE" "$FECHA"
    cat "$ARCHIVO"
} > "$DESTINO" || { echo "Error: no se pudo crear $DESTINO" >&2; exit 1; }

echo "Recordatorio: barrer datos sensibles antes de commitear el plan (.claude/rules/sensitive-data-safety.md)" >&2

# Imprimir ruta creada en stdout
echo "$DESTINO"
