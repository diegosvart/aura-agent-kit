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
**Estado:** refined
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
