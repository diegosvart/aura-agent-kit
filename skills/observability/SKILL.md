---
name: observability
description: Procesa el índice de sesiones (sessions-index.jsonl) y calcula métricas por sesión — output_tokens, tool_uses por categoría, duration_ms y delegation_rate (Issue #179). Invocada automáticamente desde el Paso 5.5 de protocols/session_start.md; no requiere invocación manual normalmente.
---

# Skill — Observability

> **Script:** `skills/observability/scripts/process-session.sh`
> **Invocado por:** `protocols/session_start.md` Paso 5.5 (fail-open, silencioso si no hay
> datos), como reporte de la sesión anterior antes del Resumen Ejecutivo.

---

## Cuándo Activar

- Automáticamente, en cada `session_start` (Paso 5.5) — nunca bloquea el resto del protocolo
  si falla, no existe `.aura/` (proyecto sin observability habilitada), o no hay datos
  nuevos.
- Bajo demanda, si el usuario pide explícitamente inspeccionar métricas de sesiones pasadas
  (tokens, `tool_uses`, `delegation_rate`) fuera del flujo automático de `session_start`.

---

## Proceso

```
skills/observability/scripts/process-session.sh
    ↓
Lee .agent/memory/observability/sessions-index.jsonl (una entrada por sesión cerrada:
session_id, transcript_path, ended_at)
    ↓
Por cada entrada NO procesada todavía (session_id ausente en sessions.jsonl):
    ├── Parsea el transcript JSONL completo
    ├── Calcula output_tokens (suma de message.usage.output_tokens, mensajes assistant)
    ├── Clasifica tool_uses: llm (Edit/Write/Read) / script_command (Bash/PowerShell) /
    │   agent_delegated (Agent) / other
    ├── Calcula duration_ms (diferencia entre primer y último timestamp ISO)
    └── Calcula delegation_rate {a, b, rate} — ver .aura/rules/subagent-dispatch.md:
        a = triggers de protocols/router.md detectados por keyword-matching (≥2 keywords
            específicos co-ocurriendo, excluye bloques de contexto inyectado por el sistema
            para no matchear router.md contra sí mismo)
        b = invocaciones del Agent tool con tool_uses > 3 en su notificación de finalización
            (deduplicadas por task-id)
        rate = b/a, o null si a == 0
    ↓
Appendea el resultado a .agent/memory/observability/sessions.jsonl (idempotente — nunca
reprocesa un session_id ya presente)
```

`protocols/session_start.md` Paso 5.5 lee la **última línea** de `sessions.jsonl` tras correr
el script y muestra un bloque compacto ("Sesión Anterior") antes del Resumen Ejecutivo:
tokens de salida, `tool_uses` por categoría, duración, y la línea de `delegation_rate` con el
formato exacto que especifica `.aura/rules/subagent-dispatch.md` (`b/a (rate)` si `a > 0`,
o la línea explícita de "sin triggers detectados" si `a == 0` — nunca dividir por cero).

---

## Reglas

1. **Fail-open siempre** — un fallo del script, la ausencia de `.aura/`, o la falta de datos
   nunca bloquea `session_start` ni ningún otro protocolo; se omite en silencio.
2. **Idempotente** — nunca reprocesa un `session_id` que ya aparece en `sessions.jsonl`
   (evita duplicar filas de la misma sesión en corridas sucesivas).
3. **No versionar la salida** — `.agent/memory/observability/` está gitignored (telemetría de
   comportamiento de sesión, ver `AGENTS.md` → "Qué se Versiona"); el script nunca debe
   escribir fuera de ese directorio.
4. **`delegation_rate.a` conservador** — un trigger ambiguo (menos de 2 keywords específicos
   co-ocurriendo) se excluye del conteo en vez de inferirse; un denominador subestimado es
   preferible a uno inflado por heurística débil (mismo criterio que
   `.aura/rules/subagent-dispatch.md`).
5. **Rutas siempre vía variable de entorno hacia los bloques Python embebidos** — nunca
   interpoladas como literal dentro de un heredoc (bug real documentado en el propio script,
   Issue #205: un `transcript_path` de Windows con backslashes corrompía el JSON si se
   interpolaba directo).
