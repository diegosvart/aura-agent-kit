---
status: approved
---

# Issue #127 — topic_key en Engram + registrar idea [019] desacople de contexto

> **Nota de estado:** plan escrito en modo Plan (sesión 2026-08-04), guardado en `draft`
> sin aprobación formal. Aprobado el 2026-08-06 tras agregar la justificación de tokens
> abajo — ejecución arranca en esta misma sesión.

## Context

Dos hilos en esta conversación:

1. **Issue #127** (ready, sin diseño previo — confirmado por exploración: solo 4 menciones
   de `topic_key` en el repo, todas incidentales — un permiso en `settings.json` y dos
   referencias en `current-session.json`/backup listando el issue como pendiente. No hay
   spec en `docs/aura/specs/`, ni idea en `ideas.md`, ni plan en `.agent/memory/plans/`).
   Motivación original (cuerpo del issue): PRs de bookkeeping (`project-log.md`,
   `current-session.json`) crecen fila-a-fila sesión tras sesión cuando en realidad son
   observaciones que *evolucionan* (mismo tema, estado actualizado) — Engram ya soporta
   esto con `topic_key` (`project+scope+topic_key` hace upsert en vez de insert).

2. **Pregunta del usuario sobre desacople de contexto**: durante una tarea de varias
   iteraciones (ej. este mismo flujo Explore → Plan → Review) el contexto crece con
   información que deja de ser relevante una vez que el plan queda aprobado y arranca la
   implementación. Pregunta si es *factible* separar esas etapas.

   **Validación (con hallazgos de exploración, citas exactas):**
   - **Sí es factible, y el harness ya lo implementa parcialmente.** En
     `skills/agentic-dev-loop/SKILL.md:111-112` el dev-runner arranca con un "Prompt
     autocontenido (el agente parte de cero — sin memoria de esta sesión)"; solo recibe el
     body del issue de GitHub (objetivo, archivos, tareas RED→GREEN, DoD). El issue actúa
     como **interfaz serializada** entre el contexto de planning y el de implementación —
     no se arrastra el historial crudo. Además corre en **worktree aislado obligatorio**
     (`skills/agentic-dev-loop/SKILL.md:121-132`, motivado por un incidente real de
     contaminación cruzada, Issues #75/#76).
   - Mecánicamente esto corresponde a usar el `Agent` tool con un `subagent_type` que
     **no** sea `fork`: un agente fresco arranca con contexto cero y debe recibir todo lo
     necesario explícito en el prompt (el plan aprobado, no la conversación completa). Un
     `fork`, en cambio, hereda *todo* el contexto — es la herramienta equivocada para este
     caso, porque el objetivo es justamente descartar lo que ya no se necesita.
   - **Gap real detectado**: este mecanismo NO existe en el flujo interactivo de
     `protocols/task_start.md:61-91` ("Plan → Aprobación → Ejecución") — planificación e
     implementación comparten la misma sesión/agente, así que toda la exploración previa
     (incluyendo hallazgos descartados, iteraciones de diseño, Q&A) sigue en contexto
     durante la implementación. La idea [008] ("/compact — compresión de contexto
     mid-session") es un mecanismo distinto y más débil (comprime, no descarta) y sigue en
     estado `raw`, sin implementar.
   - Conclusión: la pieza que falta no es tecnológica (el `Agent` tool ya lo permite) sino
     de **protocolo** — decidir en qué punto de `task_start.md` conviene handoff a un
     agente fresco alimentado solo con el plan file, y cuándo el costo de ese salto (perder
     matices de la conversación, tener que serializarlo todo al plan) no vale la pena
     frente a simplemente seguir en la misma sesión.

El usuario decidió **no** rediseñar `task_start.md` ahora — solo registrar el hallazgo
como idea en el backlog (`.agent/memory/ideas.md`) para retomarlo con `/brainstorm` en una
sesión futura. El trabajo ejecutable pendiente es exclusivamente el Issue #127.

### Por qué `topic_key` aporta al harness (optimización de tokens)

El problema de fondo no es escribir memoria — es leerla de vuelta. Cada
`mem_context`/`mem_search` en `session_start` trae observaciones completas al contexto.
Sin `topic_key`, un mismo tema que se toca en sesiones sucesivas (estado de un issue,
diseño de un check, estado de un ADR en discusión) genera una fila nueva por sesión en vez
de actualizar la existente; en la sesión siguiente el agente recibe todas las versiones
mezcladas y tiene que leerlas y reconciliar cuál es la vigente antes de poder actuar —
mismo anti-patrón que ya se diagnosticó en `project-log.md`/`current-session.json`
(bookkeeping creciendo fila a fila), replicado dentro de Engram. Con `topic_key`, la
memoria de ese tema converge a un solo estado actualizado (upsert): la recuperación futura
es más chica y no requiere reconciliar versiones obsoletas. La ganancia no es "guardar
menos" — es que cada sesión futura recupera menos y más preciso, sin depender de un
mecanismo lossy como `/compact` para descartar lo superado.

## Approach

### 1. Issue #127 — Documentar convención `topic_key`

**`AGENTS.md`** (sección "## Memoria"):
- Agregar un sub-bloque "### Convención `topic_key`" con:
  - Formato: `family/description` (ej. `bug/harness-update-tag-lag`,
    `project-log/pr-bookkeeping`).
  - Semántica: mismo `project + scope + topic_key` en `mem_save` hace **upsert** (Engram
    actualiza la observación existente) en vez de crear una fila nueva.
  - Cuándo usarlo: observaciones que **evolucionan** sesión a sesión sobre el mismo tema
    (decisiones de arquitectura que se refinan, patrones recurrentes, estado de bookkeeping
    tipo project-log) — no para hechos puntuales o eventos cerrados (esos siguen sin
    `topic_key`, una fila por evento).
  - Ejemplo concreto tomado del propio motivador del issue: el patrón de PRs de
    project-log/current-session.json que crecían fila a fila.

**`protocols/session_end.md`**:
- En el paso donde se guarda memoria (mem_session_summary / mem_save), agregar una
  indicación corta: antes de guardar una observación de tipo "decisión que ya se guardó
  antes y solo cambió de estado", usar `topic_key` consistente con el de la sesión
  anterior (buscar con `mem_search` antes de decidir si es upsert o fila nueva). Enlazar a
  la convención completa en `AGENTS.md`.

No hay código que tocar — es documentación pura, cierra con los 3 criterios de aceptación
del issue tal como están escritos.

### 2. Registrar idea [019] — Desacople de contexto plan→implementación en `task_start.md`

Agregar entrada nueva al final de `.agent/memory/ideas.md`, siguiendo el formato existente
(ver `[001]`-`[018]`):

```
## [019] Desacople de contexto entre planning e implementación en task_start.md
**Estado:** raw
**Capturado:** 2026-08-04
**Prioridad:** Explorar — impacto medio-alto, esfuerzo medio
**Contexto:** Validado en sesión 2026-08-04 que agentic-dev-loop (dev-runner) ya desacopla
contexto plan→implementación vía un agente fresco (Agent tool, no fork) alimentado solo
con el body del issue como interfaz serializada, en worktree aislado
(skills/agentic-dev-loop/SKILL.md:111-132). El flujo interactivo de task_start.md (Plan →
Aprobación → Ejecución, líneas 61-91) NO tiene este mecanismo: mismo agente/sesión continúa
desde planning a implementación arrastrando todo el historial de exploración previa, ya
irrelevante una vez el plan está aprobado. Evaluar si conviene, tras aprobar un plan en
modo interactivo, lanzar un agente fresco alimentado solo con el plan file en vez de seguir
en la misma sesión — y en qué casos el costo de ese salto (perder matices no
serializados al plan) no compensa. Relacionado: idea [008] (/compact mid-session, estado
raw, mecanismo distinto — comprime en vez de descartar).

### Iteraciones
_(sin iterar)_
```

## Verification

- `AGENTS.md`: revisar que la sección "## Memoria" quede legible y el ejemplo de
  `topic_key` sea coherente con el formato `family/description` documentado en el issue.
- `protocols/session_end.md`: confirmar que la referencia a `topic_key` no duplica texto
  ya existente en `AGENTS.md` (solo debe apuntar/enlazar, no repetir la convención completa).
- `.agent/memory/ideas.md`: confirmar que `[019]` sigue el mismo formato que las entradas
  anteriores (Estado/Capturado/Prioridad/Contexto/Iteraciones) y que el ID no colisiona
  (último usado: `[018]`).
- Cerrar Issue #127 con `gh issue close 127 --comment "Implementado en PR #<N>"` una vez
  mergeado, siguiendo el flujo estándar de `agents/github.md`.
