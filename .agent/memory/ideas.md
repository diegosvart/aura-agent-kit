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
