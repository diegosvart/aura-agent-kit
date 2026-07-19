# Comando — /run-dev-loop

> **Invoca:** `skills/agentic-dev-loop/SKILL.md`
> **Cuándo usar:** Para disparar una pasada del loop de desarrollo + verificación de issues (manual o desde una corrida programada).

---

## Qué Hace

1. **Fase 1 (dev-runner):** toma el issue `ready` de menor número sin dependencias abiertas,
   lo marca `in-progress`, lanza un agente de desarrollo que implementa el issue completo
   (rama, código, tests, commit, push, PR con `Closes #N`), y al terminar pasa el label a
   `review`.
2. **Fase 2 (verifier):** para issues en `review` (o el issue puntual que se indique), audita
   el PR asociado contra el DoD real del issue y **recomienda** mergear o no — nunca mergea
   por su cuenta.

## Cuándo Usar

- El usuario dice "corré el loop", "seguí con los issues", "revisá lo que quedó pendiente"
- El usuario avisa "cerré/mergeé el issue N, revisalo" → correr solo la Fase 2 sobre ese issue
- Desde una corrida programada (cron) que ejecuta ambas fases en secuencia

## Argumentos

- Sin argumentos: corre Fase 1 seguida de Fase 2 sobre todo lo que esté `ready`/`review`.
- Con un número de issue: corre solo la Fase 2 sobre ese issue puntual (caso "revisá el issue N").

## Precondición

`gh` autenticado con permisos de escritura (labels, comentarios, PRs) en el repo. Si no está
autenticado, avisar y detenerse — no continuar en un estado parcial.
