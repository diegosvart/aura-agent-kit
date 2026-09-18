---
name: observability
description: Tres modos. (1) Automático por sesión — process-session.sh calcula output_tokens, tool_uses por categoría, duration_ms y delegation_rate (Issue #179) y appendea a sessions.jsonl; invocado desde el Paso 3.5 de protocols/session_start.md. (2) Bajo demanda agregado — session-report.sh (Issue #265) lee sessions.jsonl completo o un rango filtrado y produce un informe con delegation_rate acumulado, tendencias de tokens/duración y distribución de tool_uses; nunca automático. (3) Resumen de loop — loop-summary.sh (Issue #304) agrega un batch específico de sesiones (por lista de session_id o rango) tras correr varios subagentes/forks en paralelo; nunca automático.
---

# Skill — Observability

> **Scripts:**
> - `skills/observability/scripts/process-session.sh` — cálculo **por sesión individual**.
> - `skills/observability/scripts/session-report.sh` — informe **agregado** sobre el histórico
>   de `sessions.jsonl` (Issue #265). Ver
>   `docs/aura/specs/2026-09-13-session-behavior-report-design.md`.
> - `skills/observability/scripts/loop-summary.sh` — resumen de un **loop puntual** (batch de
>   subagentes/forks), por lista de `session_id` o rango de tiempo (Issue #304).
>
> **Invocado por:** `protocols/session_start.md` Paso 3.5 corre `process-session.sh`
> automáticamente (fail-open, silencioso si no hay datos), como reporte de la sesión anterior
> antes del Resumen Ejecutivo. `session-report.sh` y `loop-summary.sh` **no** se invocan desde
> ahí — ver "Cuándo Activar" abajo.

---

## Cuándo Activar

Hay **tres modos**, con triggers distintos — no confundir el de uno con el otro:

### Modo 1 — automático por sesión (`process-session.sh`)

- Automáticamente, en cada `session_start` (Paso 3.5) — nunca bloquea el resto del protocolo
  si falla, no existe `.aura/` (proyecto sin observability habilitada), o no hay datos
  nuevos.
- Bajo demanda, si el usuario pide explícitamente inspeccionar métricas de **una** sesión
  pasada puntual (tokens, `tool_uses`, `delegation_rate` de esa fila) fuera del flujo
  automático de `session_start`.

### Modo 2 — bajo demanda agregado (`session-report.sh`, Issue #265)

- **Únicamente bajo demanda** — invocación explícita del usuario o del skill (vía
  `/session-report` o pidiendo el informe agregado directamente). **Nunca automático dentro
  de `session_start.md`** — mismo criterio de cautela que `agents/evaluator.md` aplica a
  `flow-conformance-check` ("Cuándo Se Invoca": automatizar un análisis agregado es prematuro
  sin haber visto varias corridas manuales primero).
- Casos de uso típicos: verificar si el criterio de cierre del Issue #231
  (`delegation_rate >= 25%` en `>= 5` sesiones) se cumple en un rango; ver tendencias de
  `output_tokens`/`duration_ms`/`tool_uses` a través del tiempo, no solo de la última sesión.
- Uso: `skills/observability/scripts/session-report.sh [--since <ISO date> |
  --since-session <session_id>]` (flags mutuamente excluyentes; sin ninguno, procesa todo
  `sessions.jsonl`). Salida: informe en texto a **stdout**, nunca se escribe a archivo.
- **Responsabilidad de quien invoca** (no del script — Engram es un tool MCP, no invocable
  desde bash): guardar la sección "Conclusiones" del informe en Engram con `mem_save`,
  `topic_key: harness/session-behavior-report`.

### Modo 3 — resumen de loop (`loop-summary.sh`, Issue #304)

- **Únicamente bajo demanda**, justo después de correr un batch de subagentes/forks en
  paralelo (ej. varios issues del backlog vía `/run-dev-loop`, o varios forks lanzados
  manualmente como en la sesión que originó este modo) — para ver de un vistazo qué sesiones
  entraron en ese loop y cuánto costó en conjunto, sin tener que revisar cada una por
  separado. **Nunca automático** dentro de `session_start.md` — mismo criterio de cautela que
  Modo 2.
- Origen: idea [032] "Aura Control Panel", Enfoque C (extender `skills/observability/` antes
  de construir un dashboard o servicio nuevo — ver
  `docs/aura/specs/2026-09-17-aura-control-panel-brainstorm.md`).
- Uso: `skills/observability/scripts/loop-summary.sh [--session-ids <id1,id2,...> | --since
  <ISO date>]` (flags mutuamente excluyentes; sin ninguno, procesa todo `sessions.jsonl`).
  Salida: resumen en texto a **stdout**, nunca se escribe a archivo.
- Agrega, sobre las sesiones seleccionadas: tokens totales, `tool_uses` por categoría,
  duración total, `delegation_rate` agregado, y un listado por sesión (`session_id`,
  `ended_at`, tokens, duración).
- **Limitación conocida:** `sessions.jsonl` no registra qué issue/PR quedó asociado a cada
  sesión — el listado por sesión lo señala explícitamente ("resultado: no disponible en
  sessions.jsonl") en vez de inventar o inferir un valor. Resolverlo (si se necesita) es
  trabajo de un issue separado, no de este paso.
- Si se quiere conservar el resumen más allá de la sesión actual: publicarlo como Artifact
  (privado por defecto) o guardar los puntos relevantes en Engram — nunca commitearlo (mismo
  motivo que Modo 2).

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

`protocols/session_start.md` Paso 3.5 lee la **última línea** de `sessions.jsonl` tras correr
el script y muestra un bloque compacto ("Sesión Anterior") antes del Resumen Ejecutivo:
tokens de salida, `tool_uses` por categoría, duración, y la línea de `delegation_rate` con el
formato exacto que especifica `.aura/rules/subagent-dispatch.md` (`b/a (rate)` si `a > 0`,
o la línea explícita de "sin triggers detectados" si `a == 0` — nunca dividir por cero).

```
skills/observability/scripts/session-report.sh [--since <ISO> | --since-session <id>]
    ↓
Lee .agent/memory/observability/sessions.jsonl completo (o el rango filtrado)
    ↓
Filas SIN campo delegation_rate (formato pre-migración) → excluidas explícitamente del
cálculo agregado, nunca contadas como a=0
    ↓
Calcula: delegation_rate agregado (sum(b)/sum(a)) + conteo de filas con a>0 (si <5,
"muestra insuficiente", nunca afirma el umbral #231 cumplido) · promedio/mediana de
output_tokens y duration_ms vs. el rango anterior de igual tamaño (si hay datos) ·
distribución de tool_uses como proporciones
    ↓
Imprime informe a stdout (nunca a archivo) con sección "Conclusiones" en prosa
    ↓
Quien invocó guarda la sección "Conclusiones" en Engram (mem_save,
topic_key: harness/session-behavior-report) — el script no lo hace
```

---

## Reglas

1. **Fail-open siempre** — un fallo del script, la ausencia de `.aura/`, o la falta de datos
   nunca bloquea `session_start` ni ningún otro protocolo; se omite en silencio.
2. **Idempotente** — nunca reprocesa un `session_id` que ya aparece en `sessions.jsonl`
   (evita duplicar filas de la misma sesión en corridas sucesivas).
3. **No versionar la salida** — `.agent/memory/observability/` está gitignored (telemetría de
   comportamiento de sesión, ver `AGENTS.md` → "Qué se Versiona"); `process-session.sh` nunca
   debe escribir fuera de ese directorio. `session-report.sh` y `loop-summary.sh` no escriben
   a ningún archivo en absoluto — imprimen a stdout únicamente (el informe cae en la fila
   "Análisis/informes ad-hoc" de esa misma tabla: NO se versiona).
4. **`delegation_rate.a` conservador** — un trigger ambiguo (menos de 2 keywords específicos
   co-ocurriendo) se excluye del conteo en vez de inferirse; un denominador subestimado es
   preferible a uno inflado por heurística débil (mismo criterio que
   `.aura/rules/subagent-dispatch.md`).
5. **Rutas siempre vía variable de entorno hacia los bloques Python embebidos** — nunca
   interpoladas como literal dentro de un heredoc (bug real documentado en el propio script,
   Issue #205: un `transcript_path` de Windows con backslashes corrompía el JSON si se
   interpolaba directo). `session-report.sh` sigue la misma convención.
6. **`session-report.sh` es aditivo y solo-lectura** — nunca modifica `sessions.jsonl` ni
   `process-session.sh`; consume la salida ya calculada, no la recalcula.
7. **`session-report.sh` con muestra chica nunca fuerza una conclusión** — si las filas con
   `delegation_rate.a > 0` en el rango son menos de 5, el informe dice explícitamente "muestra
   insuficiente" y nunca declara el umbral del Issue #231 (`>=25%`) cumplido con esa muestra
   (misma Salvaguarda de `.aura/rules/subagent-dispatch.md`, aplicada por analogía a las
   demás métricas del informe — ver spec de diseño, sección "Umbral de confiabilidad").
