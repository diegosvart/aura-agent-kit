# Aura Agent Kit — Entry Point (submodule)

> Este archivo es el entry point del harness cuando está instalado como submodule en `.aura/`.
> Carga el scope mínimo viable. Todo lo demás es opt-in desde `.aura/rules/`.

---

## OBLIGATORIO: Al iniciar cada sesión

Leer y ejecutar **paso a paso** `@.aura/protocols/session_start.md`.

No omitir ningún paso. Ejecutar en orden:
1. Leer contexto (AGENTS.md, current-session.json si existe)
2. Estado del entorno (git, gh, engram)
3. Salud de ramas
4. Issues listos (gh issue list --label ready)
5. Memoria Engram (mem_context)
6. Presentar resumen ejecutivo formateado
7. Preguntar: "¿Continuamos con [next_step] o hay algo nuevo?"

---

## OBLIGATORIO: Al cerrar sesión

Detectar triggers: **"terminamos", "cerramos", "hasta mañana", "bye", "chau", "listo por hoy", "hasta acá por hoy"**

Al detectar cualquiera → leer y ejecutar **paso a paso** `@.aura/protocols/session_end.md`.

---

## OBLIGATORIO: Después de cada tarea completada

Presentar el menú de routing según `@.aura/protocols/router.md`.

---

## OBLIGATORIO: Para trabajo nuevo sin spec previa

Si el usuario describe trabajo nuevo sin spec existente:
→ Preguntar: "¿Tenés un diseño o spec previo?"
  - Sí → Continuar con `/plan-work`
  - No → Recomendar `/brainstorm` antes de planificar

---

## Identidad y Pilares

@.aura/AGENTS.md

---

## Router de Contexto

@.aura/protocols/router.md

---

## Reglas del Harness (scope mínimo)

@.aura/rules/harness-core.md

---

## Reglas Opcionales (opt-in — descomentar las que quieras activar)

<!-- @.aura/rules/design-flow.md -->
<!-- @.aura/rules/repo-integrity.md -->
<!-- @.aura/rules/routing-menu.md -->
<!-- @.aura/rules/coding.md -->

---

## MCP Requerido

Engram para memoria persistente (P5). Ver `.aura/integrations/claude-code/CLAUDE.md`.
