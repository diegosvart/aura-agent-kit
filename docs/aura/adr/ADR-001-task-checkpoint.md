---
adr: 001
title: Protocolo de checkpoint mid-session tras cerrar una unidad de trabajo
date: 2026-05-14
status: accepted
area: harness
---

# ADR-001: Protocolo de checkpoint mid-session tras cerrar una unidad de trabajo

> Escrito retroactivamente (2026-08-01) como ejemplo de uso de la infraestructura ADR
> (Issue #33), documentando una decisión ya implementada en Issues #26/#27.

## Problema

A partir de ~100k tokens de contexto acumulado en una sesión, el modelo puede perder
visibilidad de las reglas del workflow (por ejemplo, hacer push directo a una rama
protegida) porque la degradación de contexto diluye instrucciones tempranas de la
conversación. No existía un punto de guardado que capturara el estado justo al cerrar
una unidad de trabajo, antes de que esa degradación afectara el resto de la sesión.

## Contexto

- Motivado por un incidente real: el agente ignoró reglas del harness (push directo a
  `main`) en una sesión larga de este mismo repo.
- Precedente: `protocols/session_end.md` ya guardaba estado en Engram y
  `current-session.json`, pero solo al cierre completo de sesión — no había un punto
  intermedio tras cada PR.
- Idea #007 del backlog (`.agent/memory/ideas.md`), promovida a planificación el
  2026-05-14.
- Issues #26 (crear el protocolo) y #27 (integrarlo en `finishing-a-development-branch`).

## Decisión

Crear `protocols/task-checkpoint.md`, invocado siempre desde
`skills/finishing-a-development-branch/SKILL.md` inmediatamente después de confirmar que
una PR fue abierta o mergeada, con tres pasos en orden estricto:

1. `mem_session_summary` — enfocado en la tarea recién completada, no en toda la sesión.
2. Actualizar `.agent/memory/current-session.json` con `next_step` limpio post-PR.
3. Evaluar señales heurísticas de contexto extenso (turnos, tool calls, issues
   completados en la sesión) y, si corresponde, sugerir `/compact` al usuario.

El orden es obligatorio: Engram primero, luego `current-session.json`, y solo después
evaluar compactación — nunca sugerir `/compact` antes de guardar el estado.

## Alternativas descartadas

- **Guardar solo al cierre de sesión (`session_end`)** — descartada porque el problema
  ocurre *dentro* de una sesión larga con múltiples issues, no solo al final.
- **Compactar automáticamente sin guardar estado primero** — descartada porque arriesga
  perder contexto de la tarea recién completada si el guardado en Engram falla o queda
  incompleto.
- **Checkpoint condicional (solo si se detecta degradación)** — descartada a favor de
  ejecución incondicional tras cada PR; más simple y predecible que heurísticas de
  detección de degradación en tiempo real.

## Consecuencias

- Cada PR abierta o mergeada deja un registro limpio en Engram y en
  `current-session.json`, independiente de si la sesión continúa o se cierra.
- `finish-branch` gana un paso obligatorio adicional (no bloqueante: si
  `mem_session_summary` falla, el flujo continúa con advertencia).
- Sienta el precedente para checkpoints similares en otros puntos del flujo (por
  ejemplo, el paso de ADR de Issue #34 se integra en el mismo punto del skill).

## Archivos afectados

- `protocols/task-checkpoint.md` — protocolo nuevo (Issue #26)
- `skills/finishing-a-development-branch/SKILL.md` — invocación del checkpoint tras PR (Issue #27)
