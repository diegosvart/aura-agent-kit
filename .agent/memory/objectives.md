# Objetivos — Aura Agent Kit

> Norte (largo plazo) vs ASAP (bloqueante ahora). Se edita in-place, no es append-only.

---

## ASAP — Backlog priorizado (actualizado 2026-09-18)

> Refresco completo: el bloque anterior (fechado 2026-09-05) tenía **14 de 16 issues
> referenciados ya cerrados** (verificado vía `gh issue view` en esta sesión) — incluidos
> #217/#210, que seguían listados como "P0 bloqueante estructural" pese a estar cerrados desde
> 2026-09-09. Nota histórica importante: **#217 resolvió `agentic-dev-loop` eliminando
> `isolation:"worktree"` (reemplazado por rama+lock)**, dirección opuesta a cualquier trabajo
> futuro que busque paralelismo real vía worktrees — cualquier brainstorm sobre ese tema debe
> partir de esta decisión previa, no ignorarla.

### Único ítem abierto heredado del bloque anterior
- **#199** — idea: fork sandbox para prototipar triaje FAST/STANDARD/DEEP + memoria con
  evidencia (inspirado en adaptive-engineering). Sigue `OPEN`, sin label `ready`. No verificado
  en esta sesión si sigue vigente como prioridad — confirmar con el usuario antes de retomarlo.

### Release v2.8.0 (cortado 2026-09-18) — pendientes explícitos que dejó
- **Issue #306** (`ready`, único crítico abierto) — `AGENTS.local.md` existe en la raíz pero no
  se carga en sesión (import `@../AGENTS.local.md` de CLAUDE.md). Priorizado por el usuario
  para dejarlo abierto y avanzar el release primero.
- Gap de documentación en `.agent/memory/project-log.md` (PRs #246→#310, salvo #245/#255/#299)
  — deuda no resuelta, sin issue propio todavía.
- `TODO: regenerar grafo cerebro contra v2.8.0` en `aura-harness-diagrams` — sin acceso local a
  ese checkout en la sesión del release.

### 3 líneas de trabajo nuevas planteadas por el usuario (sesión 2026-09-18, en curso)
Estado real relevado antes de brainstorm — ver `docs/aura/specs/` para el detalle de cada spec
citada:

1. **Flujo de proceso de AURA visible durante la sesión** — ya existe spec con GO de Challenger
   (`2026-09-14-harness-graph-cerebro-design.md`, grafo "Cerebro" read-only en
   `aura-harness-diagrams`), **sin implementar**. Resuelve la vista de auto-análisis offline,
   no necesariamente "el agente lo conoce en runtime" tal como lo planteó el usuario — a
   confirmar alcance real en el brainstorm.
2. **Sesiones de mayor duración/tareas** — observability Modo 1/2 ya implementada
   (`skills/observability/SKILL.md`); spec con GO de Challenger para atacar la causa raíz
   (`2026-09-13-delegacion-real-orquestador-design.md`, campo `Despacho` obligatorio en el Plan
   de `task_start.md`), **sin implementar** — el paso "crear issue de implementación" del
   "Próximos pasos" de esa spec nunca se ejecutó.
3. **Paralelismo real con subagentes en worktrees** — tensiona directamente con la decisión de
   #217 (arriba). La regla anti-worktree (`agents/github.md`) ya reserva ese caso de uso como
   excepción declarada pero nunca implementada — es aspiracional, no una capacidad real hoy.

---

## Norte (largo plazo)

(sin definir aún)
