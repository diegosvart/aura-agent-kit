---
status: approved
---

# Plan — Spec "Flujo del orquestador respetado" (Issue #148 + delegación + auto-aprendizaje activo)

## Context

Issue #148 documenta el **3er incidente** del mismo bug (`gh pr create` sin `--base`) pese a
2 "fixes" de texto anteriores. Esta sesión investigó tres frentes (Issue #148, capacidades
reales de delegación de subagentes en Claude Code, y el mecanismo de auto-aprendizaje ya
construido) y encontró un patrón único de fondo, confirmado ahora con **un inventario
completo y exhaustivo** de todo el harness (commands, skills, agents, hooks):

> Todo lo que está forzado por **script/hook determinístico** se respeta siempre. Todo lo
> que vive solo como **instrucción en Markdown** se salta bajo presión — incluidos dos gates
> que se autodenominan literalmente **"HARD-GATE"** en su propio texto
> (`commands/brainstorm.md:16`, `skills/spec-validation/SKILL.md:10`) sin que ningún hook
> verifique su resultado antes de dejar avanzar. De todo el pipeline de diseño
> (brainstorm → spec-validation → challenger → TDD), el **único** gate con enforcement real
> es "no commitear a develop/main" (`git-guard.ps1`).

El inventario también encontró 2 inconsistencias puntuales (colgantes, sin dueño):
`commands/plan-report.md` referencia `.claude/agents/plan-reporter.md`, que no existe en
ningún lado; `skills/observability/` no tiene `SKILL.md` (no es invocable como las otras 17
skills). Ambas son sintomáticas del problema de fondo: nada mantiene la coherencia del
inventario del harness automáticamente.

**Decisión del usuario en esta sesión, que amplía el alcance original:** no alcanza con
diseñar el gate — hay que poder **verificar objetivamente** si el flujo se respetó,
comparando un diagrama de **flujo esperado** (ya encargado como issues #1/#2 en
`aura-harness-diagrams`, repo consumidor separado — router de contexto y ciclo de sesión)
contra la **traza real** que ya genera `session-trace` (Fase 0 de auto-aprendizaje, hecha) al
cierre de cada sesión. Esto es exactamente la Fase 1 (`agents/evaluator.md`) de la spec de
auto-aprendizaje ya aprobada (`docs/aura/specs/2026-09-05-proceso-auto-aprendizaje-aura.md`),
que el diseño original de esta sesión había excluido — el usuario pidió traerla adentro como
trabajo activo.

La detección de acciones repetitivas del agente que deberían convertirse en script/skill
(para bajar consumo de tokens) queda **fuera** de esta spec como diseño completo — es un
proceso aparte, aguas abajo, alimentado por los hallazgos del evaluador pero no entregable de
esta spec (evita repetir el patrón de scope creep que ya se cortó una vez en esta misma
sesión).

## Approach — escribir la spec

Archivo único: `docs/aura/specs/2026-09-06-flujo-respetado-orchestrator.md`. Estructura final
(6 frentes, cada uno independientemente verificable):

### 1. Problema
Los 3 incidentes de #148 + tabla completa de gates reales vs. declarados (del inventario de
hoy) + las 2 inconsistencias encontradas, como evidencia de que el patrón es transversal, no
solo del flujo git.

### 2. Objetivo y no-objetivos
Objetivo: gate generator-verifier medible + delegación con señal real + verificación
esperado-vs-ejecutado activa. No-objetivos explícitos (ver "Fuera de alcance").

### 3. Patrón de diagnóstico transversal
La tabla "script > prosa", ahora con el inventario completo como evidencia (no solo 3
ejemplos puntuales).

### 4. Frente A — Enforcement de git flow
- Extender el hook `PreToolUse` existente (`.claude/settings.json`) para bloquear
  `gh pr create` sin `--base`, y ampliar el radar a otros comandos `gh` de riesgo similar
  (`gh pr merge`, `gh pr edit --base`) — decisión del usuario.
- Generalizar el patrón de `open-pr.sh` (comando hardcodeado) a `request-review.md:39`.
- Formalizar el gate generator-verifier: ningún ciclo de trabajo se cierra sin veredicto de
  verificación registrado — extiende lo que Fase 2 de `agentic-dev-loop` ya hace, hoy
  limitado a ese camino.
- Se descarta "subagente git-ops dedicado" (mismo modo de falla con indirección extra).

### 5. Frente B — Delegación de subagentes (piloto)
Frontmatter YAML (`description` con "use proactively"/"use after") en 3 agentes piloto:
`reviewer.md`, `challenger.md`, `github.md`. Experimento: medir `delegation_rate`
(`process-session.sh`) antes/después, filtrado por esos 3 agentes.

### 6. Frente C — Verificación esperado-vs-ejecutado activa (NUEVO, trae Fase 1 de
auto-aprendizaje a esta spec)
- **Diagrama de referencia**: generado y versionado en `aura-harness-diagrams` (issues #1
  router de contexto, #2 ciclo de sesión, ya creados con label `ready`). No se duplica en
  `aura-agent-kit`.
- **`flow-conformance-check`**: análisis nuevo dentro de `agents/evaluator.md` (Fase 1 de
  `docs/aura/specs/2026-09-05-proceso-auto-aprendizaje-aura.md`, promovida de roadmap a
  trabajo activo por esta spec). Compara la traza real de una sesión (`session-trace`,
  Fase 0 ya hecha) contra el diagrama de referencia versionado en `aura-harness-diagrams`,
  produce hallazgos `[CRÍTICO]/[ADVERTENCIA]/[MEJORA]/[INFO]` + veredicto `GO/NO-GO` (mismo
  formato que `challenger`). Se dispara con `/evaluate-sessions` (comando ya previsto en la
  spec de auto-aprendizaje).
- **Prerequisito técnico a diseñar en la spec**: cómo `evaluator.md` (corriendo en
  `aura-agent-kit`) lee un archivo que vive en otro repo (`aura-harness-diagrams`, privado)
  — opción simple a documentar: ruta de checkout local configurada (mismo patrón que
  `aura-harness-diagrams-work` de esta sesión), sin inventar sincronización automática nueva.
- **Manifiesto de capacidades vivo** (`docs/aura/CAPABILITIES.md`): consolidado de
  commands/skills/agents/hooks con su gate real (duro vs. texto) — mantenido por
  `agents/doc-guardian.md` (agente existente, se le agrega esta responsabilidad) en cada
  `/doc-check`. Resuelve sistemáticamente el tipo de inconsistencia encontrada hoy
  (`plan-reporter.md` colgante, `observability` sin `SKILL.md`) en vez de depender de que
  alguien lo note manualmente.

### Fuera de alcance (no-objetivos explícitos)
- Diseño completo del "proceso aparte" que detecta acciones repetitivas → candidatas a
  script/skill — se documenta como siguiente paso natural, alimentado por los hallazgos de
  `flow-conformance-check`, pero no se diseña en esta spec.
- Adoptar el `Workflow` tool para reestructurar `agentic-dev-loop` (spec propia).
- Frontmatter a los 9 `agents/*.md` de una sola vez (solo los 3 piloto).
- Reescribir `complexity-tiering.md`.
- Corregir ahora mismo las 2 inconsistencias encontradas (`plan-reporter.md`,
  `observability`) — quedan documentadas en el Problema como evidencia, y las resuelve el
  Frente C (manifiesto vivo) una vez implementado, no como fix suelto de esta sesión.

### Criterios de éxito medibles
- Cero incidentes de PR con `--base`/target incorrecto en las próximas 20 sesiones que abran
  PR.
- 100% de los ciclos de trabajo cerrados quedan con veredicto de verificación registrado
  (evento discreto medible, no promesa sobre el futuro).
- `delegation_rate` de los 3 agentes piloto sube de forma notoria vs. baseline ~0.
- `flow-conformance-check` corre al menos 1 vez sobre una sesión real y produce un veredicto
  (GO/NO-GO) comparando contra el diagrama de referencia — prueba de que el mecanismo cierra
  el loop, no solo que quedó diseñado.

## Archivos

- **Nuevo:** `docs/aura/specs/2026-09-06-flujo-respetado-orchestrator.md` (deliverable de
  este plan).
- **Referenciados, no modificados en este plan:** `.claude/settings.json`,
  `.claude/hooks/git-guard.ps1`, `agents/reviewer.md`, `agents/challenger.md`,
  `agents/github.md`, `agents/doc-guardian.md`, `agents/evaluator.md` (no existe aún — se
  crea cuando esta spec pase a `/plan-work`), `.aura/rules/subagent-dispatch.md`,
  `skills/agentic-dev-loop/SKILL.md`, `docs/aura/specs/2026-09-05-proceso-auto-aprendizaje-aura.md`.
- **Repo externo referenciado:** `aura-harness-diagrams` (issues #1/#2, diagrama de
  referencia vive ahí).

## Verificación

- La spec sigue el formato de `2026-09-05-proceso-auto-aprendizaje-aura.md`
  (Problema/Objetivo/Frentes/Verificación), con los 6 frentes como secciones
  independientemente verificables.
- Cada criterio de éxito es un umbral numérico o evento discreto, ninguno es promesa no
  medible.
- La sección "no-objetivos" lista explícitamente los 5 puntos fuera de alcance.
- Siguiente paso después de escribir la spec: `/brainstorm` (afinar lista exacta de comandos
  `gh` del hook, confirmar prerequisito técnico cross-repo del Frente C) →
  `spec-validation` → `challenger` → `/plan-work`.
