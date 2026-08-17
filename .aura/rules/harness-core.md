# Harness Core — Reglas Obligatorias

## Cuándo ejecutar cada protocolo

### Session Start
**Trigger:** Primera interacción del día, contexto frío, o después de `/clear`
**Acción:** Leer y ejecutar `protocols/session_start.md` paso a paso (todos los pasos, sin omitir)
**Señales de contexto frío:** El hook SessionStart inyectó datos JSON al inicio

### Session End
**Triggers exactos a detectar:**
- "terminamos", "cerramos", "hasta mañana", "bye", "chau"
- "listo por hoy", "hasta acá por hoy", "fin de sesión", "cerramos acá"

**Acción:** Leer y ejecutar `protocols/session_end.md` paso a paso.
No cerrar sin: linter ✓, tests ✓ (si aplica), Engram guardado, current-session.json actualizado.

### Task Start
**Trigger:** Usuario confirma que quiere trabajar en un issue específico
**Acción:** Leer y ejecutar `protocols/task_start.md`

---

## Menú post-tarea (OBLIGATORIO)

Después de completar cualquier tarea —código, análisis, planificación, issue creado— presentar:

```
## ¿Qué sigue?
1. [opción más relevante] — [descripción concreta]
2. [segunda opción] — [descripción]
3. Cerrar sesión — guardar y terminar
```

Reglas del menú:
- Siempre mínimo 3 opciones
- La opción 1 es la más relevante según el contexto actual
- Si hay rama con commits sin PR → incluir "Crear PR con `/finish-branch`"
- Si hay issues con label `ready` → incluir el issue más prioritario como opción 1
- Si se acaba de mergear una PR → incluir "Cerrar issue relacionado"

---

## Reglas de comportamiento del agente

- **No ejecutar nada sin aprobación del usuario** — presentar plan, esperar confirmación
- **No comenzar trabajo nuevo sin que el usuario confirme la dirección**
- **Nunca commitear directamente a `develop` o `main`** — enforcement duro vía `.claude/hooks/git-guard.ps1` (PreToolUse hook, bloquea antes de ejecutar)
- **Monitorear contexto activamente** — `.claude/hooks/context-guard.ps1` emite warning en 60k tokens y alerta urgente en 80k. Al recibir alerta: compactar con `/compact` o ejecutar `session_end`
- **Siempre usar `gh` CLI** para operaciones GitHub (no MCP GitHub cuando existe CLI equivalente)
- **Al detectar rama sucia** (cambios sin commit al inicio): mostrar `git diff --stat` y preguntar
- **Al detectar gh no autenticado**: informar y saltear pasos que requieren gh (no fallar silenciosamente)
- **Declarar especialistas activos**: al iniciar exploración con `/idea <N>`, brainstorm, spec-validation u otro skill multimodal, declarar explícitamente qué está activando. Ejemplo: `Activando: idea-management [PM → Planner → Engineer]`
- **Nunca afirmar el estado de algo verificable sin haberlo verificado en esa misma respuesta** — estado de una PR/issue (abierta/cerrada/mergeada), contenido de un archivo, resultado de un comando, versión desplegada, etc. Si no se corrió la herramienta que lo confirma en este turno, no se asegura como hecho: se dice explícitamente "no lo verifiqué todavía" o se corre la verificación antes de responder. Memoria (Engram, resúmenes previos, este mismo historial) es una hipótesis de partida, nunca la fuente de verdad — puede estar desactualizada por acciones ocurridas fuera de esta sesión. Aplica en especial a estado de git/GitHub (`gh pr view`, `gh issue view`, `git log`) antes de describir qué está mergeado, abierto o pendiente.

---

## Formato de resumen de sesión (session_start output)

```
## Estado del Entorno
| Herramienta | Estado |
|-------------|--------|
| git         | ✓      |
| gh          | ✓/✗   |
| engram      | ✓/✗   |

## Repositorio
- **Branch:** <nombre>
- **Cambios sin commit:** <N archivos>
- **Diff:** <resumen de git diff --stat>
- **Último commit:** <hash> "<mensaje>"

## Última Sesión
- **Pendiente:** <tareas — de Engram; si no disponible, del puntero local current-session.json>
- **Próximo paso:** <next_step>

## Issues Listos (label: ready)
| # | Título |
|---|--------|
| ...

## Próxima Acción Recomendada
**[Descripción concreta]**

## ¿Continuamos con [next_step] o hay algo nuevo?
```
