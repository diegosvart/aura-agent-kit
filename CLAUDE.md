# Aura Agent Kit — Claude Code Entry Point

> Este archivo es cargado automáticamente por Claude Code al iniciar en este proyecto.
> El harness completo vive en `AGENTS.md`. Este archivo activa los protocolos.

---

## OBLIGATORIO: Al iniciar cada sesión

Leer y ejecutar **paso a paso** `@protocols/session_start.md`.

No omitir ningún paso. No resumir. Ejecutar en orden:
1. Leer contexto (AGENTS.md, current-session.json si existe)
2. Estado del entorno (git, gh, engram)
3. Salud de ramas
4. Issues listos (gh issue list --label ready)
5. Memoria Engram (mem_context)
6. Presentar resumen ejecutivo formateado
7. Preguntar: "¿Continuamos con [next_step] o hay algo nuevo?"

---

## OBLIGATORIO: Al cerrar sesión

Detectar triggers de cierre: **"terminamos", "cerramos", "hasta mañana", "bye", "chau", "listo por hoy", "hasta acá por hoy"**

Al detectar cualquiera → leer y ejecutar **paso a paso** `@protocols/session_end.md`.

---

## OBLIGATORIO: Después de cada tarea completada

Presentar el menú de routing según `@protocols/router.md`.

Formato mínimo:
```
## ¿Qué sigue?
1. [opción más relevante según contexto]
2. Nueva tarea — /plan-work
3. Cerrar sesión
```

---

## OBLIGATORIO: Para trabajo nuevo sin spec previa

Si el usuario describe trabajo nuevo sin spec existente:
→ Preguntar: "¿Tenés un diseño o spec previo?"
  - Sí → Continuar con `/plan-work`
  - No → Recomendar `/brainstorm` antes de planificar

---

## Identidad y Pilares

@AGENTS.local.md
@AGENTS.md

---

## Router de Contexto

@protocols/router.md

---

## Configuración de Permisos

Ver `.claude/settings.json`.

## MCP Requerido

Engram para memoria persistente (P5). Ver `integrations/claude-code/CLAUDE.md` para instrucciones de instalación.
