# Comando — /evaluate-sessions

> **Invoca:** `agents/evaluator.md`
> **Cuándo usar:** Para auditar si una sesión (o un rango de sesiones recientes) respetó el
> flujo de protocolo declarado del harness, comparándola contra el diagrama de referencia
> versionado en `aura-harness-diagrams`.

---

## Uso

```
/evaluate-sessions                 # evalúa la sesión activa/última
/evaluate-sessions <fecha|rango>   # evalúa una sesión o rango específico
```

---

## Qué Hace

1. Invoca `agents/evaluator.md`
2. Resuelve `.agent/memory/evaluator-config.json` (ruta al checkout local de
   `aura-harness-diagrams`) — pregunta la ruta si no existe o no resuelve (fail-clear)
3. Corre `flow-conformance-check`: compara la traza real de la sesión (o el registro
   disponible si no hay traza de `skills/session-trace/SKILL.md`) contra el diagrama de
   referencia (`ciclo-vida-sesion.json` por defecto)
4. Emite reporte con `[CRÍTICO]/[ADVERTENCIA]/[MEJORA]/[INFO]` (mismo vocabulario que
   `agents/challenger.md`)
5. Veredicto final: **GO** o **NO-GO**

---

## Cuándo Usar

Solo bajo demanda — nunca automático en `session_start`/`session_end` (ver
`agents/evaluator.md` → "Cuándo Se Invoca" para el rationale de esta restricción).

---

## Proceso

```
/evaluate-sessions [sesión|rango]
    ↓
evaluator resuelve ruta cross-repo (fail-clear/fail-soft)
    ↓
flow-conformance-check contra el diagrama de referencia
    ↓
GO → sin desvíos relevantes del flujo declarado
NO-GO → lista de desvíos, candidatos a hipótesis de /auto-research
```

---

## Ejemplo de Reporte

```
## Evaluator Review — sesión 2026-09-06 (Issue #232)

### Diagrama de referencia
C:/repos/aura-harness-diagrams/output/aura-agent-kit/ciclo-vida-sesion.json (diagram_type: lifecycle)

### Conformidad de flujo
- [OK] session-start → task-start → routing-menu recorridos en orden

### Veredicto
**GO** — sin desvíos del flujo declarado.
```
