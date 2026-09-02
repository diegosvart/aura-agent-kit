---
name: plan-reporting
description: Genera reporte de gestión, tareas accionables y análisis de riesgo de un plan estratégico. Usar cuando el usuario pide un reporte de estado de un plan.
---

# Skill — plan-reporting

> **Comando:** `/plan-report "<nombre del plan>"`
> **Agente:** `.claude/agents/plan-reporter.md` ejecuta este procedimiento.
> **Cuándo activar:** Usuario pide reporte de gestión, tareas accionables, análisis de riesgo, o estado de un plan estratégico.

---

## Activación

```
Activando: plan-reporting [PM → Dataverse → motor → análisis]
```

Declarar explícitamente al inicio de la ejecución.

---

## Prerequisitos

- `az` CLI instalado y autenticado:
  ```
  az login --use-device-code --tenant b16beb2c-1c93-4497-bc75-5a1cdae6ee6c
  ```
- Python 3.10+ disponible como `python`
- `scripts/plan_report.py` en la raíz del repo

---

## Proceso Paso a Paso

### Paso 1 — Extraer datos y mostrar tabla

```bash
python scripts/plan_report.py --plan "<nombre parcial del plan>" --today YYYY-MM-DD --cache-file %TEMP%\plan_cache.json
```

- La tabla se imprime en pantalla automáticamente.
- El caché se guarda para evitar re-consultar Dataverse en el export.
- Si el usuario ya tiene el GUID exacto, usar `--project-id <GUID>` en lugar de `--plan`.
- Si quiere ajustar la ventana de "en fecha": agregar `--window-days N` (default 14).

### Paso 2 — Presentar resumen ejecutivo y análisis

La salida del motor ya incluye tres secciones. Interpretar con juicio de PM:

#### Sección [Escalamiento]
| Señal | Acción sugerida |
|-------|-----------------|
| Bloqueada + vencida > 14 días | Escalar al sponsor o responsable funcional |
| Múltiples tareas del mismo responsable en escalamiento | Riesgo de dependencia crítica |

#### Sección [Cambios de bucket]
| Situación | Sugerencia |
|-----------|------------|
| VENCIDA + nota + bucket ≠ Blocked | Mover a **Blocked** en Planner |
| Blocked + nota indica desbloqueo | Mover a **In Progress** |

**Nunca mover buckets directamente** — solo recomendar; el usuario actualiza en Planner.

#### Sección [Carga por responsable]
| Señal | Interpretación |
|-------|----------------|
| Concentración > 40% del total | Riesgo de dependencia |
| Responsable con vencidas ⚠ | Prioridad de seguimiento |

#### Sección [Calidad de datos]
- Tareas sin título excluidas del reporte — informar al usuario cuántas hay
- Tareas vencidas sin nota = sin visibilidad de bloqueo

### Paso 3 — Sugerir exportación

Al terminar de mostrar la tabla y el análisis, preguntar:

> "¿Exporto esto a CSV para análisis en Excel?"

Si el usuario dice sí:
```bash
python scripts/plan_report.py --from-cache %TEMP%\plan_cache.json --out <ruta_de_salida.csv>
```

Esto NO re-consulta Dataverse (usa el caché del Paso 1). El CSV usa encoding `utf-8-sig` compatible con Excel.

---

## Constantes Confirmadas (no re-investigar)

| Parámetro | Valor |
|-----------|-------|
| Org | `org914d3d16.crm.dynamics.com` |
| Tenant | `b16beb2c-1c93-4497-bc75-5a1cdae6ee6c` |
| Auth user | `dmorales@grupoebi.cl` |
| Responsable field | `msdyn_pfwmodifiedby` (expand `fullname`) |
| Notas field | `msdyn_descriptionplaintext` |
| Plan TI 2026 GUID | `6b687051-6b51-f111-bec7-7ced8d17c48d` |

---

## Baseline de Verificación (plan TI 2026, fecha ref 2026-06-11)

| Métrica | Esperado |
|---------|---------|
| Vencidas | 8 |
| Con nota | 12 |

> Nota: Los conteos de grupos padre e hijas varían con el trabajo del día — son un resumen en vivo.

---

## Reglas

- No commitear nada — solo analizar y reportar
- No re-implementar queries Dataverse — ejecutar el motor
- Declarar supuestos: fecha de referencia, ventana de días
- Si el token falla: informar el comando exacto de re-auth y esperar al usuario
- Al terminar → presentar menú de routing (`¿Qué sigue?`)
