# Observabilidad — Acceso a Datos de Uso/Tokens y Métrica de Esfuerzo

> **Propósito:** documentar dónde vive el dato real de consumo (tokens, tool calls,
> duración) de una sesión de Claude Code, y qué métrica usar para medir esfuerzo/trabajo de
> forma objetiva — para evaluar el desempeño del harness (¿un cambio de skill/protocolo
> redujo el costo real de una tarea repetida?), no solo su resultado cualitativo.
> **Origen:** investigación puntual en `crawler-mcp-diagram` (2026-08-03), documentada acá
> porque aplica a cualquier proyecto que use este harness, no solo a ese repo.

---

## Las 4 capas de acceso al dato

| Capa | Qué da | Cómo acceder | Cuándo usarla |
|---|---|---|---|
| **`/usage`** (comando interactivo) | % de límite de plan consumido, breakdown por subagent-type y por MCP server, ventana de 24h | Solo TUI — **sin flag de exportación a JSON documentado** | Chequeo rápido manual, no para análisis programático |
| **JSONL crudo por sesión** | `usage.input_tokens` / `output_tokens` / `cache_creation_input_tokens` / `cache_read_input_tokens` por mensaje, más el modelo usado | `~/.claude/projects/<proyecto>/<sessionId>.jsonl` — requiere parseo manual (jq/python) | Análisis retrospectivo puntual de una sesión específica |
| **OpenTelemetry (oficial)** | Métricas `claude_code.token.usage` y `claude_code.cost.usage`, exportables a cualquier colector OTLP (Prometheus, Grafana, etc.) | `CLAUDE_CODE_ENABLE_TELEMETRY=1` + `OTEL_METRICS_EXPORTER=otlp` (o `prometheus`/`console`) vía variables de entorno o `settings.json` → `env`. Ver `code.claude.com/docs/en/monitoring-usage.md` | **Ruta oficial** para dashboards/alertas/análisis agregado continuo |
| **`<usage>` de `task-notification`** | `subagent_tokens`, `tool_uses`, `duration_ms` por agente lanzado dentro de la sesión actual | Ya viene en cada notificación de finalización de un agente — no requiere configuración | Medir el costo de **una tarea/issue específico** dentro de una orquestación, sin salir de la sesión |

`~/.claude/stats-cache.json` existe pero solo trae actividad diaria agregada
(`messageCount`/`sessionCount`/`toolCallCount`) — **no trae tokens**, no sirve para esto.

**No hay** (a la fecha de esta investigación) una herramienta community/oficial documentada
tipo "ccusage" mencionada en la documentación de Claude Code — la ruta oficial para consumo
programático es OTEL.

---

## Métrica de esfuerzo recomendada

Tokens totales por sí solos son un proxy ruidoso: `cache_read_input_tokens` puede dominar el
total sin reflejar trabajo nuevo (es contexto reusado desde cache, no razonamiento nuevo).

**Recomendación: métrica compuesta de 3 ejes, no un solo número:**

1. **`output_tokens`** (o `subagent_tokens` si se usa el dato de `task-notification`, que ya
   es un agregado razonable) — proxy principal de "cuánto generó" el agente.
2. **`tool_uses`** — proxy de cuántas acciones reales tomó (lecturas, ediciones, comandos).
   Dos tareas con tokens similares pero `tool_uses` muy distinto probablemente tienen
   complejidad real distinta.
3. **`duration_ms`** — desempate terciario, útil para detectar tareas que se estancaron
   (duración alta con tokens/tool_uses bajos = señal de bloqueo, no de trabajo).

**Uso concreto:** al comparar "¿este cambio de skill redujo el costo de esta tarea
repetida?", comparar los 3 ejes antes/después — no solo el total de tokens. Ver
`agents/complexity-tiering.md` para cómo esto informa la elección de tier de modelo.

---

## Dónde va la evidencia de cada caso real

Este doc es referencia estable — no un log. **No agregar acá números de sesiones
concretas.** La evidencia de un caso real (tokens/tool_uses/duration de un bloque de
trabajo específico) va en el `docs/aura/experiments/` del proyecto que la generó (local,
gitignored por diseño — ver `skills/auto-research/SKILL.md`), no en este archivo
compartido entre todos los proyectos que consumen el harness. Ejemplo de ese patrón:
`crawler-mcp-diagram` documentó su propio caso (bloque de 11 issues Cash Flow,
2026-08-03) en `docs/aura/experiments/2026-08-04-tiering-fuera-del-loop.md` de ese repo,
no acá.
