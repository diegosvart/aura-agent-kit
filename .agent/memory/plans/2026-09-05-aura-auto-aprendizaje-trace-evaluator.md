---
status: approved
fase_0_status: done
fase_0_pr: "#225"
fase_0_commit: ddf523c838e029f9fe2720b05953fbf8d70eda55
fase_0_completed_at: 2026-09-05
---

# Plan — Auto-aprendizaje de Aura: traza de sesión + loop de mejora continua + proyecto de evaluación

## Context

Esta sesión (2026-09-05) ejerció manualmente, por primera vez, un flujo que hasta ahora no
existía como capability del harness: generar una **traza real del comportamiento de una
sesión de Aura** (no del flujo diseñado en `router.md`, sino de lo que efectivamente pasó) en
formato JSON de Archify, validarla, y renderizarla a un diagrama HTML. Ese ejercicio, sin
buscarlo, ya reveló 3 fricciones reales del harness en una sola sesión (tensión worktree vs.
regla irrompible, un bug real en `cut-release.sh` nunca disparado antes, y un guardrail de
plataforma no documentado en `agents/github.md`).

El usuario quiere dejar de hacer esto a mano y convertirlo en la base del **auto-aprendizaje**
de Aura: (1) una herramienta de mejora continua que se construye en paralelo al trabajo
normal, pensada ya con la mira en que Aura escalará a producto (no un experimento descartable);
y (2) un proyecto nuevo, separado, donde el harness corra sesiones reales evaluadas
sistemáticamente por agentes evaluadores/cuestionadores de objetivos, resultados y sesiones —
no solo specs puntuales (eso ya lo hace `challenger`), sino el comportamiento agregado sesión a
sesión.

El harness ya tiene piezas parciales de esto, hoy desconectadas entre sí:
- `skills/observability/scripts/process-session.sh` — métricas cuantitativas (`delegation_rate`,
  tokens, tool_uses) por sesión, sin skill/doc propio, solo invocado desde
  `session_start.md` Paso 5.5.
- `skills/auto-research/SKILL.md` — formaliza hipótesis P4 cuando se detecta fricción, pero
  depende de que el agente "note" la fricción en el momento; no audita sesiones pasadas.
- `agents/challenger.md` — cuestiona una spec/plan puntual **antes** de implementar, con
  formato de veredicto (`[CRÍTICO]/[ADVERTENCIA]/[MEJORA]/[INFO]`, `GO/NO-GO`). No mira
  sesiones ya ocurridas.
- Nada hoy cierra el loop completo: métrica → hallazgo → hipótesis → cambio → verificación en
  las próximas sesiones. Cada pieza vive suelta.

Este plan formaliza la traza de sesión como capability (Fase 0), conecta las piezas existentes
en un loop real de mejora continua con un rol evaluador nuevo (Fase 1), y define el proyecto
consumidor separado donde ese loop corre sobre sesiones reales (Fase 2) — con una mirada
transversal de productización (Fase 3). Sigue el mismo patrón de separación ya validado con
`aura-harness-diagrams` (harness fuente vs. consumidor) y el mismo criterio de "un issue, una
sesión" del backlog actual.

## Approach

### Fase 0 — Formalizar la traza de sesión (en `aura-agent-kit`, el harness fuente)

Nueva skill `skills/session-trace/SKILL.md` que documenta, en vez de dejarlo implícito, lo que
se ejerció manualmente hoy:

- **Qué es y qué no es**: un JSON IR de Archify (`diagram_type: sequence` o `lifecycle` según
  el caso) autoreado por el propio agente al final de la sesión — no un parser automático del
  transcript. Archify exige "fresh authorship, new stable IDs, domain wording" por diseño; un
  generador determinístico desde logs traicionaría ese contrato y produciría diagramas
  ilegibles (evidencia de hoy: el primer intento con 47 mensajes y viewBox por defecto falló
  validación 2 veces antes de ajustar `column_fit`/`viewBox`/labels).
- **Cuándo se genera**: paso **opcional, fail-open** agregado a `protocols/session_end.md` —
  mismo patrón que la propuesta de `/auto-research` ("¿hubo fricción esta sesión? → proponer").
  Nunca bloquea el cierre de sesión.
- **Dónde vive**: `.agent/memory/observability/traces/<fecha>-<slug>.sequence.json` (+ `.html`
  generado bajo demanda) — gitignored, mismo criterio que `sessions.jsonl`/`current-session.json`
  (ADR-003: telemetría de comportamiento, no versionar).
- **Dependencia de Archify**: se mantiene **opcional y bajo demanda** (`npx skills add
  tt-a1i/archify -g`, como se hizo hoy), nunca vendorizada dentro de `aura-agent-kit` — el
  harness fuente sigue "bash-scripts + markdown" (P6). La skill documenta el comando de
  instalación y los dos pasos (`validate` → `deliver`), con los gotchas reales encontrados hoy
  (rango vertical `y` ligado al `viewBox`, ancho de labels ligado a `column_fit`).

### Fase 1 — Loop de mejora continua (en `aura-agent-kit`)

Conecta lo que hoy vive suelto en un ciclo real, sin inventar mecanismo nuevo donde ya hay uno:

1. **Insumo cuantitativo**: `sessions.jsonl` (observability existente) — ya calcula
   `delegation_rate` y métricas de tool-use por sesión.
2. **Insumo cualitativo**: traza de sesión (Fase 0) — muestra *cómo* pasó lo que las métricas
   dicen *que* pasó.
3. **Rol nuevo — `agents/evaluator.md`**: a diferencia de `challenger` (cuestiona una spec
   puntual *antes* de codear), este agente cuestiona **sesiones ya ocurridas**: dado un rango
   de sesiones recientes (métricas + trazas disponibles), evalúa si los objetivos declarados
   (`objectives.md`) se cumplieron, si lo que se declaró "hecho" se verificó de verdad
   (`harness-core.md` regla de no afirmar sin verificar), y si el protocolo se siguió
   (delegation_rate, uso de worktree, pasos saltados). Reusa el mismo formato de veredicto de
   `challenger` (`[CRÍTICO]/[ADVERTENCIA]/[MEJORA]/[INFO]`, `GO/NO-GO`) para no fragmentar
   convenciones.
4. **Salida → `auto-research`**: cada `[CRÍTICO]`/`[ADVERTENCIA]` del evaluador es candidato a
   hipótesis P4 — el evaluador no cambia el harness directamente, propone.
5. **Trigger**: bajo demanda (`/evaluate-sessions` o similar) — no automático en cada
   `session_start`/`session_end` todavía; automatizarlo es prematuro sin datos de varias
   corridas (mismo criterio de cautela que ya aplica `.aura/rules/subagent-dispatch.md` sobre
   `delegation_rate`: no pasar a enforcement duro sin evidencia).

### Fase 2 — Proyecto de evaluación continua (repo consumidor nuevo, separado)

Mismo patrón ya validado con `aura-harness-diagrams`: repo nuevo, privado, que instala
`.aura/` como submodule pinneado a un release concreto (arrancar en `v2.6.1`, el que se acaba
de cortar), **no** a `develop` flotante — por la misma razón de reproducibilidad ya documentada
en el plan de Archify.

- Propósito: ejercitar el harness en sesiones de trabajo real (no sintéticas) y correr el loop
  de la Fase 1 sesión a sesión, acumulando evidencia longitudinal — el "banco de pruebas
  continuo" que hoy no existe (las 28 sesiones actuales de `aura-agent-kit` son trabajo real
  mezclado con desarrollo del propio harness, lo que contamina la medición).
- Cada sesión ahí produce: traza (Fase 0) + métricas (observability existente) + veredicto del
  evaluador (Fase 1) — mismo trío, acumulado en un dataset propio de ese repo, nunca mezclado
  con la telemetría de `aura-agent-kit`.
- Handoff: igual que con `aura-harness-diagrams`, esta sesión prepara el scaffold + primer
  issue; una sesión nueva de Claude Code corriendo *dentro* de ese repo es quien genera las
  sesiones reales a evaluar.

### Fase 3 — Mirada de productización (transversal, no una fase separada en el tiempo)

- Separación explícita: lo que vive en `aura-agent-kit` (skills/agentes de Fase 0-1) es **IP
  del harness fuente**, versionada y reutilizable por cualquier consumidor futuro. Lo que
  genera el repo de Fase 2 es **telemetría de un consumidor**, nunca se mezcla de vuelta al
  harness fuente sin pasar por el mismo filtro que hoy aplica a fricciones reales
  (`auto-research`, con hipótesis y aprobación explícita).
- No diseñar multi-tenant real todavía (no hay usuarios reales más allá de este) — pero evitar
  decisiones que lo bloqueen: los esquemas de `sessions.jsonl`/trazas ya son razonablemente
  genéricos (no asumen una sola máquina/usuario); no se necesita cambio adicional ahora, solo
  no romper esa propiedad al implementar Fase 0-1.

## Archivos/acciones críticas

- `aura-agent-kit`: `skills/session-trace/SKILL.md` (nuevo), `agents/evaluator.md` (nuevo),
  `protocols/session_end.md` (agrega paso opcional fail-open), `.agent/memory/objectives.md`
  (nueva entrada Norte: "auto-aprendizaje de Aura").
- Repo nuevo (Fase 2, nombre a definir en el issue — ej. `aura-continuous-eval`): mismo
  scaffold que `aura-harness-diagrams` (`install.sh`, `.aura/` pinneado a `v2.6.1`,
  `AGENTS.local.md`, hooks), issue inicial con el loop de la Fase 1 corriendo sobre su propia
  primera sesión real.

## Alcance de este plan vs. el issue inmediato

Este plan documenta las 4 fases completas, pero el **issue a crear ahora es solo Fase 0**
(la traza de sesión como skill formal) — es la pieza más chica y validable de forma
independiente, y las Fases 1-2-3 dependen de tener Fase 0 probada en más de una sesión antes
de generalizar (mismo criterio de P7: evolución con validación, no imponer todo de una). Las
Fases 1-2-3 quedan registradas acá como roadmap, a convertirse en issues nuevos cuando Fase 0
esté verificada.

## Verificación

- `skills/session-trace/SKILL.md` existe y sigue el mismo formato de frontmatter que las
  demás skills (`name`, `description` accionable para el router).
- `protocols/session_end.md` con el nuevo paso opcional no rompe el flujo de cierre existente
  si el usuario lo rechaza (fail-open, verificable corriendo un cierre de sesión sin traza).
- Issue de Fase 0 creado en `diegosvart/aura-agent-kit` con label `ready`, sin bloquear el
  backlog P0 actual (`#217` sigue como prioridad estructural — este es trabajo en paralelo,
  no un reemplazo).
