---
adr: 007
title: Manifest estático para el check de integridad de archivos del repo
date: 2026-08-18
status: accepted
area: harness
---

# ADR-007: Manifest estático para el check de integridad de archivos del repo

## Problema

`protocols/session_start.md` Paso 3 detecta ramas stranded y drift de release, pero no
detecta un tercer tipo de falla real: que un archivo esperado del harness haya desaparecido
del disco (borrado por error, o dejado fuera de un merge) o esté en una ubicación
equivocada. Hoy solo existe un chequeo puntual e inline para un caso específico —
`AGENTS.local.md` mal ubicado (`protocols/session_start.md` Paso 1) — sin generalizar a
ningún otro archivo del harness (`protocols/*.md`, `agents/*.md`, `skills/*/SKILL.md`,
`.claude/rules/*.md`, `.aura/rules/*.md`). Si cualquiera de esos archivos desaparece o se
mueve, nada lo detecta hasta que alguien lo nota manualmente, a mitad de una sesión distinta.

## Contexto

Issue #130 (diseño) pide definir el alcance de este chequeo, con dos preguntas explícitas
como criterios de aceptación: qué "manifest" de referencia usar, y qué umbral de falso
positivo es aceptable. Issue #131 (`ready`, dependiente) implementará el script real
siguiendo esta decisión, integrado en `protocols/session_start.md` Paso 3 con el mismo
patrón que `skills/repo-integrity/scripts/check-release-drift.sh` (bash simple, sin
dependencias externas, `<2s`, sin `gh`).

Precedente relevante: los scripts existentes de `skills/repo-integrity/scripts/`
(`check-release-drift.sh`, `classify-branch.sh`) son bash de una sola responsabilidad, sin
`jq` ni parseo de estructuras Markdown ajenas a su propósito.

## Decisión

El manifest de referencia es un archivo nuevo y estático, **`skills/repo-integrity/manifest.txt`**:
texto plano, una ruta por línea relativa a la raíz del repo, comentarios con `#`. Contenido
inicial: las rutas reales listadas en la columna "Archivos a cargar" de
`protocols/router.md`. `AGENTS.local.md` se incluye marcado `#optional` (es gitignored y
válido que no exista).

El check solo evalúa las rutas del manifest — nunca prosa libre ni heurísticas sobre el
árbol de directorios — con **cero falsos positivos tolerados** sobre este set de
exclusiones explícitas: archivos mencionados solo en prosa fuera de la tabla de routing,
entradas `#optional` ausentes, `*.example.md`/`*.template.md`, archivos gitignored. Sí
dispara hallazgo: una ruta del manifest (no `#optional`) ausente en disco (`MISSING: <ruta>`),
o un archivo con ubicación fija esperada encontrado en otro lugar (`MISPLACED: <ruta
encontrada> — se esperaba en <ruta del manifest>`).

**Contrato de salida para Issue #131** (implementación futura, sin decisiones adicionales
pendientes):
- Script: `skills/repo-integrity/scripts/check-repo-manifest.sh`, `set -uo pipefail` (sin
  `-e`, mismo motivo que `check-release-drift.sh`).
- Input: `skills/repo-integrity/manifest.txt`.
- Salida: una línea `MISSING:`/`MISPLACED:` por hallazgo; nada si todo está en orden.
- Exit code: siempre `0` (informativo, nunca bloqueante; no depende de `gh`).
- Integración: mismo patrón que `check-release-drift.sh` en `protocols/session_start.md`
  Paso 3 — se copia la salida tal cual a "Advertencias" si hay hallazgo; se omite si no.

**Mantenimiento:** cualquier PR que edite `protocols/router.md` agregando/quitando una fila
con ruta a archivo debe también actualizar `manifest.txt` en la misma PR. Se documenta como
chequeo nuevo en `agents/doc-guardian.md` (`/doc-check`), no como lógica dentro del script.

## Alternativas descartadas

- **Derivar el manifest dinámicamente parseando `protocols/router.md` en cada corrida** —
  descartada porque la tabla tiene matices reales que harían el parser frágil: celdas con
  múltiples rutas separadas por `+` (ej. fila "Mejorar el harness"), celdas que mezclan una
  ruta real con texto no-ruta (`vía /doc-check`), y una segunda tabla de flechas ("Casos
  Compuestos Frecuentes") sin backticks consistentes. Un parser que falle en silencio ante
  estos casos produce falsos negativos — el check "pasa" sin haber revisado nada — que es
  peor que el costo de mantener una lista aparte. Rompe además el precedente del proyecto
  de scripts bash simples sin dependencias de parseo de Markdown ajeno.
- **Heurísticas sobre el árbol de directorios en vez de manifest explícito** — descartada
  porque no permite acotar el umbral de falso positivo por construcción; cualquier regla
  heurística (ej. "todo `.md` bajo `protocols/`") generaría falsos positivos con archivos
  de ejemplo o documentación auxiliar no listada en el router.

## Consecuencias

- Issue #130 queda resuelto con esta decisión documentada de forma permanente (a diferencia
  de una spec en `docs/aura/specs/`, que es gitignored y efímera por convención de este
  repo — ver tabla "Qué se Versiona" en `AGENTS.md`).
- Issue #131 puede implementarse directamente desde este ADR sin decisiones de diseño
  pendientes.
- Se acepta el costo de mantenimiento manual de `manifest.txt` en paralelo a
  `protocols/router.md`, mitigado por la regla de doc-guardian (D4) en vez de resolverlo
  con parseo dinámico.

## Archivos afectados

- `docs/aura/adr/ADR-007-repo-integrity-manifest.md` — este ADR (nuevo).
- `docs/aura/adr/ADR-000-registro.md` — entrada agregada al índice.
- `skills/repo-integrity/manifest.txt` — a crear en Issue #131 (no en esta PR).
- `skills/repo-integrity/scripts/check-repo-manifest.sh` — a crear en Issue #131 (no en
  esta PR).
- `protocols/session_start.md` — a editar en Issue #131 (no en esta PR).
- `agents/doc-guardian.md` — a editar en Issue #131 o fast-follow (regla de mantenimiento
  D4, no en esta PR).
