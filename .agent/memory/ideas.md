# Ideas Backlog

> Parking de objetivos e ideas sin detallar. Para iterar usar `/idea <N>`. Para convertir en tarea usar `/idea promote <N>`.
> Formato: ID secuencial, estado, contexto, iteraciones.

---

## [001] Verificar hooks PS1 en Claude Code desktop
**Estado:** raw  
**Capturado:** 2026-05-09  
**Contexto:** Surgió al completar PR #14; los hooks se implementaron y probaron en CLI pero no se validó su ejecución en el cliente desktop de Claude Code.

### Iteraciones
_(sin iterar)_

---

## [002] Skill /auto-research activable desde session_end
**Estado:** raw  
**Capturado:** 2026-05-09  
**Contexto:** Fricción detectada al cerrar sesión — si hay patrones repetitivos acumulados, debería sugerirse /auto-research automáticamente sin que el usuario lo pida.

### Iteraciones
_(sin iterar)_

---

## [003] session-end hook + integración directa con Engram
**Estado:** raw  
**Capturado:** 2026-05-09  
**Contexto:** El hook session-end podría llamar mem_session_summary directamente vía CLI engram en lugar de depender de que el agente lo recuerde al cerrar.

### Iteraciones
_(sin iterar)_

---

## [004] Documentación formal del Harness como servicio de consultoría TI
**Estado:** exploring  
**Capturado:** 2026-05-10  
**Contexto:** El objetivo no es vender el harness — es posicionarlo como el framework detrás de un servicio de consultoría TI que multiplica la velocidad de entrega de proyectos. La documentación debe comunicar el servicio, no la herramienta.

### Iteraciones
- [2026-05-10] Decisión: harness como submodule en `.aura/`. Rules movidas a opt-in (`.aura/rules/`). Mínimo viable = spine + ciclo + hooks + harness-core. Doc acotada sin exponer modelo de negocio. Validado por Opus. Ejecución en dos etapas: docs primero (esta sesión), refactorización de arquitectura como issue separado.

---

## [005] Visibilidad en tiempo real del trabajo del agente
**Estado:** raw
**Capturado:** 2026-05-10
**Contexto:** El usuario no puede ver qué especialista está activo ni el estado interno del agente durante la ejecución. Posible solución: .agent/status.json actualizado en cada paso, visible en el editor.

### Iteraciones
_(sin iterar)_

---

## [006] Timeline de sesiones en resumen de session_start
**Estado:** raw
**Capturado:** 2026-05-10
**Contexto:** Engram ya tiene mem_timeline con historia cronológica. Integrarla al resumen ejecutivo de session_start como "Últimas N sesiones: [fecha] — [foco]" daría visibilidad inmediata del progreso sin tool calls adicionales.

### Iteraciones
_(sin iterar)_

---

## [007] Protocolo de cierre por límite de contexto
**Estado:** raw
**Capturado:** 2026-05-10
**Contexto:** A 71% de contexto (141k/200k) con 14.5k libres el autocompact comprime y puede perder nuance. Necesitamos un mecanismo que detecte cuando el contexto supera ~65% y dispare automáticamente el protocolo de cierre de sesión (guardar Engram + current-session.json + avisar al usuario).

### Iteraciones
_(sin iterar)_
