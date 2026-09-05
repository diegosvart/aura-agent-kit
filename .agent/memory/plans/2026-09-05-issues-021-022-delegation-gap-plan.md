---
status: approved
---

# Plan — Crear 6 issues en GitHub para cerrar el gap real de delegación a sub-agentes

## Contexto

El usuario busca un flujo estable donde spec detallada + issues de GitHub deriven en un
equipo de sub-agentes que desarrolle/revise/pruebe/indique "terminado" sin supervisión
constante. Ese flujo ya se diseñó hace tiempo (`.aura/rules/subagent-dispatch.md`,
`skills/agentic-dev-loop/SKILL.md`) pero en la práctica casi no delega — ni tareas simples —
y esto está generando fricción suficiente como para considerar cambiar de modelo de lenguaje.

Se investigó con 3 agentes Explore en paralelo (delegación, observability/errores de
proceso, visibilidad del harness) y 1 agente Plan que diseñó la solución. Hallazgo central:
**el problema no es solo que la regla de delegación no tenga enforcement duro (confirmado:
técnicamente imposible bloquear "no se invocó Agent" con un hook, porque la ausencia de una
tool-call no es un evento capturable)** — es que la única métrica que debía darle
visibilidad al usuario sobre si se delega o no (`delegation_rate`, definida en Issue #179)
**nunca se calculó ni una sola vez**: `sessions-index.jsonl` tiene 27 sesiones reales desde
2026-08-04, pero `sessions.jsonl` (el output de `process-session.sh`) no existe — el script
nunca completó un run exitoso, y el paso que lo invoca en `session_start.md` es fail-open
silencioso (`2>/dev/null || true`), así que nadie se enteró.

Las ideas [021] (log de errores de proceso) y [022] (dashboard de visibilidad del harness),
ya registradas en `.agent/memory/ideas.md` (PR #204, mergeado), construyen sobre ese mismo
patrón roto — arreglarlo es la precondición, no una idea más.

**Decisión del usuario:** no implementar nada en esta sesión. Crear los 6 issues en GitHub,
con el diseño completo embebido en cada body, para ejecutarlos después (manualmente o vía
`/run-dev-loop`).

## Housekeeping previo (antes de crear issues)

- `develop` local está 9 commits detrás de `origin/develop` (incluye el merge de PR #204).
  Correr `git pull origin develop` antes de crear cualquier rama nueva basada en local.

## Issues a crear (orden de prioridad/dependencia)

Repo: `diegosvart/aura-agent-kit`. Usar `gh issue create` con `--label` según se indica.

### Issue #1 — bug: `process-session.sh` nunca generó `sessions.jsonl`
**Label:** `bug`, `ready`
**Body:**
- Diagnosticar por qué, sobre 27 entradas reales en `.agent/memory/observability/sessions-index.jsonl`,
  nunca se generó ninguna línea en `sessions.jsonl`. Candidatos a revisar en orden: (1) correr
  `bash skills/observability/scripts/process-session.sh` sin `2>/dev/null` y leer stderr real;
  (2) rutas con backslash de Windows en `transcript_path` rompiendo `open()` de Python
  embebido; (3) confirmar si el Paso 5.5 de `protocols/session_start.md` se ejecuta
  consistentemente en sesiones reales.
- Corregir la causa raíz y correr sobre el histórico completo.
- Reportar en el PR el `delegation_rate` real agregado resultante — primer dato real desde
  que existe la regla (Issue #179).
- **No requiere hipótesis P4** — es fix de un script con contrato ya definido, no cambio de
  comportamiento de protocolo/skill.
- **DoD:** `sessions.jsonl` existe con una línea por entrada procesable; PR incluye el
  `delegation_rate` real observado.
- **Archivos:** `skills/observability/scripts/process-session.sh`.
- **Verificación:**
  ```bash
  bash skills/observability/scripts/process-session.sh
  wc -l .agent/memory/observability/sessions.jsonl   # esperar ~27
  tail -1 .agent/memory/observability/sessions.jsonl | python3 -m json.tool
  ```

### Issue #2 — mecanismo de log de errores de proceso (idea [021])
**Label:** `enhancement` (sin `ready` hasta que exista la hipótesis P4, ver abajo)
**Depende de:** Issue #1 (mismo directorio/contexto, conviene después).
**Body:**
- Requiere primero registrar hipótesis P4 en
  `docs/aura/experiments/2026-09-05-observability-errores-proceso.md` (formato de
  `docs/aura/experiments/TEMPLATE.md`) — incluir como primera tarea del issue, no como
  issue separado.
- Script nuevo `skills/observability/scripts/log-process-error.sh <owner>/<repo> <tipo>
  "<descripción>" ["<afectado>"]` que appendea a
  `.agent/memory/observability/process-errors.jsonl` (gitignored, mismo directorio que
  `sessions.jsonl`).
- Autodeclarado por el agente en el momento en que detecta/corrige el error — no inferido
  post-hoc del transcript (a diferencia de `delegation_rate`, un error de proceso ya es un
  evento discreto observable en el momento).
- Taxonomía cerrada de 4 tipos (no lista abierta): `branch-wrong-base`, `merge-order`,
  `no-retry-after-rejection`, `other` (obliga a descripción libre).
- Schema: `{"logged_at","session_id","tipo","descripcion","afectado","corregido"}`.
- Conexión con `protocols/session_end.md` Paso 10 (Auto-Research): agregar una pregunta más
  a las 3 existentes ("¿se registró algún error de proceso esta sesión?") sin bajar el
  umbral de 3+ sesiones que ya usa ese paso.
- Nuevo paso en `protocols/session_start.md` (junto al Paso 5.5 existente, mismo patrón
  fail-open): cuenta `process-errors.jsonl` de los últimos N días agrupado por `tipo`; si un
  mismo `tipo` aparece 3+ veces en las últimas 10 sesiones, sugiere `/auto-research` con ese
  `tipo` como hipótesis de partida — mismo umbral cualitativo de Paso 10, sin inventar un
  segundo criterio.
- **Archivos:** `skills/observability/scripts/log-process-error.sh` (nuevo);
  `.aura/rules/harness-core.md` o `.aura/rules/process-error-log.md` (nuevo, decidir en el
  issue); `protocols/session_start.md`; `protocols/session_end.md`; `protocols/router.md`
  (nueva fila si aplica).
- **Verificación:**
  ```bash
  bash skills/observability/scripts/log-process-error.sh diegosvart/aura-agent-kit branch-wrong-base "test" "feature/x"
  tail -1 .agent/memory/observability/process-errors.jsonl
  ```
  Confirmar rechazo claro para un `tipo` fuera de la taxonomía cerrada.

### Issue #3 — fricción en el momento de decidir delegar
**Label:** `enhancement` (condicionado, ver nota)
**Depende de:** Issue #1 — el alcance exacto se define después de ver el `delegation_rate`
real; si el número ya es razonable, este issue podría cerrarse como no-necesario.
**Body:**
- Extender `.aura/rules/subagent-dispatch.md` para exigir auto-declaración explícita en el
  output cuando se detecta un trigger de `router.md` aplicable: *"Trigger de router.md
  detectado (<situación>); ejecuto inline porque <condición 2 no se cumple / volumen ≤3>"*.
  Convierte una decisión implícita en una afirmación auditable — sin hooks, sin bloqueo
  duro (confirmado técnicamente inviable).
- **Verificación:** cualitativa — en una sesión real con trigger claro de `router.md`,
  confirmar que el agente emite la auto-declaración antes de decidir.

### Issue #4 — comando `/harness-status` (idea [022], Fase A)
**Label:** `enhancement` (sin `ready` hasta que exista la hipótesis P4)
**Depende de:** nada, puede ejecutarse en paralelo a #1-#3.
**Body:**
- Requiere primero registrar hipótesis P4 en
  `docs/aura/experiments/2026-09-05-harness-status-dashboard.md`.
- Script `skills/observability/scripts/build-harness-inventory.sh`: recorre `agents/*.md`
  (9), `skills/*/SKILL.md` (17), `protocols/*.md` (5), `.aura/rules/*.md` (6) +
  `.claude/rules/*.md` (2), `commands/*.md` (13), `.claude/hooks/*.ps1` (4).
- Parsea la tabla de `protocols/router.md` (reusar la misma lógica de parseo de columnas
  `|` que ya usa `process-session.sh` para calcular `a` de `delegation_rate` — no
  reinventar un parser de markdown-tables) y valida que cada ruta referenciada exista en
  disco. Si no existe: `BROKEN-REF: <situación> → <ruta>` (mismo formato de severidad que
  `MISSING:`/`MISPLACED:` de `check-repo-manifest.sh`).
- Salida Fase A: comando `/harness-status` que imprime tabla markdown en consola —
  **no HTML todavía** (más caro de mantener y de verificar mecánicamente; el JSON que
  produce este script queda como base para un artifact HTML en un issue futuro, Fase B, no
  incluido acá).
- Se mantiene actualizado por construcción: nunca se edita a mano, se regenera en cada
  invocación leyendo el árbol real — evita repetir el caso de
  `docs/aura/specs/2026-05-09-harness-pillars.md` (referenciado, nunca existió en disco,
  ver Issue #147).
- **Archivos:** `skills/harness-status/SKILL.md` (nuevo, o extensión de
  `skills/observability/`); `skills/observability/scripts/build-harness-inventory.sh`
  (nuevo); `commands/harness-status.md` (nuevo); `protocols/router.md` (nueva fila);
  `skills/repo-integrity/manifest.txt` (agregar rutas nuevas).
- **DoD:** correr `/harness-status` sobre este repo reporta al menos 1 `BROKEN-REF` real (el
  de Issue #147).
- **Verificación:**
  ```bash
  bash skills/observability/scripts/build-harness-inventory.sh
  ```
  Esperar conteos ≈ (agentes=9, skills=17, protocolos=5, rules=8, comandos=13, hooks=4) y
  al menos 1 `BROKEN-REF`.

### Issue #5 — cerrar Issue #147 usando el propio `/harness-status`
**Label:** `bug`
**Depende de:** Issue #4.
**Body:**
- Aplicar una de las 3 opciones que Issue #147 ya lista (crear `harness-pillars.md`,
  actualizar las referencias, o eliminarlas) y confirmar con `/harness-status` que el
  `BROKEN-REF` desaparece.
- **DoD:** Issue #147 cerrado; `/harness-status` limpio de esa referencia.
- **Verificación:**
  ```bash
  bash skills/observability/scripts/build-harness-inventory.sh | grep BROKEN-REF
  ```
  Esperar sin salida.

### Issue #6 — spec/hipótesis: ampliar `agentic-dev-loop` a más tipos de trabajo
**Label:** `enhancement` (label `research` no existe en el repo; no `ready` — es solo
redactar la hipótesis, no implementar)
**Depende de:** dato real de Issue #1 (y opcionalmente #3).
**Body:**
- Único lugar donde la delegación es estructural hoy (no depende de que el modelo se
  acuerde) es `skills/agentic-dev-loop/SKILL.md` Fase 1 Paso 4 (dev-runner, `isolation:
  "worktree"` obligatorio). Evaluar si conviene reformular más tipos de tarea como issues
  loop-ready en vez de dejarlos a la decisión ad-hoc de `subagent-dispatch.md`.
- Registrar hipótesis P4 en
  `docs/aura/experiments/2026-09-05-ampliar-agentic-dev-loop.md`: *"Si reformulamos [tipo de
  tarea hoy decidida ad-hoc] como issues loop-ready, esperamos que `delegation_rate` suba
  porque pasa a estar dentro del molde estructural que fuerza `isolation: worktree`, en vez
  de depender de que se recuerde la regla de `subagent-dispatch.md` caso a caso."*
- **No tocar `agentic-dev-loop/SKILL.md` en este issue** — solo redactar y presentar la
  hipótesis para validación (P4 exige esto antes de modificar el skill).
- **DoD:** archivo de experimento existe con hipótesis + criterio de éxito, revisado vía
  `/doc-check`.

## Verificación end-to-end del plan

```bash
git pull origin develop
gh issue list --repo diegosvart/aura-agent-kit --label ready --state open
```
Confirmar que Issue #1 aparece como `ready` y los demás con sus labels correctos
(`enhancement`/`bug`, sin `ready` donde depende de hipótesis P4 previa).
