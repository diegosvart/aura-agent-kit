# Comando — /plan-report

> **Invoca:** `.claude/agents/plan-reporter.md`
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

1. Delega en el subagente `plan-reporter`
2. Obtiene token Azure vía `az account get-access-token`
3. Resuelve el GUID del proyecto desde el nombre parcial
4. Descarga tareas + buckets dinámicamente (sin hardcodear GUIDs)
5. Resuelve padres cross-proyecto via batch query
6. Clasifica hijas accionables: **VENCIDA** o **EN FECHA** (≤ ventana)
7. Presenta tabla agrupada por padre (vencidas primero)
8. Entrega 3 secciones de análisis:
   - Sugerencias de bucket (Blocked ↔ In Progress)
   - Alertas de riesgo (carga por responsable, tareas sin nota)
   - Vistas / filtros adicionales disponibles
9. Exporta CSV (utf-8-sig) si se especifica `--out`

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
/plan-report "Planificación área TI 2026" --out reporte_ti.csv
/plan-report "Planificación área TI 2026" --window 7 --today 2026-07-01
```

---

## Proceso

```
/plan-report "<plan>"
    ↓
plan-reporter ejecuta scripts/plan_report.py
    ↓
Tabla por padre (vencidas [!] primero)
    ↓
Resumen ejecutivo
    ↓
Recomendaciones (buckets + riesgo + vistas)
    ↓
CSV opcional
```

---

## Baseline de Verificación (TI 2026, 2026-06-11)

| Métrica | Esperado |
|---------|---------|
| Grupos padre | 18 |
| Hijas accionables | 39 |
| Vencidas | 8 |
| En fecha | 31 |
| Con nota | 12 |
