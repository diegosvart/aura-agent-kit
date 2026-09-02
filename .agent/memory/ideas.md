# Ideas Backlog

> Parking de objetivos e ideas sin detallar. Para iterar usar `/idea <N>`. Para convertir en tarea usar `/idea promote <N>`.
> Formato: ID secuencial, estado, contexto, iteraciones.

---

## [001] Verificar hooks PS1 en Claude Code desktop
**Estado:** raw  
**Capturado:** 2026-05-09  
**Prioridad:** Quick win — impacto medio, esfuerzo bajo  
**Contexto:** Surgió al completar PR #14; los hooks se implementaron y probaron en CLI pero no se validó su ejecución en el cliente desktop de Claude Code.

### Iteraciones
_(sin iterar)_

---

## [002] Skill /auto-research activable desde session_end
**Estado:** raw  
**Capturado:** 2026-05-09  
**Prioridad:** Quick win — impacto medio, esfuerzo bajo  
**Contexto:** Fricción detectada al cerrar sesión — si hay patrones repetitivos acumulados, debería sugerirse /auto-research automáticamente sin que el usuario lo pida.

### Iteraciones
_(sin iterar)_

---

## [003] session-end hook + integración directa con Engram
**Estado:** raw  
**Capturado:** 2026-05-09  
**Prioridad:** Hacer — impacto alto, esfuerzo medio  
**Contexto:** El hook session-end podría llamar mem_session_summary directamente vía CLI engram en lugar de depender de que el agente lo recuerde al cerrar.

### Iteraciones
_(sin iterar)_

---

## [004] Documentación formal del Harness como servicio de consultoría TI
**Estado:** exploring  
**Capturado:** 2026-05-10  
**Prioridad:** Planificar — impacto alto, esfuerzo alto  
**Contexto:** El objetivo no es vender el harness — es posicionarlo como el framework detrás de un servicio de consultoría TI que multiplica la velocidad de entrega de proyectos. La documentación debe comunicar el servicio, no la herramienta.

### Iteraciones
- [2026-05-10] Decisión: harness como submodule en `.aura/`. Rules movidas a opt-in (`.aura/rules/`). Mínimo viable = spine + ciclo + hooks + harness-core. Doc acotada sin exponer modelo de negocio. Validado por Opus. Ejecución en dos etapas: docs primero (esta sesión), refactorización de arquitectura como issue separado.

---

## [005] Visibilidad en tiempo real del trabajo del agente
**Estado:** raw
**Capturado:** 2026-05-10
**Prioridad:** Evaluar — impacto medio, esfuerzo alto  
**Contexto:** El usuario no puede ver qué especialista está activo ni el estado interno del agente durante la ejecución. Posible solución: .agent/status.json actualizado en cada paso, visible en el editor.

### Iteraciones
_(sin iterar)_

---

## [006] Timeline de sesiones en resumen de session_start
**Estado:** raw
**Capturado:** 2026-05-10
**Prioridad:** Quick win — impacto bajo, esfuerzo bajo  
**Contexto:** Engram ya tiene mem_timeline con historia cronológica. Integrarla al resumen ejecutivo de session_start como "Últimas N sesiones: [fecha] — [foco]" daría visibilidad inmediata del progreso sin tool calls adicionales.

### Iteraciones
_(sin iterar)_

---

## [007] Protocolo de cierre por límite de contexto
**Estado:** done
**Capturado:** 2026-05-10
**Prioridad:** Hacer — impacto alto, esfuerzo medio  
**Contexto:** A 71% de contexto (141k/200k) con 14.5k libres el autocompact comprime y puede perder nuance. Necesitamos un mecanismo que detecte cuando el contexto supera ~65% y dispare automáticamente el protocolo de cierre de sesión (guardar Engram + current-session.json + avisar al usuario).

### Iteraciones
- [2026-05-14] Alcance refinado: no es cierre de sesión sino checkpoint post-PR. Flujo: después de PR confirmada → mem_session_summary → current-session.json actualizado → si contexto extenso sugerir /compact. Trigger fijo post-PR (no condicional por umbral porque el agente no puede leer tokens directamente). El check preciso del 60% requeriría hook PostToolUse. Evidencia directa en este repo: a 100k+ el agente ignoró reglas workflow y ejecutó push directo a main. Veredicto: GO. Diseño mínimo: nuevo paso en finish-branch + protocolo task-checkpoint.md.

---

## [008] Comando /compact — compresión de contexto mid-session
**Estado:** raw  
**Capturado:** 2026-05-10  
**Prioridad:** Planificar — impacto alto, esfuerzo alto  
**Contexto:** Derivado de evidencia MIT 2025 sobre degradación por ruido. Mid-session: comprimir historial de conversación a resumen estructurado + limpiar tool outputs ya consumidos. Reduce degradación sin cerrar sesión. El documento lo llama "handoffs limpios". Diferente a /clear — no borra, resume.

### Iteraciones
_(sin iterar)_

---

## [009] Verificación antes de guardar en Engram
**Estado:** done  
**Capturado:** 2026-05-10  
**Prioridad:** Quick win — impacto alto, esfuerzo bajo  
**Contexto:** Hoy se guarda a Engram sin verificar que lo que el agente cree que hizo coincide con lo que realmente está en el repo (git log, archivos). Un paso de verificación pre-mem_session_summary: comparar afirmaciones del resumen vs estado real del repo. Evita que Engram acumule memorias falsas o inexactas.

### Iteraciones
- **2026-05-11**: Implementado como Paso 3 de `protocols/session_end.md` (Verificación de Estado GitHub pre-Engram). Consulta PRs mergeadas, PRs abiertas, issues cerrados y issues ready antes de construir `pending_verified`. El hook `session-end.ps1` también fue actualizado con fast-path (`recently_merged_prs`, `recently_closed_issues`). Status: done.

### Iteraciones
_(sin iterar)_

---

## [010] Contenido externo como dato no confiable
**Estado:** raw  
**Capturado:** 2026-05-10  
**Prioridad:** Planificar — impacto alto, esfuerzo alto  
**Contexto:** El harness no distingue entre contexto interno (protocolos, rules) y contenido externo (GitHub issues, PRs, archivos del usuario, outputs de APIs). NCSC y OWASP documentan que LLMs no separan "datos" de "instrucciones" — prompt injection no se elimina, solo se reduce. Necesitamos delimitar, etiquetar y validar todo contenido externo antes de que el agente actúe sobre él.

### Iteraciones
_(sin iterar)_

---

## [011] Testing del harness — retorno y estrategia
**Estado:** raw  
**Capturado:** 2026-05-10  
**Prioridad:** Evaluar — impacto bajo a corto plazo, esfuerzo medio  
**Contexto:** Analizado el costo/beneficio de testear el harness. Tests LLM de comportamiento tienen retorno bajo porque el modelo siempre decide — no generan independencia real. El valor está en tests estáticos (estructura de archivos, schemas JSON) y en hooks PS1 (enforcement mecánico). Tests LLM son observabilidad, no control.

### Iteraciones
- [2026-05-10] PS1 hooks = independencia alta. Tests estáticos = independencia parcial. Tests LLM = solo observabilidad. Plataforma viable: PromptFoo + Haiku (~$0.16/run). Decisión: bajo retorno inmediato, no priorizar ahora.

---

## [012] Detección de ideas duplicadas en /idea skill
**Estado:** raw  
**Capturado:** 2026-05-10  
**Prioridad:** Hacer — impacto alto, esfuerzo medio  
**Contexto:** El flujo actual de /idea no busca similitudes antes de capturar una nueva idea. Sin revisión activa del backlog, es posible registrar la misma idea dos veces con distinta redacción. Necesitamos que /idea haga búsqueda semántica o keyword en ideas.md antes de guardar, y alerte si hay solapamiento probable.

### Iteraciones
_(sin iterar)_

---

## [013] Integración con MCP de Perplexity para búsquedas web
**Estado:** raw  
**Capturado:** 2026-05-14  
**Prioridad:** Planificar — impacto alto, esfuerzo medio  
**Contexto:** (pendiente de exploración)

### Iteraciones
_(sin iterar)_

---

## [015] Cerrar el loop de `agentic-dev-loop`: `changes-requested` no vuelve a `ready`
**Estado:** raw
**Capturado:** 2026-07-30
**Prioridad:** Hacer — impacto alto, esfuerzo medio
**Contexto:** Validando el flujo completo del loop (Preparar → Planificar → Ejecutar → Revisar →
Entregar) contra las fases documentadas en `skills/agentic-dev-loop/SKILL.md` se confirmó un
gap real: dentro de una misma corrida hay un micro-loop de ajuste (`verify.sh` en cada
iteración RED→GREEN) y entre corridas hay un macro-loop de ajuste (issue vuelto a `ready` con
comentario de bloqueo → `resolve-tier.sh` escala el modelo en el próximo intento) — pero el
veredicto negativo de la Fase 2 (Verifier, label `changes-requested`) **no vuelve a alimentar
ese ciclo**. `pick-next-issue.sh` solo mira el label `ready`; nada en el skill ni en los
scripts documenta cómo un issue en `changes-requested` regresa a un segundo intento del
dev-runner. Hoy el loop se detiene ahí y depende de intervención manual. No se aborda en el
spec de `harness-update` (`docs/aura/specs/2026-07-30-harness-self-update.md`) — es un gap de
`agentic-dev-loop` en sí mismo, tema aparte.

### Iteraciones
_(sin iterar)_

---

## [016] Resto del barrido de scripting determinístico del harness (post Tier 1, Issue #66)
**Estado:** done (5/5 — classify-branch.sh PR #72, post-merge.sh PR #75,
apply-branch-protection.sh PR #77, new-branch-for-issue.sh PR #79, git hooks nativos PR #81 —
todo mergeado a develop 2026-08-01)
**Capturado:** 2026-07-31
**Prioridad:** Hacer — impacto alto (volumen de tokens), esfuerzo medio-alto
**Contexto:** Un barrido completo del harness (3 agentes Explore en paralelo, motivado por el
caso real Issues #75/#76 en otro proyecto con este harness — PRs abiertos contra `main` en vez
de `develop`, y contaminación cruzada de working directory entre dev-runners) encontró ~11
candidatos a script bash+gh reutilizable, de los cuales solo los de mayor urgencia (bugs reales
+ incidente de commit directo) se implementaron en Tier 1 (Issue #66). Quedan pendientes, ya
diseñados a nivel de contrato en el plan de esa sesión:
- `skills/repo-integrity/scripts/classify-branch.sh <owner>/<repo> <branch> <issue_n>` — cubre
  los Pasos C+D del algoritmo de detección de `skills/repo-integrity/SKILL.md` (hoy 100% prosa:
  `gh issue view --json state` + `gh pr list --state merged`). Mayor volumen de repetición de
  todo el barrido — corre hasta 10 veces por sesión (una por rama candidata).
- `post-merge.sh <owner>/<repo> <issue> <pr>` — dedupe de prosa casi idéntica duplicada en
  `agents/github.md` ("Al Mergear una PR a Develop") y `protocols/session_end.md` ("Post-merge a
  develop"): verifica `gh pr view --json state,mergedAt` y cierra el issue con el comentario
  estándar.
- `apply-branch-protection.sh <owner>/<repo> <branch>` — encapsula el heredoc JSON de
  `gh api -X PUT .../protection` que hoy el agente reconstruye de memoria (bajo volumen, alto
  riesgo si se arma mal el JSON — es una operación de seguridad real).
- `new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>` — resuelve el prefijo
  correcto (`feature/`, `fix/`, `chore/` desde develop; `hotfix/` desde main) según la tabla que
  hoy solo vive en prosa en `agents/github.md`, para trabajo manual fuera del loop.
- Git hooks nativos (`.githooks/pre-push` + `core.hooksPath`) — segunda capa de enforcement de
  "nunca commit a develop/main" independiente de Claude Code. El barrido confirmó que hoy **no
  existe ningún git hook nativo** en el repo — todo el enforcement depende de que Claude Code
  dispare `.claude/hooks/git-guard.ps1` y que `pwsh` resuelva en el PATH de esa sesión. Evaluado
  y recomendado en el plan de Tier 1, explícitamente dejado fuera de esa tanda por decisión del
  usuario (requiere un paso de setup — `git config core.hooksPath` — que no se auto-aplica al
  clonar, y se prefirió no ampliar el alcance de un PR ya enfocado en bugs reales).

### Iteraciones
_(sin iterar)_

---

## [017] Reporte de sesión anterior + agente especialista en observability al iniciar sesión
**Estado:** planned
**Capturado:** 2026-08-03
**Contexto:** Objetivo amplio: depurar flujos de trabajo, detectar oportunidades de mejora,
capturar errores, y optimizar LLM-vs-script-vs-command priorizando herramientas reusables por
los modelos que ahorren tokens. Nace del gap detectado al revisar PR #101 (observability.md +
complexity-tiering.md): el único mecanismo de captura de consumo hoy (`<usage>` de
task-notification) solo aplica a subagentes delegados, no a sesiones sin delegación.

**Arquitectura acordada (2 fases, para no repetir el timeout O(n) que ya tuvo
`context-guard.ps1` con JSONL grande):**
- Fase A: `session-end.ps1` lee stdin (mismo patrón que `git-guard.ps1`) y appendea
  `transcript_path`+`session_id` a un índice liviano — sin parsear el JSONL en el hook.
- Fase B: paso nuevo en `session_start.md`, sin presión de timeout, procesa las entradas
  pendientes del índice y calcula tokens/tool_uses-por-tipo/duration.
- Persistencia en `.agent/memory/observability/` — **gitignored**, no versionado como
  `current-session.json`, porque validamos en esta misma sesión que ese archivo, siendo
  público, ya filtra patrón de trabajo (horarios, nombres de proyectos privados como
  `crawler-mcp-diagram`) — un histórico de split LLM/script por sesión sería peor.

**Opciones evaluadas:** A (captura+reporte básico) / B (+ tendencia histórica) / C (+ agente
especialista que analiza el histórico acumulado). Se decide arrancar por A — B es casi gratis
una vez que A esté guardando el histórico; C recién rinde con 5-10 sesiones reales acumuladas.

**Extensión pedida por el usuario:** que ofrecer este reporte sea una opción estándar en las
ejecuciones de `/run-dev-loop` (ver `skills/agentic-dev-loop/SKILL.md` Paso 5.5, que ya
guarda consumo en Engram pero solo dentro del loop formal).

### Iteraciones
- [2026-08-04] Exploración completa (PM → Planner → Engineer). Decisión: implementar Opción A
  vía `/run-dev-loop`, 4 issues (captura en hook → script de procesamiento → reporte en
  session_start → oferta del reporte como opción estándar en loops).

---

## [018] Router de flujos determinísticos por tipo de operación
**Estado:** raw
**Capturado:** 2026-08-04
**Prioridad:** Evaluar — impacto alto, esfuerzo alto
**Contexto:** Surgió al diseñar `cut-release.sh` (Issue #136) para resolver el bloqueo de
`git-guard.ps1` al publicar el tag de un release. El usuario cuestionó por qué hacen falta 3
capas de enforcement (branch protection de GitHub, `.githooks/pre-push`, `git-guard.ps1`) si
el agente pudiera simplemente saber qué flujo seguir según el tipo de operación. Conclusión de
la investigación: las 3 capas son la red de seguridad *mientras* no existe una capa 0 que cubra
el 100% de las operaciones sensibles con scripts determinísticos — hoy esa capa existe parcial
y dispersa (`new-branch-for-issue.sh` + `open-pr.sh` para feature work, `cut-release.sh` nuevo
para release, pero cada flujo se descubre por separado leyendo `agents/github.md`).

La idea: un punto único (¿extensión de `protocols/router.md`? ¿un script `resolve-flow.sh`
que reciba "tipo de operación" y devuelva qué script correr?) donde el agente identifique la
naturaleza de la operación que va a hacer y resuelva automáticamente el flujo/script correcto,
en vez de razonar cada vez qué comandos de git/gh componer a mano. Reduciría tokens/razonamiento
(pedido explícito del usuario) y encogería la superficie que las 3 capas de enforcement
necesitan cubrir como red de seguridad.

### Iteraciones
_(sin iterar)_

---

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

---

## [020] Integración de /goal para ejecución autónoma de objetivos multi-issue
**Estado:** refined  
**Capturado:** 2026-05-14  
**Prioridad:** Planificar — impacto alto, esfuerzo alto  
**Contexto:** Claude Code tiene /goal: define una condición de completitud y Claude trabaja autónomamente entre turnos hasta cumplirla (evaluador Haiku post-turn). El objetivo es integrar esto con el harness para que un conjunto de issues ya planificados (vía /plan-work) se ejecuten autónomamente, y al finalizar el humano valide contra los tests y documentación generados que el objetivo fue alcanzado. Ref: https://code.claude.com/docs/en/goal

### Iteraciones
- [2026-05-14] Flujo diseñado en 3 fases: (1) Definición — agent verifica spec + issues ready, construye condición evaluador, presenta plan con opciones [go] / [iterar] / [cancelar]; (2) Ejecución autónoma — auto mode ON, loop por issue (branch → TDD → PR → merge → close), evaluador Haiku post-turn; (3) Validation Gate — auto mode OFF, informe con PRs + tests + docs, humano revisa y aprueba merge manualmente. NO reemplaza flujo semi-auto actual — es modo opt-in activado explícitamente con /goal.
- [2026-09-02] Renumerada de [014] a [020] al resolver conflicto de merge con ideas [015]-[019] llegadas de `origin/develop` (mismo número, contenido distinto — la sesión que las creó nunca sincronizó local). Nota: Issue #30 ("crear spec formal del skill /goal", derivado de esta idea) fue creado y luego cerrado con label `blocked` sin PR asociada — la idea sigue vigente en estado `refined`, pendiente de desbloqueo antes de re-intentar el issue.
