---
adr: 002
title: Integrar escritura de ADR en el flujo de finish-branch
date: 2026-08-01
status: accepted
area: harness
---

# ADR-002: Integrar escritura de ADR en el flujo de finish-branch

## Problema

Con la infraestructura ADR creada (ADR-001, Issue #33), sin un punto de integración
obligatorio en el flujo de trabajo, los ADRs quedan como documentación que "se escribe
cuando hay tiempo" — es decir, nunca. El residuo permanente de una decisión solo tiene
valor si se captura en el momento en que la decisión se toma, no retroactivamente.

## Contexto

- Precedente directo: ADR-001 documenta el protocolo de checkpoint (Issues #26/#27), que
  sí se integró como paso obligatorio en `finishing-a-development-branch/SKILL.md` justo
  después de confirmar la PR.
- Issue #34, dependiente de #33.

## Decisión

Agregar una nueva sección "Pre-PR: Escribir ADR" en
`skills/finishing-a-development-branch/SKILL.md`, ubicada entre el Health Check y la
presentación de opciones (antes de `gh pr create`). El paso es:

- **Obligatorio** para ramas `feat/*` y `docs/*`.
- **Opcional** para ramas `chore/*` y `fix/*` menores, a criterio del agente.
- Usa `docs/aura/adr/ADR-TEMPLATE.md`, se commitea en la misma rama antes de abrir la PR,
  y actualiza `docs/aura/adr/ADR-000-registro.md`.

## Alternativas descartadas

- **ADR obligatorio para todo tipo de rama** — descartada: un `fix/` de una línea o un
  `chore/` de versionado no tiene una decisión de arquitectura real que documentar; forzar
  el ADR ahí genera ruido y entrena al agente a escribir ADRs vacíos.
- **ADR como paso posterior al PR (post-merge)** — descartada: el mismo razonamiento que
  descartó "checkpoint solo al cierre de sesión" en ADR-001 — separar la decisión de su
  documentación aumenta el riesgo de que nunca se escriba.
- **Detectar automáticamente si el cambio "amerita" ADR en vez de usar el prefijo de
  rama** — descartada por complejidad; el prefijo de rama (`feat/docs/chore/fix`) ya es
  una señal explícita y existente en la convención de naming del harness
  (`agents/github.md`), no requiere heurística nueva.

## Consecuencias

- Cada feature o cambio de documentación deja un ADR versionado antes de mergear, sin
  paso manual adicional fuera del flujo ya existente de `finish-branch`.
- El registro (`ADR-000-registro.md`) se mantiene actualizado por construcción, no por
  disciplina externa.
- Riesgo aceptado: para `chore`/`fix`, la decisión de escribir ADR queda a criterio del
  agente — puede haber inconsistencia entre sesiones. Se acepta porque forzarlo generaría
  más ruido que valor.

## Archivos afectados

- `skills/finishing-a-development-branch/SKILL.md` — nueva sección "Pre-PR: Escribir ADR"
- `docs/aura/adr/ADR-000-registro.md` — nueva entrada
