# Comando — /session-report

> **Invoca:** `skills/observability/SKILL.md` (Modo 2 — bajo demanda agregado) →
> `skills/observability/scripts/session-report.sh`
> **Cuándo usar:** Para un informe agregado sobre `.agent/memory/observability/sessions.jsonl`
> — `delegation_rate` acumulado, tendencias de tokens/duración y distribución de `tool_uses` —
> en vez de leer el archivo a mano. Nunca se ejecuta automáticamente (ver
> `skills/observability/SKILL.md` → "Cuándo Activar").

---

## Uso

```
/session-report                              # todas las filas de sessions.jsonl
/session-report --since 2026-09-10            # desde una fecha ISO
/session-report --since-session <session_id>  # desde una sesión puntual (inclusive)
```

`--since` y `--since-session` son mutuamente excluyentes.

---

## Qué Hace

1. Corre `skills/observability/scripts/session-report.sh` con los flags pasados.
2. El script imprime el informe a stdout: `delegation_rate` agregado (con aviso explícito de
   "muestra insuficiente" si aplica), promedio/mediana de `output_tokens`/`duration_ms` vs. el
   rango anterior de igual tamaño, distribución de `tool_uses` como proporciones, y una
   sección "Conclusiones" en prosa.
3. **Después de mostrar el informe**, guardar la sección "Conclusiones" en Engram con
   `mem_save` (`topic_key: harness/session-behavior-report`) — responsabilidad de quien
   invoca el comando, no del script (Engram es un tool MCP, no invocable desde bash).

---

## Cuándo Usar

Solo bajo demanda — nunca automático en `session_start` (mismo criterio de cautela que
`/evaluate-sessions` aplica a `flow-conformance-check`, ver `agents/evaluator.md`).

Caso de uso típico: verificar si el criterio de cierre del Issue #231
(`delegation_rate >= 25%` en `>= 5` sesiones) se cumple en un rango de sesiones posteriores a
un merge puntual.
