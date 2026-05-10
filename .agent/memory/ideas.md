# Ideas Backlog

> Parking de ideas sin detallar. Para convertir en tarea usar `/plan-work`.
> Formato: `## [YYYY-MM-DD] Título` + una línea de contexto.

---

## [2026-05-09] Verificar hooks PS1 en Claude Code desktop
Contexto: surgió al completar PR #14; los hooks se implementaron pero no se validó su ejecución en el cliente desktop de Claude Code vs CLI.

## [2026-05-09] Skill /auto-research activable desde session_end
Contexto: fricción detectada al cerrar sesión — si hay patrones repetitivos o fricción acumulada, debería sugerirse /auto-research automáticamente sin que el usuario lo pida.

## [2026-05-09] session-end hook + integración directa con Engram
Contexto: el hook session-end podría llamar mem_session_summary directamente vía CLI engram en lugar de depender de que el agente lo recuerde al cerrar.
