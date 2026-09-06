---
status: approved
---

# Plan — Issue #232: agents/evaluator.md (Fase 1 auto-aprendizaje)

## Contexto

Fase 0 del plan `.agent/memory/plans/2026-09-05-aura-auto-aprendizaje-trace-evaluator.md`
(session-trace) ya está hecha (PR #225). Fase 1 conecta las piezas sueltas del harness
(`observability` cuantitativo + `session-trace` cualitativo) en un rol nuevo,
`agents/evaluator.md`, que — a diferencia de `challenger.md` (cuestiona una spec *antes* de
codear) — cuestiona **sesiones ya ocurridas**: compara la traza real de comportamiento contra
un diagrama de referencia versionado en el repo consumidor `aura-harness-diagrams`, y emite
veredicto `GO/NO-GO` con el mismo vocabulario de `challenger` (`[CRÍTICO]/[ADVERTENCIA]/
[MEJORA]/[INFO]`) para no fragmentar convenciones.

El Issue #232 (label `ready`) agrega tres piezas más sobre esa base: (a) config cross-repo
gitignored para resolver la ruta del checkout local de `aura-harness-diagrams` con fallback
fail-clear/fail-soft, (b) manifiesto vivo de capacidades mantenido por `doc-guardian`, y (c)
verificación obligatoria con corrida real (no solo diseño en papel) antes de mergear.

## Diseño de `agents/evaluator.md`

Mismas 3 secciones obligatorias que valida `doc-guardian` para `agents/*.md` (Rol / Cuándo Se
Invoca / Herramientas — ver `agents/doc-guardian.md:61-64`), y mismo formato de veredicto que
`agents/challenger.md` (no inventar vocabulario nuevo):

- **Rol**: evaluador retrospectivo de sesiones — no de specs. Reusa el trío
  métricas (`sessions.jsonl`) + traza cualitativa (`skills/session-trace/SKILL.md`) + diagrama
  de referencia (`aura-harness-diagrams`) descrito en el plan de Fase 1.
- **Cuándo se invoca**: bajo demanda (comando `/evaluate-sessions`, nuevo — sigue el patrón de
  `commands/doc-check.md`), nunca automático en `session_start`/`session_end` (decisión ya
  tomada en el plan de origen, punto 5 de Fase 1 — evita enforcement duro sin evidencia,
  mismo criterio que `.aura/rules/subagent-dispatch.md` aplica a `delegation_rate`).
- **Config cross-repo** (`.agent/memory/evaluator-config.json`, gitignored — nuevo):
  - Campo único: `diagrams_repo_path` (ruta absoluta al checkout local de
    `aura-harness-diagrams`).
  - **Fail-clear**: si el archivo no existe o la ruta no resuelve a un directorio real →
    detener y preguntar la ruta al usuario antes de continuar. No asumir default.
  - **Fail-soft en persistencia** (mismo bug ya documentado para `current-session.json` en
    sesiones background): tras preguntar la ruta, intentar `Write` del config; si falla,
    seguir la corrida con la ruta en memoria y avisar explícitamente "no persistió" — nunca
    fallar en silencio ni bloquear la evaluación.
  - Se agrega `.agent/memory/evaluator-config.json` a `.gitignore` (hoy no cubierto por
    ningún patrón existente — verificado, la única entrada de `.agent/memory/*.json` hoy es
    `current-session.json` explícito).
  - Se versiona `.agent/memory/evaluator-config.json.example` con
    `{ "diagrams_repo_path": "C:/repos/aura-harness-diagrams" }` como referencia (mismo
    patrón que `.claude/sensitive-terms.local.txt.example`).
- **Proceso — `flow-conformance-check`**:
  1. Resolver `diagrams_repo_path` (con el fallback de arriba).
  2. Elegir el diagrama de referencia según qué se evalúa — para conformidad de protocolo de
     sesión, `output/aura-agent-kit/ciclo-vida-sesion.json` (`diagram_type: lifecycle`,
     estados: `session-start → task-start → delegar-inline/routing-menu → session-end →
     sesion-cerrada` — ver `meta.views` del propio JSON).
  3. Reconstruir la secuencia real de estados de la sesión evaluada: preferir una traza de
     `skills/session-trace/SKILL.md` (Fase 0) si existe para esa sesión; si no existe,
     declarar la limitante explícitamente y usar el registro disponible de la sesión activa
     (menos preciso, pero no bloquea la evaluación).
  4. Mapear cada paso real al estado del diagrama de referencia más cercano.
  5. Comparar orden/completitud: estados saltados, invertidos, o no contemplados en el
     diagrama → hallazgo.
  6. Emitir reporte con el mismo formato de `agents/challenger.md:74-93`
     (`[CRÍTICO]/[ADVERTENCIA]/[MEJORA]/[INFO]` + `### Veredicto` `GO`/`NO-GO`).
- **Reglas**: solo lee y reporta (no modifica nada — mismo principio que `challenger`/
  `doc-guardian`); cada `[CRÍTICO]`/`[ADVERTENCIA]` es candidato a hipótesis de
  `/auto-research`, el evaluador no cambia el harness directamente (ya decidido en el plan de
  origen, Fase 1 punto 4).
- **Herramientas**: `Read`, `Glob` (ubicar diagramas/trazas), `Write` (único uso: persistir
  `evaluator-config.json` tras confirmar la ruta con el usuario).

## Manifiesto vivo de capacidades (`doc-guardian`)

- `agents/doc-guardian.md`: nueva sección "8. Manifiesto vivo de capacidades" en "Qué
  Verifica" — al correr con `--all` (o un flag `--manifest` nuevo), reconstruye
  `docs/aura/CAPABILITIES.md` listando agentes (`agents/*.md`), skills (`skills/*/SKILL.md`),
  comandos (`commands/*.md`) y protocolos (`protocols/*.md`) con su descripción de una línea
  (tomada del frontmatter `description` en skills, o la primera línea bajo el título en
  agentes/comandos/protocolos que no tienen frontmatter).
- `docs/aura/CAPABILITIES.md` (nuevo, versionado — es documentación viva, no telemetría
  efímera, no aplica la exclusión de `docs/aura/specs/`).

## Verificación (obligatoria antes de mergear, por AC del issue)

1. **Config fail-clear/fail-soft**: test manual simulando (a) archivo ausente, (b) ruta
   inválida, (c) `Write` bloqueado tras confirmar la ruta — documentar los 3 resultados.
2. **`doc-guardian` corrida real**: ejecutar su proceso sobre el repo y confirmar que detecta
   las 2 inconsistencias ya conocidas (`commands/plan-report.md` →
   `.claude/agents/plan-reporter.md` inexistente; `skills/observability/` sin `SKILL.md`) —
   incluir la tabla de salida real en la descripción del PR.
3. **`flow-conformance-check` real**: correrlo usando
   `C:/repos/aura-harness-diagrams/output/aura-agent-kit/ciclo-vida-sesion.json` como
   diagrama de referencia y la trayectoria real de **esta misma sesión** (background,
   Issue #232) como traza a evaluar — produce la tabla "Requerimiento vs. Resultado de test
   real" con veredicto `GO`/`NO-GO`, incluida en el PR.

## Archivos

- `agents/evaluator.md` (nuevo)
- `.agent/memory/evaluator-config.json.example` (nuevo, versionado)
- `.gitignore` (agregar `.agent/memory/evaluator-config.json`)
- `agents/doc-guardian.md` (agrega sección de manifiesto)
- `docs/aura/CAPABILITIES.md` (nuevo, generado por la corrida real de doc-guardian)
- `commands/evaluate-sessions.md` (nuevo, trigger del agente — sigue el patrón de
  `commands/doc-check.md`)
- `protocols/router.md` (agregar fila "Evaluar sesiones pasadas" a la tabla de routing)

## Rama y PR

Ya en worktree aislado de esta sesión de background. Crear rama `feature/issue-232-evaluator-flow-conformance`
desde `develop` (fetch + checkout -b), commits convencionales, PR con `--base develop` al
terminar (per `pr-base-guard.ps1`).
