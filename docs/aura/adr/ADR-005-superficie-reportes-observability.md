---
adr: 005
title: Exponer reportes de observability en session_start y al cerrar el loop
date: 2026-08-04
status: accepted
area: harness
---

# ADR-005: Exponer reportes de observability en session_start y al cerrar el loop

## Problema

El mecanismo de observability de sesiones (Issues #103/#104) captura y agrega métricas
(`output_tokens`, `tool_uses` por tipo, `duration_ms`) en
`.agent/memory/observability/sessions.jsonl`, pero no había ningún punto del harness que
mostrara esos datos al usuario — el histórico quedaba acumulado sin superficie visible.

## Contexto

Issues #105 y #106 (dependientes de #104, ya resuelto vía PR #108) piden dos puntos de
exposición distintos:
- #105: un resumen compacto de la sesión anterior al iniciar una nueva sesión.
- #106: una opción de menú para ver el consumo de una corrida completa de
  `/run-dev-loop` (múltiples sesiones/issues).

## Decisión

- `protocols/session_start.md`, nuevo **Paso 5.5** (entre `mem_context` y el Resumen
  Ejecutivo): corre `process-session.sh` y muestra tokens/tool_uses/duration de la última
  entrada de `sessions.jsonl`. **Fail-open**: sin `.aura/`, con el script fallando, o sin
  datos, se omite en silencio — no bloquea el resto del protocolo (mismo principio que el
  resto de bloques opcionales del protocolo, ej. ideas en backlog).
- `.aura/rules/routing-menu.md`, nueva sección "Si acaba de terminar una corrida de
  `/run-dev-loop`" con la opción "Ver reporte de consumo de esta corrida".
- `skills/agentic-dev-loop/SKILL.md`, Paso 5.5 (registro de consumo): se agrega una nota
  que referencia el mecanismo automático como complemento del registro manual en Engram —
  no lo reemplaza, porque Engram registra por *issue* (decisión editorial del agente) y
  `sessions.jsonl` registra por *sesión* (mecánico, sin intervención).

## Alternativas descartadas

- **Reemplazar el registro manual en Engram por el mecanismo automático** — descartado:
  Engram captura contexto cualitativo (qué se decidió, por qué) que `sessions.jsonl` no
  tiene; son complementarios, no sustitutos.
- **Un solo punto de exposición (solo el menú post-loop)** — descartado: el caso de uso de
  #105 (sesión anterior fuera del loop, ej. trabajo manual/ad-hoc) no queda cubierto por el
  menú post-loop, que solo dispara al terminar `/run-dev-loop`.

## Consecuencias

- Dos superficies nuevas y pequeñas (un paso de protocolo, una entrada de menú) reusan
  infraestructura ya existente (`process-session.sh`, `sessions.jsonl`) — sin scripts ni
  archivos nuevos.
- El fail-open del Paso 5.5 significa que un repo sin `.aura/` (o sin sesiones previas
  registradas) no ve ninguna diferencia — no rompe el protocolo en proyectos que no usan
  observability.

## Archivos afectados

- `protocols/session_start.md` — nuevo Paso 5.5.
- `.aura/rules/routing-menu.md` — nueva sección de menú post-loop.
- `skills/agentic-dev-loop/SKILL.md` — nota en Paso 5.5 (Fase 1).
