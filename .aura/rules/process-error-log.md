# Process Error Log — Autodeclaración de Errores de Proceso del Agente

## Regla principal (idea [021], Issue #206)

Cuando el agente detecta y corrige, dentro de la misma sesión, un error de **proceso** propio
(no un bug de código del proyecto — un error en cómo el agente operó el harness/git/gh), debe
invocar `log-process-error.sh` **en el momento** en que lo corrige, no diferirlo a un resumen
de cierre en prosa:

```bash
bash skills/observability/scripts/log-process-error.sh <owner>/<repo> <tipo> "<descripción>" ["<afectado>"]
```

## Taxonomía cerrada de `<tipo>`

No es una lista abierta — no inventar tipos nuevos sin pasar primero por una revisión de esta
regla:

| `tipo` | Cuándo aplica |
|---|---|
| `branch-wrong-base` | Se creó una rama desde el HEAD equivocado (ej. desde `main` en vez de `develop`, o desde una rama vieja sin actualizar) |
| `merge-order` | Un merge/rebase se aplicó en el orden incorrecto, generando conflictos evitables o pisando trabajo |
| `no-retry-after-rejection` | El usuario rechazó una acción (tool call denegado, PR pedido cambios) y el agente no reintentó con la corrección antes de seguir a otra cosa |
| `other` | Cualquier otro error de proceso real — obliga a una `<descripción>` libre y específica, no genérica |

## Por qué autodeclarar en el momento, no post-hoc

A diferencia de `delegation_rate` (Issue #179, `.aura/rules/subagent-dispatch.md`), que se
audita retrospectivamente parseando el transcript porque delegar-o-no es una decisión difusa,
un error de proceso ya es un **evento discreto observable en el momento exacto** en que el
agente lo detecta o lo corrige. Diferirlo a un `session_summary` en prosa al cierre depende de
que el agente se acuerde de mencionarlo con suficiente estructura para que sea buscable
después — el mismo anti-patrón que ya motivó mecanismos estructurados en vez de reglas de
texto puro en este harness (`pr-base-guard.ps1` para Issue #148/#230,
`.aura/rules/repo-integrity.md`).

## Qué NO cuenta como error de proceso

- Bugs de código del proyecto consumidor (van a Engram como `bugfix`, no acá).
- Decisiones de diseño discutibles pero no erróneas (eso es una `decision`, no un error).
- Rechazos del usuario por preferencia, no por error del agente (ej. "prefiero que uses X en
  vez de Y" no es `no-retry-after-rejection` salvo que el agente además haya ignorado el
  rechazo y seguido con Y).

## Verificación / auditoría

`protocols/session_start.md` Paso 3.6 cuenta ocurrencias por `tipo` en las últimas 10
sesiones (`skills/observability/scripts/check-process-errors.sh`) y sugiere `/auto-research`
cuando un mismo `tipo` aparece 3+ veces — mismo umbral cualitativo que
`protocols/session_end.md` Paso 10. `protocols/session_end.md` Paso 10 también pregunta
explícitamente si hubo un error de proceso sin autodeclarar antes de cerrar, como red de
seguridad.
