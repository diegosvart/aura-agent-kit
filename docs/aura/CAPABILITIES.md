# Manifiesto Vivo de Capacidades

> Generado automáticamente por `agents/doc-guardian.md` (sección 8) en cada
> `/doc-check --all`, vía `Glob` sobre `agents/*.md`, `skills/*/SKILL.md`,
> `commands/*.md` y `protocols/*.md`. No editar a mano — se regenera y se
> pisa en la próxima corrida.
>
> Fecha de esta generación: 2026-09-06

| Tipo | Nombre | Ruta | Descripción |
|------|--------|------|-------------|
| Agente | Browser Control | `agents/browser-control.md` | Dar al agente visión y control de un navegador real (vía |
| Agente | Browser Testing | `agents/browser-testing.md` | Validar programáticamente que una app web funciona — sin supervisión |
| Agente | Challenger | `agents/challenger.md` | Cuestionar specs y planes antes de persistirlos. Actúa como abogado del diablo — no para bloquear, sino para fortalecer. |
| Agente | Tiering de Modelo por Complejidad de Tarea | `agents/complexity-tiering.md` | Elegir el tier de modelo (Haiku/Sonnet/Opus) antes de lanzar un agente, |
| Agente | Doc Guardian | `agents/doc-guardian.md` | Verificar la integridad documental del repo. Detecta referencias rotas, inconsistencias de versión y estructura incompleta en archivos Markdown. |
| Agente | Evaluator | `agents/evaluator.md` | Cuestionar sesiones **ya ocurridas** — a diferencia de `challenger`, que |
| Agente | GitHub — Ramas, Issues, PRs, Merge | `agents/github.md` | Gestionar toda la operativa de Git y GitHub para mantener el flujo de trabajo ordenado. |
| Agente | Infra — Docker, CI/CD, Environments, Secrets | `agents/infra.md` | Gestionar la infraestructura del proyecto: contenedores, pipelines de CI/CD, entornos y gestión de secretos. |
| Agente | Language — Stack del Proyecto | `agents/language.md` | Ser el experto en la tecnología del proyecto, ejecutando código, entendiendo el dominio y aplicando las mejores prácticas del stack. |
| Agente | Plan Reporter | `agents/plan-reporter.md` | Ejecutar `skills/plan-reporting/SKILL.md` en contexto aislado — genera un |
| Agente | Reviewer — Tests, Arquitectura, Calidad | `agents/reviewer.md` | Revisar código antes de merges, garantizar calidad, validar arquitectura y tests. |
| Skill | agentic-dev-loop | `skills/agentic-dev-loop/SKILL.md` | Ejecuta issues con label ready usando agentes, separando desarrollo (no supervisado) de verificación (nunca mergea sola). Usar al correr /run-dev-loop. |
| Skill | auto-research | `skills/auto-research/SKILL.md` | Formaliza la mejora continua del harness con hipótesis documentadas. Usar cuando se detecta fricción repetida, un workaround recurrente, una pregunta que se repite entre sesiones, un paso de protocolo que se saltea sistemáticamente, o una inconsistencia entre skills/protocolos. |
| Skill | brainstorming | `skills/brainstorming/SKILL.md` | Use before any creative work - creating features, building components, or modifying behavior. |
| Skill | e2e-testing | `skills/e2e-testing/SKILL.md` | Ejecuta un smoke test / flujo E2E headless contra una app web vía agent-browser, sin supervisión humana. Usar para validar un flujo crítico tras implementar un issue con impacto en UI, o capturar regresión visual. |
| Skill | finishing-a-development-branch | `skills/finishing-a-development-branch/SKILL.md` | Use when all tasks in a branch are complete and you're ready to close the work |
| Skill | harness-update | `skills/harness-update/SKILL.md` | Detect and apply updates to the harness submodule |
| Skill | idea-management | `skills/idea-management/SKILL.md` | Captura, madura y promueve objetivos de alto nivel a través de un ciclo de vida estructurado. Usar cuando el usuario quiere registrar una idea, explorarla, o promoverla a planificación. |
| Skill | issue-planning | `skills/issue-planning/SKILL.md` | Refina el requerimiento del usuario y lo convierte en uno o varios issues de GitHub listos para trabajar. Usar cuando el usuario describe trabajo nuevo o quiere planificar. |
| Skill | observability | `skills/observability/SKILL.md` | Procesa el índice de sesiones (sessions-index.jsonl) y calcula métricas por sesión — output_tokens, tool_uses por categoría, duration_ms y delegation_rate (Issue #179). Invocada automáticamente desde el Paso 5.5 de protocols/session_start.md; no requiere invocación manual normalmente. |
| Skill | plan-reporting | `skills/plan-reporting/SKILL.md` | Genera reporte de gestión, tareas accionables y análisis de riesgo de un plan estratégico. Usar cuando el usuario pide un reporte de estado de un plan. |
| Skill | repo-integrity | `skills/repo-integrity/SKILL.md` | Detecta trabajo stranded (issue cerrado sin PR mergeada) y ramas que requieren limpieza. Invocada desde el Paso 3 de session_start. |
| Skill | requesting-code-review | `skills/requesting-code-review/SKILL.md` | Use after completing significant implementation work, before merging or moving forward |
| Skill | session-trace | `skills/session-trace/SKILL.md` | Genera una traza cualitativa del comportamiento real de una sesión (no del flujo diseñado en router.md, sino de lo que efectivamente pasó) como diagrama Archify autoreado por el agente. Usar al cerrar sesión, cuando hubo fricción, decisiones no obvias, o desvíos del protocolo que valga la pena poder revisar visualmente después. |
| Skill | spec-validation | `skills/spec-validation/SKILL.md` | Valida técnicamente que una spec es implementable antes de pasarla al challenger. Usar después de aprobar el diseño en /brainstorm, antes de invocar challenger. HARD-GATE para /write-plan. |
| Skill | stack-selection | `skills/stack-selection/SKILL.md` | Detecta o selecciona el stack tecnológico de la sesión y lo persiste en session-stack.json. Usar al iniciar sesión sin stack detectado, o al invocar /stack. |
| Skill | systematic-debugging | `skills/systematic-debugging/SKILL.md` | Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes |
| Skill | test-driven-development | `skills/test-driven-development/SKILL.md` | Use when implementing any feature or bugfix, before writing implementation code |
| Skill | writing-plans | `skills/writing-plans/SKILL.md` | Use when you have a spec or requirements for a multi-step task, before touching code |
| Comando | /auto-research | `commands/auto-research.md` | Cuando se detecta fricción, patrón repetitivo o ineficiencia en el flujo del harness. |
| Comando | /brainstorm | `commands/brainstorm.md` | Inicia el proceso de diseño colaborativo antes de cualquier trabajo creativo. |
| Comando | /doc-check | `commands/doc-check.md` | Después de crear o modificar archivos `.md`, o para verificar integridad general del repo. |
| Comando | /evaluate-sessions | `commands/evaluate-sessions.md` | Para auditar si una sesión (o un rango de sesiones recientes) respetó el |
| Comando | /execute-plan | `commands/execute-plan.md` | Ejecuta un plan de implementación tarea por tarea. |
| Comando | /finish-branch | `commands/finish-branch.md` | Cuando la rama tiene trabajo listo para crear una PR o cerrar. |
| Comando | /harness-update | `commands/harness-update.md` | Para actualizar el harness a la versión más reciente disponible. |
| Comando | /idea | `commands/idea.md` | (sin línea de propósito bajo el título — ver `## Sintaxis`: captura, lista, exploración y promoción de objetivos) |
| Comando | /plan-report | `commands/plan-report.md` | Para generar un reporte de gestión de un plan estratégico — tareas accionables, análisis de riesgo, sugerencias de bucket. |
| Comando | /plan-work | `commands/plan-work.md` | Cuando el usuario describe trabajo nuevo y quiere convertirlo en issues de GitHub listos para trabajar. |
| Comando | /request-review | `commands/request-review.md` | Antes de crear una PR o cuando una PR ya está abierta y lista para revisión. |
| Comando | /run-dev-loop | `commands/run-dev-loop.md` | Para disparar una pasada del loop de desarrollo + verificación de issues (manual o desde una corrida programada). |
| Comando | /stack | `commands/stack.md` | Seleccionar o cambiar el stack tecnológico de la sesión actual. |
| Comando | /write-plan | `commands/write-plan.md` | Crea un plan de implementación detallado a partir de una spec aprobada. |
| Protocolo | Router de Contexto | `protocols/router.md` | Determinar qué archivos cargar según la situación actual. Permite que AGENTS.md sea un spine liviano sin perder cobertura. |
| Protocolo | Session End | `protocols/session_end.md` | Al cerrar cada sesión de trabajo. |
| Protocolo | Session Start | `protocols/session_start.md` | Al inicio de cada sesión de trabajo. |
| Protocolo | Task Checkpoint | `protocols/task-checkpoint.md` | Preservar el estado relevante de la tarea completada antes de que la degradación de contexto afecte el workflow en sesiones largas. |
| Protocolo | Task Start | `protocols/task_start.md` | Al comenzar a trabajar en una tarea/issue específica. |

## Notas de esta generación

- `agents/plan-reporter.md` y `skills/observability/SKILL.md` (ambos creados en esta sesión
  para resolver referencias colgantes detectadas en la corrida anterior de `/doc-check --all`)
  ya aparecen en la tabla — la corrida anterior los excluía porque no existían.
- `commands/idea.md` no tiene una línea de propósito bajo el título (`> **Propósito:**`,
  `> **Qué hace:**` o `> **Cuándo usar:**`) como las demás — la descripción de esta fila es
  un fallback derivado del contenido, no una extracción literal.
- Varias descripciones de agentes/comandos están cortadas en la primera línea del bloque
  `> **Propósito:**`/`> **Cuándo usar:**` porque ese bloque continúa en una segunda línea
  en el archivo fuente (extracción literal de "primera línea bajo el título", tal como
  especifica `agents/doc-guardian.md` sección 8).
