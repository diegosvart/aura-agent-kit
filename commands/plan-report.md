# Comando — /plan-report

> **Skill:** `skills/plan-reporting/SKILL.md` (fuente de verdad del procedimiento)
> **Agente:** `.claude/agents/plan-reporter.md` (ejecuta el skill en contexto aislado)
> **Cuándo usar:** Para generar un reporte de gestión de un plan estratégico — tareas accionables, análisis de riesgo, sugerencias de bucket.

---

## Uso

```
/plan-report "<nombre del plan>"
/plan-report "<nombre del plan>" --window 21
/plan-report "<nombre del plan>" --today 2026-07-01 --out reporte.csv
/plan-report --project-id <GUID>
```

---

## Qué Hace

1. Activa el skill `plan-reporting` vía el subagente `plan-reporter`
2. Obtiene token Azure vía `az account get-access-token`
3. Resuelve el GUID del proyecto desde el nombre parcial
4. Descarga tareas + buckets dinámicamente (sin hardcodear GUIDs)
5. Resuelve padres cross-proyecto via batch query
6. Clasifica hijas accionables: **VENCIDA** o **EN FECHA** (≤ ventana)
7. **Muestra la tabla en pantalla** (siempre, antes de exportar)
8. Entrega análisis en 4 secciones:
   - Escalamiento (bloqueadas-vencidas críticas)
   - Sugerencias de bucket (Blocked ↔ In Progress)
   - Carga por responsable
   - Calidad de datos (tareas fantasma, sin nota)
9. **Sugiere exportación a CSV** — si el usuario acepta, usa caché local (sin re-consultar Dataverse)

---

## Prerequisitos

- `az` CLI instalado y autenticado:
  ```
  az login --use-device-code --tenant b16beb2c-1c93-4497-bc75-5a1cdae6ee6c
  ```
- Python 3.10+ en el PATH
- `scripts/plan_report.py` en la raíz del repo

---

## Ejemplos

```
/plan-report "Planificación área TI 2026"
/plan-report "Planificación área TI 2026" --window 7 --today 2026-07-01
/plan-report --project-id 6b687051-6b51-f111-bec7-7ced8d17c48d
```

---

## Flujo

```
/plan-report "<plan>"
    ↓
plan-reporter ejecuta skills/plan-reporting/SKILL.md
    ↓
Tabla por padre (vencidas [!] primero) + nota completa en sub-línea
    ↓
Resumen ejecutivo
    ↓
Análisis: Escalamiento / Buckets / Carga / Calidad
    ↓
Sugerir export → si sí: --from-cache (sin doble Dataverse fetch)
    ↓
CSV opcional
```

---

## Baseline de Verificación (TI 2026, 2026-06-11)

| Métrica | Esperado |
|---------|---------|
| Vencidas | 8 |
| Con nota | 12 |

> Nota: conteos de grupos y hijas varían con el trabajo del día — resumen en vivo.
