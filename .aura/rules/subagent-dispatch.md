# Subagent Dispatch — Criterio de Delegación

## Regla principal (Issue #179)

`protocols/router.md` indica *qué archivo cargar* por situación, pero no distingue cuándo eso
implica *despachar un subagente* (`Agent` tool, contexto aislado) versus *leer el archivo
inline* (contexto compartido de la conversación activa, sin aislar). Esta regla cierra esa
ambigüedad con dos condiciones evaluables.

**Delegar a subagente (`Agent` tool) cuando se cumplen AMBAS condiciones:**
1. Existe un trigger aplicable en la tabla de `protocols/router.md` para la situación actual, **y**
2. La tarea NO requiere leer de vuelta el contexto ya acumulado en la conversación activa para
   ejecutarse — se le puede pasar como entrada un enunciado autocontenido (un issue, un
   archivo, un fragmento de spec) sin que dependa de decisiones tomadas minutos antes con el
   usuario en el hilo actual.

**Ejecutar inline cuando se cumple CUALQUIERA de estas:**
- La condición 2 de arriba falla (la tarea depende del contexto vivo de la conversación), o
- El volumen esperado de tool-calls es bajo (≤3) y aislar el contexto no genera ahorro medible.

Esto formaliza como regla del harness Aura un principio que ya existe como guía en el entorno
de ejecución (fork vs. fresh agent) — no es mecanismo nuevo, es hacerlo explícito y auditable
dentro de `AGENTS.md`/`router.md`, en vez de dejarlo a criterio implícito caso por caso.

## Caso borde — tarea ambigua entre delegar e inline

Si la condición 1 aplica pero la condición 2 es dudosa (la tarea toca tanto contexto vivo como
trabajo aislable), la regla por defecto es **delegar la porción aislable** y mantener inline
solo la parte que depende del hilo — no una decisión binaria de todo-o-nada por tarea.

Ejemplo real (sesión 2026-09-02): implementar un fix ya discutido con el usuario queda inline
(depende de la decisión recién tomada), pero la verificación de integridad documental posterior
se delega a `doc-guardian` (aislable, verificable sin el hilo completo).

## Caso borde — riesgo de que la regla se ignore en la práctica

El git flow no se respetaba mientras vivió solo como instrucción en `AGENTS.md`, sin
verificación — se resolvió cuando pasó a ser un hook (`git-guard.ps1`) que bloquea la acción,
no un texto a recordar. Esta regla corre el mismo riesgo si queda solo como texto.

A diferencia del git flow, no hay forma de bloquear estructuralmente "no delegaste cuando
debías" con un hook `PreToolUse` — delegar es una decisión positiva, no una acción prohibible
que se pueda interceptar. Por eso esta regla **no lleva enforcement duro**: en su lugar,
`skills/observability/scripts/process-session.sh` audita el comportamiento después del hecho
vía la métrica `delegation_rate` (ver abajo), como detección, no como bloqueo.

## Métrica de auditoría — `delegation_rate`

Calculada por sesión en `skills/observability/scripts/process-session.sh` y expuesta en
`protocols/session_start.md` Paso 5.5 (reporte de sesión anterior):

- **Denominador `a` (triggers aplicables):** derivado mecánicamente por matching de patrón
  entre el transcript de la sesión y las columnas "Situación"/"Trigger" de
  `protocols/router.md` (mismo enfoque de matching por patrón que `check-base-branch.sh` /
  `check-repo-manifest.sh`). Si el matching es ambiguo para un trigger dado, ese trigger se
  **excluye** del conteo — un denominador subestimado es preferible a uno inflado por
  heurística débil.
- **Numerador `b` (delegaciones con volumen real):** cuenta solo invocaciones del `Agent` tool
  cuyo resultado registra **más de 3 tool-calls internas** — el mismo umbral que define la
  condición "no delegar por bajo volumen" arriba. Una invocación con ≤3 tool-calls no cuenta:
  es evidencia de delegación cosmética.
- **Delegación parcial:** si dentro de una misma sesión un trigger aplicable resultó en una
  mezcla de trabajo inline + una invocación delegada que supera el umbral de `b`, cuenta como
  delegación cumplida para ese trigger.
- Se expone como `delegation_rate = b/a`, junto con los valores crudos `a` y `b` (no solo el
  cociente), para que una sesión con `a` bajo (0 o 1) sea distinguible de una con muestra
  significativa.

**Línea base:** 1/8 = 12.5% (sesión 2026-09-02, `docs/aura/specs/2026-09-02-resumen-comportamiento-agente-subagentes.md`).

**Salvaguarda:** una tendencia medida sobre pocas sesiones (n=5, denominador estructuralmente
chico y heterogéneo) no autoriza por sí sola escalar a enforcement duro sobre esta regla —
solo justifica seguir observando o revisarla cualitativamente. Cualquier propuesta de
enforcement duro posterior necesita su propia hipótesis P4 nueva, registrada en Engram
(`topic_key: harness/delegation-rate`), no se deriva automáticamente de esta métrica.

---

Ver `docs/aura/specs/2026-09-02-plan-estabilizacion-harness-reconciliacion.md` (gitignored)
para el análisis completo que motivó esta regla — reconciliación del plan de estabilización
fase 1 contra evidencia empírica real, validado por `spec-validation` (PASS) y `challenger`
(GO con condiciones, aplicadas).
