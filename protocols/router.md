# Protocol — Router de Contexto

> **Propósito:** Determinar qué archivos cargar según la situación actual. Permite que AGENTS.md sea un spine liviano sin perder cobertura.
> **Cuándo leer este archivo:** Al inicio de sesión (desde session_start) y al comenzar cualquier tarea nueva.

---

## Tabla de Routing

| Situación | Archivos a cargar | Trigger |
|-----------|------------------|---------|
| **Inicio de sesión** | `protocols/session_start.md` | Primera interacción del día o contexto frío |
| **Nueva tarea / issue** | `protocols/task_start.md` | Usuario menciona nueva feature, fix, chore, o tarea |
| **Retomar tarea** | `protocols/task_start.md` + `.agent/memory/current-session.json` | "Continuemos con...", "seguimos donde..." |
| **Operaciones git / GitHub** | `agents/github.md` | Crear rama, PR, issue, merge, push, cherry-pick |
| **Escribir o revisar código** | `agents/language.md` | Implementar feature, fix bug, refactorizar |
| **Docker / CI / deploy** | `agents/infra.md` | Dockerfile, workflows, environments, secrets |
| **Revisar antes de merge** | `agents/reviewer.md` | Pre-merge, code review, quality gate |
| **Cuestionar un plan o spec** | `agents/challenger.md` | Spec lista para pasar a /write-plan |
| **Validar spec técnicamente** | `skills/spec-validation/SKILL.md` | Después de /brainstorm, antes de challenger |
| **Planificar trabajo nuevo** | `skills/issue-planning/SKILL.md` via `/plan-work` | Usuario describe trabajo nuevo, no hay issues ready |
| **Rama lista para PR** | `skills/finishing-a-development-branch/SKILL.md` via `/finish-branch` | Commits sin PR, rama completa |
| **Solicitar code review** | `skills/requesting-code-review/SKILL.md` via `/request-review` | PR abierta lista para revisión |
| **Cambios en documentación** | `agents/doc-guardian.md` via `/doc-check` | Se creó o modificó un archivo .md |
| **Gestionar objetivos / ideas** | `skills/idea-management/SKILL.md` via `/idea` | Usuario escribe `/idea`, registra idea, o quiere explorar/promover un objetivo |
| **Mejorar el harness** | `skills/auto-research/SKILL.md` + `docs/aura/specs/2026-05-09-harness-pillars.md` | Fricción detectada, patrón repetitivo |
| **Seleccionar / cambiar stack** | `skills/stack-selection/SKILL.md` via `/stack` | Sin session-stack.json, inicio de proyecto nuevo, o usuario quiere cambiar stack |
| **Reporte de plan estratégico** | `skills/plan-reporting/SKILL.md` via `/plan-report` (ejecutado por `plan-reporter`) | Usuario pide reporte de gestión, tareas accionables, análisis de riesgo de un plan |
| **Loop de desarrollo + verificación de issues** | `skills/agentic-dev-loop/SKILL.md` via `/run-dev-loop` | Usuario pide correr/automatizar el desarrollo de issues `ready`, o avisa que cerró/mergeó un issue y hay que revisarlo |
| **Manejo de datos sensibles / repo público** | `.claude/rules/sensitive-data-safety.md` | Repo público con datos de cliente, antes de commit/push, o session_start detecta `visibility=public` |
| **Cierre de sesión** | `protocols/session_end.md` | "Terminamos", "cerramos", fin de trabajo |

---

## Reglas de Carga

1. **Cargar solo lo necesario** — no precargar todos los archivos al inicio
2. **Una situación puede requerir múltiples archivos** — ej: nueva tarea de código carga `task_start.md` + `language.md`
3. **Los archivos de pilares** (`docs/aura/specs/2026-05-09-harness-pillars.md`) solo se cargan cuando se invoca challenger o auto-research
4. **AGENTS.md (spine) siempre está cargado** — no necesita estar en esta tabla
5. **En caso de duda** sobre qué cargar → leer este router primero, luego decidir

---

## Casos Compuestos Frecuentes

| Escenario | Carga |
|-----------|-------|
| Inicio + tarea nueva de código | `session_start.md` → `task_start.md` → `language.md` |
| Fix urgente con PR | `task_start.md` → `language.md` → `github.md` |
| Diseño + implementación completa | `task_start.md` → (brainstorm) → `spec-validation` → `challenger` → `language.md` → `github.md` → `reviewer.md` |
| Inicio sin issues pendientes | `session_start.md` → `/plan-work` → `task_start.md` |
| Inicio sin stack detectado | `session_start.md` → `stack-selection/SKILL.md` → capability menu |
| Proyecto nuevo desde cero | `stack-selection/SKILL.md` → estructura inicial → `github.md` → `/plan-work` |
| Rama terminada | `session_end.md` → `/finish-branch` → `/request-review` |
| Cierre con cambios en .md | `session_end.md` → `/doc-check` |
| Cierre con fricción detectada | `session_end.md` → `/auto-research` |
| Mejora al harness | `/auto-research` → `harness-pillars.md` → `challenger.md` |
| Reporte de plan + análisis | `/plan-report` → `plan-reporter` → scripts/plan_report.py |
| Loop de issues ready → review | `/run-dev-loop` → `agentic-dev-loop` (Fase 1 dev-runner → Fase 2 verifier) |

---

## Para Proyectos Complejos

En proyectos con múltiples dominios, equipos o integraciones donde el contexto es imprevisible, considerar reemplazar esta tabla estática por un **router subagente** que razone sobre el contexto antes de decidir qué cargar. El costo adicional (~500-1.000 tokens/invocación) se justifica cuando los casos compuestos son frecuentes y difícilmente anticipables.
