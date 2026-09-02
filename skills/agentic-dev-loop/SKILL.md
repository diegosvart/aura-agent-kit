---
name: agentic-dev-loop
description: Ejecuta issues con label ready usando agentes, separando desarrollo (no supervisado) de verificación (nunca mergea sola). Usar al correr /run-dev-loop.
---

# Skill — Agentic Dev Loop (desarrollo + verificación de issues)

> **Propósito:** Ejecutar issues `ready` con agentes, separando desarrollo (no supervisado) de
> verificación (nunca mergea sola). Reduce la atención humana requerida por issue a: aprobar el
> plan una vez, y decidir el merge al final.
> **Comando asociado:** `/run-dev-loop`
> **Spec / hipótesis:** `docs/aura/specs/2026-07-19-loop-dev-verificacion.md` (P4)
> **Precondición:** `gh` autenticado y con permisos de escritura (labels, comentarios, PRs) en
> `<OWNER>/<REPO>`. Si no está autenticado, no ejecutar — avisar y detenerse.

---

## Vocabulario de Labels

| Label | Significado | Quién lo pone | Excluye a |
|---|---|---|---|
| `ready` | Sin dependencias abiertas, libre para tomar | `issue-planning` / manual | los otros 4 |
| `blocked` | Depende de algo no resuelto (otro issue abierto, un repo externo) | manual / dev-runner | los otros 4 |
| `in-progress` | El dev-runner lo está trabajando ahora | dev-runner | los otros 4 |
| `review` | PR abierto, esperando auditoría | dev-runner al terminar | los otros 4 |
| `changes-requested` | La verificación encontró que no cumple el DoD | verifier | los otros 4 |

Un issue solo debe tener **uno** de estos cinco labels a la vez. Aparte de estos, el label
estándar de GitHub `bug` (si el repo lo tiene, que es el caso por default) funciona como señal
de **prioridad**: `pick-next-issue.sh` toma un `ready` con `bug` antes que cualquier `ready` sin
ese label, sin importar el número de issue (fix antes que feat). `issue-planning/SKILL.md`
aplica `bug` al crear un issue que describe un defecto/corrección. Si un repo no tiene alguno de
estos labels todavía, crearlo antes de la primera corrida:
```bash
gh label create in-progress --repo <OWNER>/<REPO> --description "El dev-runner lo está trabajando" --color 0e8a16
gh label create review --repo <OWNER>/<REPO> --description "PR abierto, esperando auditoría" --color fbca04
gh label create changes-requested --repo <OWNER>/<REPO> --description "No cumple el DoD, requiere ajuste" --color d93f0b
gh label create blocked --repo <OWNER>/<REPO> --description "Depende de algo no resuelto" --color b60205
```

---

## Precondición de contenido — ¿el issue es apto para el loop?

Antes de tomar un issue `ready`, confirmar que su body es **autocontenido**: objetivo, archivos
a tocar, criterio de éxito (DoD) explícito, y — si depende de otro issue — que esa dependencia
esté declarada en texto ("Depende de: Issue N"). Si el body es vago (sin DoD verificable, sin
archivos, requiere una decisión de diseño que no está tomada), **no tomarlo**: dejarlo `ready`
y señalar al usuario que necesita más detalle antes de entrar al loop (volver a
`issue-planning` si hace falta). Esto es lo que separa a un issue "loop-ready" de uno que solo
tiene el label `ready` por convención de `session_start`.

---

## Paso 0 — Bootstrap de stack (una sola vez por repo)

Si `.agent/memory/session-stack.json` no existe, generarlo antes de correr el loop por primera
vez en este repo: detectar el stack (P6) y completar `{"stack": "...", "lint": "...",
"typecheck": "...", "test": "..."}` (el campo `typecheck` puede quedar vacío si el stack no
aplica). Esto es una detección manual **una sola vez** — todas las corridas siguientes del loop
lo reutilizan gratis vía `scripts/verify.sh`, en vez de que cada agente redetecte el stack.

## Scripts de orquestación (sin gastar razonamiento de agente)

Los pasos de este skill que son lógica determinística sobre output de `gh`/`git` — elegir
issue, resolver tier, cerrar el ciclo, ubicar candidatos/PR — están implementados como scripts
en `skills/agentic-dev-loop/scripts/` (solo `bash`+`gh`, sin dependencias externas). El
orquestador (sesión interactiva o, a futuro, un runner headless/cron) **ejecuta el script y usa
su output directo** — no le pide a un agente que "razone" estos pasos. Esto es la extensión de
**P1 (CLI > MCP)**: si un script determinístico alcanza, no gastar un agente en decidirlo.

| Script | Reemplaza | Contrato |
|---|---|---|
| `pick-next-issue.sh <owner>/<repo>` | Fase 1, Pasos 1+2 | stdout = número de issue elegido, ya marcado `in-progress` atómicamente (vacío si ninguno apto); prioriza `ready`+`bug` sobre el resto (fix antes que feat); corrige a `blocked` los `ready` con dependencia abierta |
| `resolve-tier.sh <owner>/<repo> <issue>` | Fase 1, Paso 3 | stdout = `haiku` \| `sonnet` \| `opus` |
| `open-pr.sh <owner>/<repo> <issue> <branch> <title> <body_file>` | Fase 1, Paso 4 (apertura de PR) | stdout = número de PR creado; `--base develop` hardcodeado (nunca cae al default branch del repo) y `Closes #<issue>` inyectado por el script (nunca reconstruido por el agente) |
| `close-cycle.sh <owner>/<repo> <issue>` | Fase 1, Paso 5 | aplica `review` si hay PR abierto con `Closes #N`, `ready` si no hay PR (ni abierto ni mergeado); si el único PR encontrado ya está mergeado, no toca ningún label (issue ya resuelto) |
| `find-review-candidates.sh <owner>/<repo>` | Fase 2, Paso 1 | stdout = JSON de issues `review` |
| `find-pr-for-issue.sh <owner>/<repo> <issue>` | Fase 2, Paso 2 | stdout = número de PR, abierto o mergeado (exit 1 si no hay ninguno) |
| `reject-review.sh <owner>/<repo> <issue>` | Fase 2, Paso 4 (veredicto "No pasa") | quita `review`, agrega `changes-requested`, reabre el issue si estaba `CLOSED`; el comentario con los hallazgos se publica antes, por separado (juicio del agente) |
| `verify.sh` | corridas sueltas de lint/typecheck/test | resumen corto pass/fail; solo muestra el fragmento de error si algo falla — nunca vuelca output crudo completo en éxito |

**Nota de diseño importante (descubierta validando `pick-next-issue.sh` contra un repo real):**
si el *default branch* del repo (el que dispara el autocierre de `Closes #N`) es distinto de la
rama de integración a la que mergean los PRs del loop (ej. default `main`, PRs a `develop`),
**el issue nunca se autocierra al mergear** y queda `OPEN` indefinidamente. Por eso ningún script
de este skill confía solo en `gh issue view N --json state` ni en buscar únicamente PRs
*abiertos*: `pick-next-issue.sh` busca también un PR *mergeado* con `Closes #N`
(`gh pr list --search "Closes #N" --state merged`) al resolver dependencias, y `close-cycle.sh`/
`find-pr-for-issue.sh` hacen lo mismo antes de asumir que un issue no tiene PR. Cualquier lógica
nueva que dependa de "¿está cerrado el issue N?" o "¿tiene PR el issue N?" debe usar el mismo
criterio doble (abierto O mergeado), no solo el estado del issue ni solo PRs abiertos.

---

## Fase 1 — Dev-runner (desarrollo, no supervisado)

### Paso 1 — Elegir issue y marcarlo in-progress
```bash
skills/agentic-dev-loop/scripts/pick-next-issue.sh <OWNER>/<REPO>
```
Si no imprime nada, no hay issue apto (ya hay uno `in-progress`, o ningún `ready` tiene sus
dependencias resueltas) — terminar esta fase. Si imprime un número, ese issue **ya quedó
marcado `in-progress`** por el propio script (atómico con la elección — cierra la ventana de
carrera que existía cuando "elegir" y "marcar" eran dos pasos separados); no hace falta ningún
`gh issue edit` adicional.

### Paso 3 — Resolver tier de modelo (D3 de la spec)
```bash
skills/agentic-dev-loop/scripts/resolve-tier.sh <OWNER>/<REPO> <N>
```
Default **Haiku**; escala a **Sonnet** si el body trae `**Complejidad:** alta` o si ya hay 1
comentario de bloqueo/fallo previo en el issue; a **Opus** si hay 2 o más.

### Paso 4 — Lanzar el agente de desarrollo
Prompt autocontenido (el agente parte de cero — sin memoria de esta sesión):
- Body completo del issue (ya trae objetivo, archivos, tareas RED→GREEN, DoD).
- Instrucción explícita de usar `skills/agentic-dev-loop/scripts/verify.sh` para lint/typecheck/
  test en cada iteración RED→GREEN, en vez de correr los comandos sueltos e ir volcando su
  output completo al contexto — el script ya resuelve los comandos desde
  `.agent/memory/session-stack.json` (Paso 0) y devuelve un resumen corto; solo muestra el
  fragmento de error si algo falla. Correr la suite completa (no acotada a archivos tocados)
  únicamente en la verificación final antes de commitear — es el gate real, pero no hace falta
  pagarlo completo en cada iteración intermedia.
- Instrucciones operativas:
  1. **Aislamiento por worktree (obligatorio si el orquestador es una sesión de Claude Code):**
     lanzar el agente de desarrollo con `isolation: "worktree"` en el Agent tool. El agente
     resultante ya parte de un working directory aislado (`git worktree` propio) y debe hacer
     `git fetch && git checkout develop && git pull && git checkout -b feature/issue-<N>-<slug-corto>`
     **dentro de ese worktree**, nunca en el checkout compartido del repo. Caso real que motiva
     esto: en otro proyecto que usa este harness, dos dev-runners corrieron sobre el mismo
     working directory (sin `isolation: "worktree"`) y el segundo (Issue #76) heredó estado sucio
     del primero (Issue #75), contaminando su rama con una entrada duplicada — se reparó a mano
     con un splice quirúrgico de bytes (ver Errores Comunes). Si el orquestador no es una sesión
     de Claude Code con el Agent tool disponible (ej. un futuro runner headless/cron, ver
     "Extensión futura" al final de este documento), debe garantizar el mismo aislamiento por
     otro medio antes de tocar `develop` — nunca compartir working directory entre dev-runners.
  2. Implementar **exactamente** las tareas listadas (RED→GREEN si el issue las trae así), sin
     tocar archivos fuera de la lista "Archivos" salvo que el DoD lo exija explícitamente.
  3. `verify.sh` debe quedar en verde antes de commitear (tests gateados por entorno real, ej.
     `@skipif`, se respetan tal cual están — no forzarlos a correr).
  4. Commit con mensaje convencional, push a la rama remota.
  5. Escribir el resumen de cambios a un archivo temporal y abrir el PR con
     `skills/agentic-dev-loop/scripts/open-pr.sh <OWNER>/<REPO> <N> <rama> "<título>" <archivo-resumen>`
     — el script fija `--base develop` (nunca cae al default branch del repo) e inyecta el
     keyword **literal en inglés** `Closes #<N>` él mismo, sin que el agente lo escriba. Esto
     reemplaza tanto el riesgo histórico de traducción del keyword (Issue #28 → PR #41,
     "Cierra #28" en vez de "Closes #28", ver Errores Comunes) como un segundo bug real
     encontrado después: un dev-runner corrió `gh pr create` sin `--base` explícito y el PR cayó
     contra `main` (el default branch del repo) en vez de `develop` (caso real Issues #75/#76,
     ver Errores Comunes) — con `open-pr.sh` ninguno de los dos es posible porque el agente nunca
     construye el comando a mano.
  6. Si en algún punto queda bloqueado (dependencia no resuelta que no se había detectado,
     ambigüedad real del DoD): **no commitear a medias** — comentar en el issue qué falta y
     terminar sin PR.

### Paso 4.5 — Smoke test post-implementación (opcional, ver ADR-010)

Punto de extensión, **no un paso obligatorio del loop**: si el issue recién implementado
tiene impacto en UI (heurística: tocó archivos de frontend/rutas/componentes) y
`agent-browser` está disponible en el proyecto, el dev-runner puede invocar
`skills/e2e-testing/SKILL.md` como smoke test antes de pasar a Paso 5 — valida que el flujo
crítico no se rompió, sin depender de que el usuario abra un navegador.

No se acopla el loop a esta dependencia externa: si `agent-browser` no está instalado, se
omite el smoke test y se continúa normalmente (ver `agents/browser-testing.md` → detección
de disponibilidad). Ver `docs/aura/adr/ADR-010-agent-browser-e2e-testing.md` para el
rationale completo de la capability.

### Paso 5 — Cerrar el ciclo
```bash
skills/agentic-dev-loop/scripts/close-cycle.sh <OWNER>/<REPO> <N>
```
Aplica automáticamente `review` (si encuentra PR abierto con `Closes #N`) o `ready` (si no) —
en el segundo caso, confirmar además que el agente dejó un comentario de bloqueo en el issue.

### Paso 5.5 — Registrar consumo (ambas fases)
Guardar tokens y tool-calls que reportó el agente (dev-runner y, más adelante, verifier) como
observación en Engram (`mem_save`, `project=<repo>`, ej. `type=pattern` con un tag de métricas)
para trackear si el costo por issue baja con las optimizaciones de este skill, o si conviene
revisar el enfoque antes de escalar el loop a más issues.

Este registro manual en Engram es complementario al mecanismo automático de observability
(Issues #103/#104): `session-end.ps1` captura cada sesión en `sessions-index.jsonl`, y
`skills/observability/scripts/process-session.sh` agrega `output_tokens`/`tool_uses`/
`duration_ms` en `sessions.jsonl` — histórico acumulado por sesión, no por issue. Al terminar
una corrida del loop, ofrecer al usuario "Ver reporte de consumo de esta corrida" (ver
`.aura/rules/routing-menu.md`) leyendo las entradas de `sessions.jsonl` correspondientes a las
sesiones de esta corrida.

---

## Fase 2 — Verifier (auditoría, nunca mergea sola)

Se dispara igual por cron que a demanda ("cerré/revisá el issue N").

### Paso 1 — Ubicar candidatos
```bash
skills/agentic-dev-loop/scripts/find-review-candidates.sh <OWNER>/<REPO>
```
O, si el usuario indica un issue puntual, usar ese directamente aunque no tenga el label
`review` todavía (caso "cerré el issue a mano, revisalo").

### Paso 2 — Ubicar el PR asociado
```bash
skills/agentic-dev-loop/scripts/find-pr-for-issue.sh <OWNER>/<REPO> <N>
```

### Paso 3 — Auditar (mismo método que un code review manual)
No confiar en el resumen del PR. Para cada tarea del DoD del issue:
1. Leer el diff real (`git diff develop..<rama> -- <archivos>` o `gh pr diff <N>`).
2. Confirmar que el comportamiento descrito existe en el código, no solo que se tocó el
   archivo correcto.
3. Correr `skills/agentic-dev-loop/scripts/verify.sh` localmente sobre la rama — mismo wrapper
   que usa la Fase 1, mismo resumen corto en vez de output crudo completo.
4. Listar hallazgos concretos (archivo, línea, qué falla) si algo no cumple.

### Paso 4 — Veredicto
- **Pasa (sin hallazgos bloqueantes):** comentar en el PR/issue "DoD cumplido, listo para
  mergear" con un resumen de lo verificado; notificar al usuario. **No mergear** — el usuario
  decide y ejecuta el merge.
- **No pasa:** comentar los hallazgos concretos (qué falta, con evidencia) con
  `gh issue comment <N>`, luego ejecutar
  `skills/agentic-dev-loop/scripts/reject-review.sh <OWNER>/<REPO> <N>` — el script aplica
  `changes-requested` y reabre el issue si estaba cerrado (cierre prematuro vía un merge que no
  debió pasar), sin que el agente reconstruya la secuencia de comandos.

---

## Regla de Concurrencia

Un solo issue `in-progress` por vez en todo el repo (Fase 1, Paso 1). La Fase 2 sí puede auditar
varios issues `review` en la misma corrida — auditar no muta código, solo lee y comenta.

---

## Errores Comunes

| Error | Solución |
|---|---|
| Dos labels de flujo en el mismo issue | Corregir a mano antes de la próxima corrida — señal de que algo pisó un label a mitad de camino |
| Issue `ready` con dependencia abierta | Corregir a `blocked`, no confiar en que el dev-runner lo detecte siempre |
| `gh` no autenticado en corrida programada (cron/headless) | Las integraciones autenticadas interactivamente pueden no estar disponibles en ejecuciones remotas — validar esto manualmente antes de programar el cron, no asumir que funciona igual que en sesión interactiva |
| El dev-runner abre PR pero no pushea (o viceversa) | Tratar como fallo — el issue debe quedar `ready`/`blocked` con comentario, nunca `review` sin PR real |
| Un issue "resuelto" (PR mergeado) queda `OPEN` indefinidamente | Pasa cuando el *default branch* del repo (el que dispara el autocierre de `Closes #N`) es distinto de la rama a la que mergean los PRs (ej. default `main`, loop mergea a `develop`). `pick-next-issue.sh` ya compensa esto buscando un PR *mergeado* además del estado del issue — no asumir que "issue closed" es la única señal válida de dependencia resuelta en ningún script/skill nuevo |
| `close-cycle.sh` corrompe un issue con `ready`+`review` a la vez | Ocurría al re-correrlo sobre un issue cuyo PR ya está mergeado (mismo gap del default branch, arriba): el script solo buscaba PRs *abiertos* con `Closes #N`, no encontraba nada, y devolvía el issue a `ready` encima del `review` que ya tenía. Se detectó corriendo el script contra el Issue #27 real. Fix: `close-cycle.sh` y `find-pr-for-issue.sh` ahora buscan también PRs *mergeados* antes de asumir que no hay ninguno; si encuentran uno mergeado, `close-cycle.sh` no toca ningún label y avisa que no debería haberse re-ejecutado sobre ese issue |
| `pick-next-issue.sh` marca una dependencia real como "no parseable" | El grep que ubica la sección "Depende de" no estaba anclado a inicio de línea, así que matcheaba cualquier ocurrencia de la frase en texto libre del body *antes* de llegar a la sección real (caso real: Issue #45 trae el criterio de aceptación "Ningún script depende de jq externo" antes de su `## Depende de`). Se detectó corriendo el loop contra la cadena #44-47 (Batch 1). Fix (PR #50): anclar el grep con `-E '^(#{1,6}[[:space:]]*|-[[:space:]]*\*\*)Depende de'`, que solo matchea el heading o el bullet canónico, no texto libre |
| Un issue con PR mergeado queda `OPEN` con label `review` sin que nada lo cierre | Consecuencia directa del gap de default branch (arriba): ni `close-cycle.sh` ni el verifier cierran el issue automáticamente tras un merge manual del usuario. Casos reales: Issue #44 tras PR #49, Issue #47/#62 tras PR #64/#63, Issue #71 tras PR #72 — todos cerrados a mano. Fix (Issue #74): `post-merge.sh <owner>/<repo> <issue_n> <pr_n>` verifica que el PR esté mergeado hacia `develop` y cierra el issue con el comentario estándar, de forma idempotente — invocado desde `agents/github.md` ("Al Mergear una PR a Develop") y `protocols/session_end.md` ("Post-merge a develop") |
| El dev-runner escribe el keyword de cierre traducido ("Cierra #N") en vez de literal ("Closes #N") | GitHub solo reconoce el keyword en inglés para el autocierre real al mergear, y `close-cycle.sh`/`find-pr-for-issue.sh` buscan ese mismo string — una traducción rompe ambas cosas aunque el resto del PR esté perfecto. Pasó con Issue #28 → PR #41 (memo-digital): el dev-runner tradujo el keyword pese a la instrucción explícita, `close-cycle.sh` no encontró el PR y devolvió el issue a `ready` con un PR real abierto. Fix aplicado: `close-cycle.sh` ahora tiene el mismo fallback por `headRefName` (`^feature/issue-N-`) que ya tenía `find-pr-for-issue.sh`, y avisa por stderr si el PR encontrado no traía el keyword esperado (para corregir el body a mano, GitHub no autocierra sobre el fallback). Fix estructural posterior: `open-pr.sh` (ver tabla de scripts) inyecta el keyword él mismo — el agente ya no lo escribe, así que no puede traducirlo |
| El dev-runner abre PR sin `--base` explícito y cae contra el default branch del repo (`main`) en vez de la rama de integración (`develop`) | Misma causa raíz que el gap de autoclose (arriba): el default branch del repo no es la rama a la que mergea el loop, y `gh pr create` sin `--base` usa el default branch por convención de `gh`. Caso real: Issues #75/#76 (otro proyecto con este harness), ambos dev-runners abrieron PR contra `main`; la auditoría (Fase 2) lo detectó y corrigió a mano antes de recomendar merge. Fix estructural: `open-pr.sh` hardcodea `--base develop`, no es parámetro — el agente no puede omitirlo porque nunca construye el comando |
| Dos dev-runners comparten working directory y el segundo hereda estado sucio del primero | Sin aislamiento, un `checkout develop && pull` de un dev-runner puede pisar/heredar una rama a medio commitear de una corrida anterior. Caso real: Issue #76 (otro proyecto con este harness) heredó el working directory de Issue #75 y su commit terminó con una entrada duplicada — se reparó a mano con un splice quirúrgico de bytes para no corromper un byte mal codificado preexistente en el archivo. Fix: lanzar cada dev-runner con `isolation: "worktree"` en el Agent tool (ver Fase 1, Paso 4, sub-paso 1) — cada uno parte de un working directory realmente aislado, no de una convención que el agente deba recordar |
| La rama local queda viva indefinidamente tras el merge | `post-merge.sh` cierra el issue pero nunca toca la rama local — queda acumulándose hasta que `session_start.md` (Paso 3, salud de ramas) la detecta pasivamente en una sesión posterior, o hasta una limpieza manual. Caso real: `crawler-mcp-diagram` (2026-08-03) acumuló 8 ramas locales + 10 remotas ya mergeadas sin que nada las hubiera limpiado antes de esa sesión. Fix: `cleanup-merged-branch.sh <owner>/<repo> <pr_n> [--delete]` (ver `agents/github.md`, "Al Mergear una PR a Develop", Paso 4) — dry-run por default, borra con `git branch -d` (nunca `-D`) solo tras confirmación explícita del usuario, invocado inmediatamente después de `post-merge.sh` en el mismo turno del merge en vez de esperar a la próxima sesión |

---

## Extensión futura — ejecutor intercambiable

El contrato de la Fase 1 es *"dado el body autocontenido de un issue → producir una rama + PR
que lo cierre"*. Cualquier backend de desarrollo automatizado que cumpla ese contrato podría
reemplazar al agente Haiku/Sonnet sin cambiar la Fase 2. Hoy el único ejecutor soportado es un
agente Claude vía la herramienta de agentes del entorno — no hay integración con otros
productos de desarrollo automatizado.
