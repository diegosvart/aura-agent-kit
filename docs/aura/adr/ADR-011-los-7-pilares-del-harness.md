---
adr: 011
title: Los 7 Pilares del harness como registro permanente
date: 2026-09-14
status: accepted
area: harness
---

# ADR-011: Los 7 Pilares del harness como registro permanente

## Problema

El harness necesita una vara de medición estable contra la cual evaluar specs y cambios
(P4/challenger, `agents/challenger.md`), sin que quede sujeta a edición informal. Esa vara —
"Los 7 Pilares" (P1-P7) — se referenciaba desde varios archivos operativos
(`AGENTS.md`, `protocols/router.md`, `agents/challenger.md`, `commands/auto-research.md`,
`skills/auto-research/SKILL.md`) como un documento **permanente**, "la vara de medición", que
"no se modifica sin spec aprobada", apuntando a
`docs/aura/specs/2026-05-09-harness-pillars.md`. Ese archivo **no existe en disco** y nunca
existió — la ruta es fantasma. Un archivo que declara semántica de "no modificable" no debería
vivir, ni siquiera nominalmente, en un directorio (`docs/aura/specs/`) cuya política de
versionado default es "efímero, gitignoreado" (ver `.gitignore` líneas 53-61 y
`docs/aura/adr/ADR-003-politica-versionado-artefactos.md`).

## Contexto

- Origen: Issue #147, que documenta la contradicción entre cómo se referencia el archivo
  (permanente, inmutable sin proceso) y dónde vivía la ruta (directorio efímero gitignoreado).
- Spec de diseño: `docs/aura/specs/2026-09-14-issue-147-harness-pillars-fantasma-design.md`
  (Opción 2 elegida tras comparar tres alternativas).
- El contenido "completo" de los 7 pilares nunca vivió en un archivo autónomo — ya existía,
  parcialmente (la tabla resumen "regla en una línea"), inline en `AGENTS.md` (sección
  "Los 7 Pilares"). No hay nada que rescatar de un archivo que nunca se escribió; este ADR
  formaliza esa misma tabla como registro permanente.
- `docs/aura/adr/ADR-000-registro.md` confirma que el propósito declarado de `adr/` es
  exactamente "el residuo permanente de un spec efímero" — coincide en propósito y en
  convención de nombre (`ADR-NNN-titulo.md`) con lo que este contenido necesita.
- El propio `AGENTS.md` (tabla "Harness Engineering") ya declaraba que la fila
  "**Evaluación**" (`agents/challenger.md`, pilares) **no puede modificarse en experimentos**
  — esa regla no cambia con este ADR, solo se corrige dónde vive el archivo que la sustenta.
- Se descartó la referencia a `.aura/rules/subagent-dispatch.md` como parte del alcance: no
  contiene ninguna mención a la ruta fantasma (confirmado por grep).

## Decisión

Se crea este ADR (ADR-011) como el registro permanente de "Los 7 Pilares" del harness, y las
7 referencias operativas que apuntaban a la ruta fantasma
(`docs/aura/specs/2026-05-09-harness-pillars.md`) pasan a apuntar a
`docs/aura/adr/ADR-011-los-7-pilares-del-harness.md`.

### Los 7 Pilares

| # | Pilar | Regla en una línea |
|---|-------|--------------------|
| P1 | CLI > MCP | Si existe CLI que alcanza, no usar MCP |
| P2 | Diseño antes de código | Sin spec aprobada → sin código |
| P3 | TDD siempre | Test primero, ver fallar, luego implementar |
| P4 | Hipótesis antes de cambiar el harness | Sin hipótesis escrita → no modificar protocolos/skills |
| P5 | Memoria distribuida | Engram + current-session.json al cerrar siempre |
| P6 | Stack-agnóstico | Detectar stack antes de asumir herramientas |
| P7 | Evolución con validación | Proponer mejoras como opción, nunca imponer |

Esta tabla es la misma que vive en `AGENTS.md` (sección "Los 7 Pilares") — este ADR no la
reescribe ni la expande, la formaliza como registro permanente y verificable en disco.

Regla de inmutabilidad (ya declarada en `AGENTS.md` → tabla "Harness Engineering", fila
"Evaluación", y que este ADR no debilita sino que ratifica formalmente): el contenido de los
7 pilares **no se modifica sin una nueva spec aprobada** que pase por el flujo de diseño
completo (`brainstorm` → `spec-validation` → `challenger`). Los pilares son la vara de
medición contra la que `challenger` evalúa cambios propuestos al harness — no pueden
evolucionar por el mismo camino que evalúan.

## Alternativas descartadas

- **Opción 1 — crear el archivo fantasma + agregar una 5ta excepción en `.gitignore`** —
  descartada: perpetuaría un directorio (`docs/aura/specs/`) cuya semántica de política del
  repo es "efímero" para contenido que el propio harness ya trata como inmutable; contradice
  la intención original de la carpeta en vez de resolver la contradicción.
- **Opción 3 — solo actualizar las referencias, sin crear un registro permanente nuevo** —
  descartada: no hay ningún otro lugar en disco donde el contenido "completo" de los pilares
  ya viva de forma autónoma y permanente; solo vive, parcialmente (la tabla resumen), dentro
  de `AGENTS.md`, que es el spine del harness y no el lugar declarado para decisiones/ADRs.

## Consecuencias

- Las 7 referencias operativas que apuntaban a la ruta fantasma se actualizan para apuntar a
  este ADR (ver "Archivos afectados").
- `AGENTS.md` mantiene la tabla resumen de los 7 pilares tal cual estaba, pero el pointer
  "Fuente de verdad completa" apunta a este ADR en lugar de a
  `docs/aura/specs/2026-05-09-harness-pillars.md`.
- Los archivos de memoria histórica (`.agent/memory/project-log.md`, `.agent/memory/ideas.md`,
  `.agent/memory/plans/2026-09-05-issues-021-022-delegation-gap-plan.md`) **no se actualizan**
  — son bitácora de lo que ocurrió en su momento (incluyendo la mención a la ruta fantasma
  como antecedente del problema que este ADR resuelve), no punteros operativos vigentes.
- `agents/challenger.md` y `AGENTS.md` (tabla "Harness Engineering") siguen declarando
  explícitamente que los 7 pilares no se modifican sin nueva spec aprobada — este ADR corrige
  dónde vive el registro, no la regla de inmutabilidad en sí.

## Archivos afectados

- `docs/aura/adr/ADR-011-los-7-pilares-del-harness.md` — este archivo (nuevo)
- `docs/aura/adr/ADR-000-registro.md` — fila nueva para ADR-011
- `AGENTS.md` — línea 25, pointer "Fuente de verdad completa"
- `protocols/router.md` — fila "Mejorar el harness" y nota "Los archivos de pilares"
- `agents/challenger.md` — encabezado "Contra los Pilares" y Paso 2 del proceso
- `commands/auto-research.md` — dos menciones ("No modifica...")
- `skills/auto-research/SKILL.md` — "No modificar pilares"
