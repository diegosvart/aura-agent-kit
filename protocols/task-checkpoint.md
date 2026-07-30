# Protocolo — Task Checkpoint

> **Cuándo:** Al confirmar que una PR fue abierta o mergeada (invocado desde `finish-branch`).
> **Propósito:** Preservar el estado relevante de la tarea completada antes de que la degradación de contexto afecte el workflow en sesiones largas.
> **Obligatorio:** Sí — corre siempre después de PR, no es condicional.

---

## Motivación

A partir de ~100k tokens de contexto, el modelo puede perder visibilidad de las reglas del workflow y GitHub, generando errores como commits directos a ramas protegidas. Este protocolo crea un punto de guardado limpio al cerrar cada unidad de trabajo.

---

## Paso 1 — Guardar en Engram (siempre primero)

```
mem_session_summary(
  content="## Goal
[Una línea: qué tarea se completó]

## Accomplished
- ✅ [Descripción de lo implementado]
- ✅ PR #N abierta / mergeada a develop

## Next Steps
- [Próximo issue o acción concreta]

## Relevant Files
- [archivo 1] — [qué cambió]
- [archivo 2] — [qué cambió]",
  project="{{PROJECT_NAME}}"
)
```

**Foco:** la tarea recién completada, no toda la sesión.  
Si `mem_session_summary` falla → continuar con advertencia, no bloquear.

---

## Paso 2 — Actualizar `current-session.json`

Archivo: `.agent/memory/current-session.json`

```json
{
  "last_updated": "{{ISO_TIMESTAMP}}",
  "branch": "{{CURRENT_BRANCH}}",
  "focus": "{{TAREA_COMPLETADA_EN_UNA_LÍNEA}}",
  "next_step": "{{SIGUIENTE_ISSUE_O_ACCIÓN}}",
  "pending": ["{{TAREA_PENDIENTE_1}}", "{{TAREA_PENDIENTE_2}}"],
  "required_reads": ["{{ARCHIVO_RELEVANTE}}"]
}
```

**Reglas:**
- `next_step` debe apuntar al próximo trabajo concreto (ej: "Issue #27 — integrar checkpoint en finish-branch")
- `pending` solo items verificados — no incluir la PR recién abierta/mergeada
- Max 4 items en `pending`, max 4 en `required_reads`

---

## Paso 3 — Evaluar necesidad de compact

El agente evalúa señales heurísticas de contexto extenso:

| Señal | Umbral orientativo |
|-------|--------------------|
| Turnos en la conversación | > 30 turnos |
| Tool calls acumulados | > 50 tool calls |
| Tareas completadas en esta sesión | > 2 issues implementados |

Si **una o más señales** están presentes:

```
💡 Contexto extenso detectado.

Para mantener la calidad del workflow en el resto de la sesión,
recomiendo compactar el contexto ahora que terminamos esta tarea.

Ejecutá: /compact

Esto comprime el historial de conversación sin perder el estado
guardado en Engram y current-session.json.
```

Si no hay señales → continuar sin interrumpir.

---

## Orden de Ejecución (obligatorio)

```
1. mem_session_summary    ← SIEMPRE primero
2. current-session.json   ← antes de cualquier compactación
3. Evaluar compact         ← solo después de guardar
```

**Nunca sugerir `/compact` antes de completar los pasos 1 y 2.**

---

## Integración

Este protocolo es invocado desde:
- `skills/finishing-a-development-branch/SKILL.md` — como último paso post-PR

Puede invocarse desde cualquier skill que represente el cierre de una unidad de trabajo.

---

## Reglas

1. **Corre siempre** — no es condicional por umbral de tokens
2. **Engram antes que compact** — el orden no es negociable
3. **No bloquear el flujo** — si Engram falla, advertir y continuar
4. **Foco en la tarea** — `mem_session_summary` describe la tarea completada, no toda la sesión
5. **Heurísticas, no métricas exactas** — el agente no puede leer tokens directamente
