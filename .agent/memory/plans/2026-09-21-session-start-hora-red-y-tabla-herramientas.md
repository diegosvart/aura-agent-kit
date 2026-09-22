---
status: done
pr: "#339"
completed_at: "2026-09-22T15:51:24Z"
---
# Plan — Session Start/End: hora de red verificada, timezone de visualización y tabla de herramientas

**Spec:** `docs/aura/specs/2026-09-21-session-start-hora-red-y-tabla-herramientas-design.md`

## Contexto

Aprobado por el usuario en sesión 2026-09-21. Tres gaps del Resumen Ejecutivo de
`session_start.md`: (1) sin timestamp de red verificado, (2) sin visibilidad de hora de cierre
de la sesión anterior, (3) sin inventario de herramientas MCP/hooks configuradas vs. cargadas
en contexto. Incluye también timezone de visualización (`America/Santiago`, ya configurado en
`AGENTS.local.md`) sobre almacenamiento canónico en UTC.

## Pasos

### Paso 1 — Hora de red en `session_start.md`
- **Qué:** Agregar ítem 2.5 al Paso 0 (consulta `WebFetch` a API de tiempo, fallback a reloj
  local con aviso explícito). Agregar filas "Sesión anterior cerrada (UTC, hora de red)" y
  "Extraído ahora (UTC, hora de red)" a la tabla "1. Continuidad" del Paso 4, cada una con
  conversión a `Timezone (IANA)` de `AGENTS.local.md` (o aviso de fallback si el campo no
  existe).
- **Archivos:** `protocols/session_start.md`
- **Seguridad:** ninguna — cambio de documentación de protocolo, sin código ejecutable nuevo
- **Despacho:** INLINE (edición de un solo archivo markdown, bajo volumen de tool-calls, depende
  del texto exacto ya acordado en la spec — no amerita aislar contexto)

### Paso 2 — Tabla de herramientas en `session_start.md`
- **Qué:** Reemplazar la fila `git/gh/engram: ✓/✗` de "2. Estado real — mío" (Paso 4) por las
  dos tablas "Herramientas MCP" y "Hooks activos" descritas en la spec (Diseño, punto 4).
- **Archivos:** `protocols/session_start.md`
- **Seguridad:** ninguna
- **Despacho:** INLINE (mismo archivo que Paso 1, conviene resolver en la misma pasada de edición)

### Paso 3 — Hora de red en `session_end.md`
- **Qué:** Agregar la misma consulta `WebFetch` (con fallback) al Paso 1. Agregar línea
  `Cierre (UTC, hora de red): {{session_end_utc}}` al contenido de `mem_session_summary` (Paso
  4). Cambiar la fuente del campo `last_updated` de `current-session.json` (Paso 5) de reloj
  local a `session_end_utc` — sin agregar campo nuevo, se reutiliza el existente.
- **Archivos:** `protocols/session_end.md`
- **Seguridad:** ninguna
- **Despacho:** INLINE (mismo criterio que Pasos 1-2 — documento de protocolo, bajo volumen)

### Paso 4 — Verificación en vivo
- **Qué:** En la próxima sesión real, confirmar que el Resumen Ejecutivo (Paso 4 de
  `session_start.md`) muestra las 4 piezas nuevas (hora de red al inicio, hora de cierre de la
  sesión anterior, tabla de herramientas, conversión a timezone local) sin que el usuario tenga
  que pedirlo — criterio observable de la hipótesis P4 de la spec.
- **Archivos:** ninguno (verificación, no edición)
- **Seguridad:** ninguna
- **Despacho:** INLINE (parte del flujo normal de `session_start.md`, no una tarea aislable)
