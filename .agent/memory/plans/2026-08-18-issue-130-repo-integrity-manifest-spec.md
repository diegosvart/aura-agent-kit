---
status: approved
---

# Plan — Issue #130: Diseñar check de integridad de repo (archivos faltantes/fuera de lugar)

## Contexto

El Issue #130 es un issue de **diseño** (no de código): pide definir el alcance de un
chequeo que, al iniciar sesión, detecte archivos esperados del harness que faltan (ej. un
`protocols/*.md` referenciado en el router pero ausente en disco) o archivos fuera de la
estructura esperada (ej. `AGENTS.local.md` mal ubicado, hoy cubierto solo parcialmente
mediante un chequeo inline en `protocols/session_start.md` Paso 1). El entregable es una
spec en `docs/aura/specs/`. El Issue #131 (dependiente, ya `ready`) implementará después el
script real siguiendo esa spec — esta sesión **no toca código**, solo escribe la spec.

Los dos criterios de aceptación del issue son preguntas abiertas de diseño:
1. Qué "manifest" de referencia usar (¿lista estática o derivada de `protocols/router.md`?)
2. Qué umbral de falso positivo es aceptable

Investigación ya hecha (patrón de `skills/repo-integrity/scripts/check-release-drift.sh` y
`classify-branch.sh`, estructura de `protocols/router.md`, formato de specs existentes en
`docs/aura/specs/2026-07-30-harness-self-update.md`) y decisión confirmada con el usuario:
**manifest estático versionado a mano**, no derivado de `router.md` en runtime — el
precedente del proyecto es bash simple sin dependencias, y la tabla de `router.md` tiene
matices reales (celdas con múltiples rutas separadas por `+`, texto no-ruta como "vía
/doc-check", una segunda tabla de flechas sin backticks consistentes) que harían el parseo
dinámico frágil y con riesgo de falsos negativos silenciosos.

## Alcance de esta sesión

Un solo archivo nuevo: la spec de diseño. Nada de código, nada de edición a
`protocols/session_start.md`/`router.md`/`skills/repo-integrity/` — eso es Issue #131.

## Archivo a crear

`docs/aura/specs/2026-08-18-repo-integrity-manifest.md`

Formato: mismo patrón que `docs/aura/specs/2026-07-30-harness-self-update.md` (título
`Spec — ...`, bloque de metadata `> Propósito` / `> Versión del harness` / `> Fecha`,
luego **Problema**, **Objetivo**, **Decisiones de Diseño** D1–D4, **Cómo se mide si
funciona**, **Criterios de Aceptación**).

### Contenido de las Decisiones de Diseño

**D1 — Manifest estático versionado, no derivado de `router.md` en runtime.**
Nuevo archivo `skills/repo-integrity/manifest.txt` (texto plano, una ruta por línea,
comentarios con `#`, mismo estilo bash-sin-dependencias que los scripts existentes).
Contenido inicial: las rutas reales listadas en la columna "Archivos a cargar" de
`protocols/router.md`. `AGENTS.local.md` se marca con sufijo `#optional` (ver D2).
Justificar citando el precedente `check-release-drift.sh`/`classify-branch.sh` (bash simple,
sin parseo de estructuras ajenas) y los matices reales de `router.md` que hacen el parseo
dinámico frágil.

**D2 — Umbral de falso positivo: cero tolerado, acotado por construcción al manifest
explícito.**
El check solo evalúa lo que está en `manifest.txt`, nunca prosa libre ni heurísticas.
No debe disparar alerta: archivos mencionados en prosa fuera de la tabla, `AGENTS.local.md`
(marcado `#optional`, ya cubierto por el chequeo inline existente), `*.example.md`/
`*.template.md`, archivos gitignored. Sí debe disparar: ruta del manifest ausente en disco
(`MISSING:`), o archivo con ubicación fija esperada encontrado en otro lado (`MISPLACED:`).

**D3 — Contrato de salida del script futuro (para que Issue #131 lo implemente sin
ambigüedad).**
- Ubicación futura: `skills/repo-integrity/scripts/check-repo-manifest.sh`
- `set -uo pipefail` (sin `-e`, mismo motivo que `check-release-drift.sh`)
- Input: `skills/repo-integrity/manifest.txt`
- Salida: una línea por hallazgo — `MISSING: <ruta>` / `MISPLACED: <ruta-encontrada> — se
  esperaba en <ruta-manifest>`; nada si todo está en orden
- Exit code: siempre `0` (informativo, nunca bloqueante)
- Tiempo esperado: `<2s` (solo `test -f` sobre ~15-20 rutas, sin `gh`, sin red)
- Integración futura en `protocols/session_start.md` Paso 3: mismo patrón que
  `check-release-drift.sh` — si imprime algo, se copia tal cual a "Advertencias" del Paso 6;
  si no imprime nada, se omite la línea

**D4 — Mantenimiento del manifest ligado a `/doc-check`.**
Cualquier PR que edite `protocols/router.md` agregando/quitando una fila con ruta a archivo
debe también tocar `manifest.txt`. Se documenta como chequeo nuevo en
`agents/doc-guardian.md`, no como lógica dentro del script — consistente con que
doc-guardian ya es el punto central de consistencia doc-código.

### Cómo se mide si funciona (sección de la spec)
- Eliminar un archivo listado en `manifest.txt` dispara `MISSING:` en la próxima sesión.
- Mover `AGENTS.local.md` fuera de la raíz dispara `MISPLACED:`.
- Ningún caso del set "no debe disparar" (D2) genera salida — verificado manualmente antes
  de mergear #131.
- El script corre en `<2s` sobre el manifest inicial.

### Criterios de Aceptación (checklist de la spec)
- [x] Define manifest de referencia: lista estática, no derivada de `router.md` en runtime
- [x] Define umbral de falso positivo: cero tolerado sobre exclusiones documentadas en D2
- [x] Contrato de salida (D3) completo para que #131 lo implemente sin decisiones adicionales
- [x] Regla de mantenimiento (D4) enlazada a doc-guardian

## Qué pasa con los issues

- Issue #130 se cierra al mergear la PR que agrega esta spec (su criterio de aceptación
  queda satisfecho por el contenido de la spec, sin requerir código).
- Issue #131 permanece abierto, sin tocarse en esta sesión — queda referenciando la spec
  mergeada como su dependencia de diseño ya resuelta.

## Verificación

- Revisión de que la spec siga el formato de `docs/aura/specs/2026-07-30-harness-self-update.md`
  (secciones presentes, nivel de detalle, checklist de criterios de aceptación).
- Confirmar que las dos preguntas abiertas del issue (manifest + umbral) quedan respondidas
  de forma concreta y accionable, sin dejar decisiones pendientes para Issue #131.
- No requiere ejecutar código (no hay código en este alcance).
