# Protocolo — Session Start

> **Cuándo:** Al inicio de cada sesión de trabajo.
> **Obligatorio:** Sí.

---

## Paso 0 — Recuperar Contexto de la Sesión Anterior (obligatorio, bloqueante)

> **Por qué existe este paso primero:** la información de cierre de sesión (qué se hizo, qué
> quedó pendiente, sugerencias del agente) se guarda en cada cierre pero históricamente nunca
> llegaba de forma confiable al siguiente inicio — vivía solo en Engram (contenido rico de
> `mem_session_summary`), nunca en `current-session.json` (reducido a 3 campos desde ADR-006).
> Este paso corre **siempre**, incluso cuando el hook nativo del plugin de Engram ya inyectó
> contexto al inicio del turno — defensa en profundidad barata (una llamada MCP adicional):
> nunca se asume que la inyección de otra pieza de software funcionó esta vez. Ver
> `docs/aura/specs/2026-09-10-session-lifecycle-script-consolidation-design.md` para el
> rationale completo, incluyendo por qué no se reconstruye acá el mecanismo nativo del plugin
> de Engram (`scripts/session-start.sh`, matchers `startup|resume|clear|fork`) en vez de
> reemplazarlo.

1. `mem_context(project)` → identificar el `session_summary` más reciente.
2. `mem_get_observation(id)` sobre **ese mismo** — nunca conformarse con el preview de 300
   caracteres de `mem_context`. Extraer `Accomplished` (✅/🔲) y cualquier sugerencia/next-step
   explícito del agente en esa sesión. Afirmar "no hay next_step" sin haber hecho esta llamada
   es una violación de la regla de `.aura/rules/harness-core.md` de no afirmar estado sin
   verificar.
2.5. **Hora de red** (Issue #337): consultar `WebFetch` contra
   `https://timeapi.io/api/time/current/zone?timeZone=UTC`, extrayendo el datetime ISO 8601
   UTC. Si la consulta falla (sin red, API caída): usar el reloj local como fallback con
   advertencia explícita `⚠ Hora de red no disponible — usando reloj local (posible drift)`.
   Este timestamp se reporta en la tabla "1. Continuidad" del Paso 4, fila "Extraído ahora
   (UTC, hora de red)" — complementa el `Created:` de Engram, no lo reemplaza. Conversión a
   hora local: ver `AGENTS.local.md` → "Configuración Regional" → `Timezone (IANA)`; si el
   campo no existe, mostrar solo UTC con el aviso `⚠ Timezone no configurado en
   AGENTS.local.md — mostrando solo UTC` (nunca inferir por heurística).
3. Si `mem_context` falla (error de MCP) o no devuelve resultados → fallback a
   `.agent/memory/current-session.json` (si existe), usando sus 3 campos (`last_updated`,
   `branch`, `next_step`), con advertencia explícita:
   ```
   ⚠ Engram no disponible — mostrando puntero local de current-session.json (posiblemente desactualizado)
   ```
   Si tampoco existe `current-session.json`, continuar sin esa sección.
4. **Gate:** no se avanza al Paso 4 (Resumen Ejecutivo) sin haber completado este paso — con
   éxito o con el fallback declarado. Nunca en silencio.

---

## Paso 1 — Leer Contexto Local (obligatorio)

Leer en paralelo:
- `AGENTS.md` (este archivo, si no se cargó antes)
- `AGENTS.local.md` (raíz del proyecto, si existe) — **Read explícito obligatorio**: el `@import`
  automático de `CLAUDE.md` no resuelve archivos gitignorados de forma confiable. Este Read
  explícito es el fallback estructural de defensa en profundidad (mismo patrón de "dos capas"
  que usa el Paso 0 con Engram).
- `{{PROJECT_CONTEXT}}` (archivo de contexto del proyecto)
- `{{MATRIZ_PLANIFICACION}}` (si existe)
- `.agent/memory/repo-classification.json` (si existe) — `repo_type`: `harness` / `personal` /
  `cliente`. Si no existe, ver Gate de Clasificación de Repo en el Paso 3 — no asumir un default.
- `.agent/memory/current-session.json` (si existe)
- `.agent/memory/project-log.md` (si existe) — qué se agregó al proyecto en los últimos
  merges, independiente de si las sesiones anteriores cerraron formalmente
- `.agent/memory/objectives.md` (si existe) — Norte (largo plazo) vs ASAP (bloqueante ahora);
  se edita in-place, a diferencia de `project-log.md`
- `docs/adr/README.md` (decisiones arquitecturales)

### Chequeo de ubicación de `AGENTS.local.md`

`.aura/CLAUDE.md` carga la identidad local vía `@../AGENTS.local.md` — es decir, el
archivo debe vivir en la **raíz del proyecto consumidor**, no dentro de `.aura/`. Si no
existe `AGENTS.local.md` en la raíz pero sí existe `.aura/AGENTS.local.md`, el import
falla en silencio y la identidad del agente nunca carga. Verificar:

```bash
test -f AGENTS.local.md || test -f .aura/AGENTS.local.md && echo "ADVERTENCIA: AGENTS.local.md está en .aura/, no en la raíz — moverlo con: mv .aura/AGENTS.local.md AGENTS.local.md"
```

Si se detecta esta condición, incluirla en la sección "Advertencias" del Resumen Ejecutivo
(Paso 4) antes de continuar.

---

## Paso 2 — Gathering Determinístico (`session-start.ps1` extendido)

> **Nota de alcance:** este paso es sobre gathering de **git/gh/filesystem**, no sobre memoria
> Engram (eso ya se resolvió en el Paso 0, con un mecanismo distinto).

### Modos de Ejecución (Issue #322, D4 — piloto de delegación)

Dos opciones equivalentes para resolver este paso (ítems 1-17 abajo):

| Modo | Cuándo usarlo | Cómo |
|------|---------------|-----|
| **Automático (hook)** | Sesión con hooks del harness configurados y disparando | Hook `.claude/hooks/session-start.ps1` emite JSON; ver "Si el JSON del hook ya está disponible" más abajo |
| **Manual (línea por línea)** | Sesión sin hooks, o el JSON del hook no llegó | Ejecutar manualmente los comandos de la tabla; ver sección "Si el hook no disparó" más abajo |
| **Delegado (piloto)** | Optativo — para medir consumo de contexto de esta sesión | Lanzar un subagente que ejecuta `skills/session-lifecycle/scripts/gather-session-start.sh` y reformatea su JSON para el Resumen Ejecutivo; ver sección "Modo piloto: delegación a subagente" más abajo |

Todos los modos producen el mismo output final (datos 1-17 disponibles para los Pasos 3-4).
El usuario puede optar por el modo manual en sesiones sin hooks, o experimentar con delegación
en sesiones con hooks disponibles (para recolectar datos de comparación de contexto, Issue #322).

---

El hook `.claude/hooks/session-start.ps1` corre en los matchers `startup`/`resume`/`clear` y
emite un único JSON cubriendo los ítems 1-16 de la tabla siguiente. El ítem 17
(clasificación de repo) **todavía no está wireado al hook** — pese a documentarse acá como
parte del gathering automático, `session-start.ps1` no lo emite (confirmado por `git diff`:
el hook no tiene ninguna referencia a `repo-classification.json`, hallazgo del code-review de
PR #307). Hasta que se implemente, este ítem se resuelve **siempre** con el comando manual de
más abajo — no asumir que llega en el JSON del hook:

| # | Tarea | Mecanismo interno |
|---|-------|---------|
| 1 | Rama y estado de git | `git branch --show-current`, `git status --short`, `git diff --stat`, `git log --oneline -1/-3` |
| 2 | Config de hooks nativos | detecta `.githooks/`, setea `core.hooksPath` si falta |
| 3 | Init de submódulo `.aura` si quedó vacío | `git submodule status/update --init .aura` |
| 4 | Autenticación de GitHub | `gh auth status` |
| 5 | Nombre y topics del repo | `gh repo view --json name,repositoryTopics` |
| 6 | Visibilidad del repo | `gh repo view --json visibility` — alimenta el gate de datos sensibles (Paso 3) |
| 7 | Stash pendiente | `git stash list` |
| 8 | Salud de ramas | `git branch --merged develop`, `git branch -vv \| grep gone` |
| 9 | PRs abiertas | `gh pr list --state open --json number,title,headRefName,baseRefName,mergeable` |
| 10 | Issues `ready` | `gh issue list --label ready --state open --json number,title` |
| 11 | Detección de stack | busca `pyproject.toml`/`package.json`/`Cargo.toml`/`go.mod`; si no hay ninguno, `detected_stack: null` explícito (no un salteo silencioso) |
| 12 | `session-stack.json` existente | lee si ya fue confirmado antes |
| 13 | 5 scripts de repo-integrity | `check-release-drift.sh`, `check-repo-manifest.sh`, `check-base-branch.sh`, `check-orphaned-worktrees.sh`, `check-agent-frontmatter.sh` — stdout capturado, solo aparece si imprimieron algo (fail-silent) |
| 14 | Candidatos a trabajo stranded | ramas ahead de `develop` con commits `Closes/Fixes/Resolves #N` |
| 15 | Ideas en backlog | cuenta `## [` en `ideas.md` |
| 16 | Update del harness disponible | compara tag local de `.aura` vs. remoto (caché 30 min) o versión de plugin instalada vs. marketplace |
| 17 | Clasificación de repo (Issue #303, D1) — **NO implementado en el hook, ver nota arriba** | comando manual (`cat .agent/memory/repo-classification.json`, más abajo); alimenta el Gate de Clasificación de Repo (Paso 3) |

### Si el JSON del hook ya está disponible en el contexto

(campos como `branch`, `issues_ready`, `open_prs`, `repo_visibility`, `repo_integrity`,
`last_session`, `harness_update_available` presentes): usar esos datos directamente para el
Paso 3 y el Paso 4 — no repetir ninguna de las llamadas de la tabla de arriba.

### Si el hook no disparó

```bash
# Rama, estado, commits
git branch --show-current
git status --short
git log --oneline -5

# GitHub CLI
gh auth status --hostname github.com 2>&1 || echo "gh: no autenticado"

# Stash
git stash list

# Visibilidad del repo (si gh autenticado)
gh repo view --json visibility -q .visibility

# PRs abiertas (si gh autenticado)
gh pr list --state open --json number,title,headRefName,baseRefName,mergeable --limit 20

# Issues ready (si gh autenticado)
gh issue list --label ready --state open --json number,title,labels --limit 20

# Salud de ramas (actualizar develop primero — Issue #214)
git fetch origin develop --quiet
git branch --merged develop | grep -v "^\*\|main\|develop"
git branch -r --merged origin/develop | grep -v "origin/HEAD\|origin/main\|origin/develop"
git branch -vv | grep ": gone]"
git remote prune origin --dry-run

# 5 scripts de repo-integrity (fail-silent si no imprimen nada)
bash skills/repo-integrity/scripts/check-release-drift.sh
bash skills/repo-integrity/scripts/check-repo-manifest.sh
bash skills/repo-integrity/scripts/check-base-branch.sh
bash skills/repo-integrity/scripts/check-orphaned-worktrees.sh
bash skills/repo-integrity/scripts/check-agent-frontmatter.sh agents/*.md | grep -v "^OK:" || true

# Clasificación de repo (Issue #303, D1)
cat .agent/memory/repo-classification.json 2>/dev/null || echo "repo_classification: null"
```

### Worktrees Adicionales (Issue #200 — regla anti-worktree, no cubierto por el hook)

```bash
git worktree list
```

Si devuelve más de una entrada (el checkout activo cuenta como una): reportar cada worktree
adicional en el Resumen Ejecutivo (sección Advertencias del Paso 4) y **proponer** su
eliminación (`git worktree remove <path>`), con confirmación del usuario antes de ejecutar —
ver `agents/github.md` → "Regla anti-worktree" para el criterio completo. No aplica al
worktree que la sesión de background actual esté usando para su propio aislamiento (mecanismo
de la plataforma, no del harness) — solo a worktrees adicionales/huérfanos detectados junto al
checkout activo.

### Repo Health (branch protection)

Chequeo de protección de `main`/`develop` (`gh api repos/{{OWNER}}/{{REPO}}/branches/.../protection`)
→ **omitir por defecto**; solo ejecutar bajo demanda o una vez por semana. No forma parte del
gathering de rutina de este paso.

---

### Modo piloto: delegación a subagente (Issue #322, D4)

**Régimen experimental** (no es el default): si el orquestador quiere medir el impacto en
consumo de contexto de delegar el Paso 2 completo a un subagente (en vez de ejecutar 17 comandos
crudos e inyectar su output), puede optar por este modo:

**Precondición:** El JSON del hook nativo está disponible, O el orquestador está dispuesto a
ejecutar la versión manual — se necesita alguno de los dos para proceder.

**Flujo:**
1. Ejecutar (o recibir del hook): todos los datos de la tabla 1-17 de alguna forma.
2. **Si se opta por delegación:** Lanzar un subagente con el siguiente contrato autocontenido:
   - **Input:** el número/nombre del repo (o auto-detectar desde cwd).
   - **Tarea:** Ejecutar el script `skills/session-lifecycle/scripts/gather-session-start.sh
     <owner>/<repo>` una sola vez.
   - **Output:** Capturar su JSON, parsear los campos, y devolver al orquestador un resumen ya
     formateado (mismo shape que el Resumen Ejecutivo espera para el Paso 4 — no JSON crudo).
3. El subagente NO ejecuta comandos adicionales ni razona comando por comando — solo corre el
   script una sola vez y reformatea su output.

**Métrica de éxito:** tokens de contexto del orquestador consumidos durante esta sesión,
registrados en `.agent/memory/observability/sessions.jsonl` (automático al cierre, Paso 10 de
`session_end.md`). Comparar contra el promedio de sesiones recientes sin piloto activado para
medir reducción. Ver `docs/aura/specs/2026-09-18-fase2-marco-024-025-026-028-design.md` (D4)
para el objetivo completo.

**Nota:** Este modo es optativo y experimental — no reemplaza el flujo manual/hook existente.
Se documenta acá para que el usuario pueda activarlo en sesiones posteriores si lo desea.
Mediciones reales solo ocurren en sesiones siguientes donde se active efectivamente.

---

## Paso 3 — Gates (usa datos del Paso 2)

### Gate de Clasificación de Repo (Issue #303, D1)

Usar el dato del ítem 17 del Paso 2 (`.agent/memory/repo-classification.json`).

Si el archivo **no existe** (`repo_classification: null`) → **DETENER aquí**. No mostrar el
Resumen Ejecutivo (Paso 4) ni el Capability Menu (Paso 6) hasta que el usuario responda.
Preguntar textualmente:

> "Este repo todavía no tiene clasificación de memoria
> (`.agent/memory/repo-classification.json`). ¿Es `harness` (el harness mismo o un fork
> directo), `personal` (proyecto propio, sin terceros con acceso) o `cliente` (un tercero
> tiene o puede tener acceso)?"

Con la respuesta, crear el archivo:

```json
{
  "repo_type": "<harness|personal|cliente>",
  "classified_at": "<timestamp UTC actual>",
  "classified_by": "manual"
}
```

No asumir un default ni inferir por heurística — ver D1 en
`docs/aura/specs/2026-09-17-memoria-clasificacion-repos-design.md`. Si el archivo **sí
existe**, continuar sin preguntar y mostrar `repo_type` en la sección "Estado real — mío" del
Resumen Ejecutivo (Paso 4).

`repo_type` alimenta además la política de qué puede guardar `mem_save` en este repo — ver
`.aura/rules/memory-classification.md` (Issue #303, D3, enforcement capa 1).

### Gate de Trabajo Stranded (si `gh` autenticado)

Usar los candidatos del ítem 14 de la tabla del Paso 2 (ramas ahead de `develop` con commits
`Closes/Fixes/Resolves #N`). Invocar `skills/repo-integrity/SKILL.md`, que clasifica cada rama
vía `skills/repo-integrity/scripts/classify-branch.sh <owner>/<repo> <rama>` (no reconstruir el
algoritmo en prosa).

Si se detecta trabajo stranded → **DETENER aquí**. No mostrar el Resumen Ejecutivo (Paso 4) ni
el Capability Menu (Paso 6) hasta que el usuario resuelva. Ver `.aura/rules/repo-integrity.md`
para el criterio completo.

### Gate de Datos Sensibles (si `visibility == public`, del ítem 6 del Paso 2)

Si la visibilidad es **pública** y el proyecto maneja datos de un cliente real
(heurística: existe `output/` gitignored, o config local-only en `config/*.json`
gitignored, o el objetivo del proyecto es reverse-engineering de una BD real) →
**DETENER aquí, antes del Paso 4.** No presentar el resumen ejecutivo ni el Paso 6 hasta
que el usuario responda.

Preguntar textualmente:
> "El repo es **público** y este proyecto maneja datos de un cliente real. ¿Confirmás que
> no hay datos sensibles versionados, o preferís pasarlo a privado ahora
> (`gh repo edit --visibility private`)?"

Ver `.claude/rules/sensitive-data-safety.md` para el catálogo completo de qué cuenta
como sensible. Registrar la respuesta del usuario en la sección "Advertencias" del
Resumen Ejecutivo (Paso 4).

### Advertencias Condicionales (del ítem 13 del Paso 2 — repo-integrity)

Cada uno de los 4 scripts solo produce una línea si encuentra algo — silencioso si no imprime
nada (mismo patrón para los cuatro, no mostrar bloque vacío):

- **Drift de Release** (`check-release-drift.sh`): línea `DRIFT: ...` → incluirla tal cual en
  "Advertencias", con la acción sugerida: aplicar el sync-back de `agents/github.md` →
  "Proceso de Release". Ver Issue #120 y PR #119 para el caso real que lo motivó.
- **Integridad del Manifest** (`check-repo-manifest.sh`): líneas `MISSING: ...` /
  `MISPLACED: ...` → incluirlas tal cual. Ver ADR-007 y `skills/repo-integrity/manifest.txt`.
- **PRs contra la Rama Base Incorrecta** (`check-base-branch.sh`): líneas `BASE-BRANCH: ...` →
  incluirlas tal cual. Detecta PRs `feature/*`/`fix/*`/`chore/*` que apuntan contra `main` en
  vez de `develop` (excluyendo el PR legítimo de `promote` de `cut-release.sh`). Caso real: PR
  #159.
- **Worktrees Huérfanos** (`check-orphaned-worktrees.sh`): líneas `ORPHANED-WORKTREE: ...` →
  incluirlas tal cual, con la acción sugerida ya embebida en cada línea. No borra nada, solo
  informa. Caso real: sesión 2026-09-02, 3 worktrees acumulados sin limpiar.
- **Frontmatter de Agentes** (`check-agent-frontmatter.sh`): líneas `NO-FRONTMATTER: ...` /
  `MISSING-FIELD: ...` / `BAD-DESCRIPTION-PATTERN: ...` → incluirlas tal cual, con la acción
  sugerida "agregar/corregir frontmatter YAML (`name`/`description`/`tools`) en el archivo
  indicado, ver `agents/github.md` como referencia de formato". Gate creado en el PR de Issue
  #231 pero nunca wireado a ningún hook ni CI — quedó huérfano hasta Issue #285, que lo conectó
  acá.

---

## Paso 3.5 — Reporte de Observability de la Sesión Anterior (fail-open)

Procesa entradas pendientes del índice de sesiones y muestra un resumen compacto de la
sesión anterior, antes del Resumen Ejecutivo. Es **fail-open**: si el script falla, no
existe `.aura/` (proyecto sin observability habilitada), o no hay datos, se omite en
silencio — nunca bloquea el resto del protocolo.

```bash
bash skills/observability/scripts/process-session.sh 2>/dev/null || true
```

Si `.agent/memory/observability/sessions.jsonl` existe y tiene al menos una línea, leer la
**última** línea (la sesión más reciente procesada) y mostrar antes del Resumen Ejecutivo:

```
## Sesión Anterior
- Tokens de salida: <output_tokens>
- Tool uses: LLM <n> · Script/Comando <n> · Delegado a agente <n> · Otro <n>
- Duración: <duration_ms convertido a min:seg, o "—" si es null>
- Delegation rate: <ver formato exacto abajo>
```

La línea "Delegation rate" (Issue #179) toma `delegation_rate.a`/`.b`/`.rate` de la entrada
correspondiente en `sessions.jsonl`. Formato exacto de la línea completa:

- Si `a > 0`: `Delegation rate: <b>/<a> (<rate>) — ver .aura/rules/subagent-dispatch.md`
- Si `a == 0`: `Delegation rate: — (sin triggers detectados) — ver .aura/rules/subagent-dispatch.md`
  (reemplaza la línea entera, no solo el paréntesis — no dividir por cero)

Mostrar siempre los valores crudos `a`/`b` junto al cociente cuando `a > 0` — un `a` bajo (0 o
1) hace que el ratio no sea representativo por sí solo (ver "Salvaguarda" en
`.aura/rules/subagent-dispatch.md`).

Si el archivo no existe, está vacío, o el script devolvió error → omitir esta sección por
completo (no mostrar un bloque vacío ni un mensaje de error).

---

## Paso 3.6 — Patrones de Errores de Proceso (fail-open)

Mismo patrón fail-open que el Paso 3.5. Cuenta `.agent/memory/observability/process-errors.jsonl`
(idea [021], Issue #206 — ver `.aura/rules/process-error-log.md`) agrupado por `tipo` dentro de
las últimas 10 sesiones distintas:

```bash
bash skills/observability/scripts/check-process-errors.sh 2>/dev/null || true
```

Si el script imprime una o más líneas `PROCESS-ERROR-PATTERN: <tipo> apareció <n> veces en las
últimas 10 sesiones — considerar /auto-research`, incluirlas tal cual en la sección
"Advertencias" del Resumen Ejecutivo (Paso 4) — mismo umbral cualitativo (3+) que ya usa el
Paso 10 de `protocols/session_end.md`, sin inventar un segundo criterio.

Si el archivo no existe, está vacío, o ningún `tipo` llega a 3+ ocurrencias → omitir esta
sección por completo (no mostrar un bloque vacío ni un mensaje de error).

---

## Paso 4 — Resumen Ejecutivo (3 preguntas raíz, formato obligatorio)

> Las 8 secciones del formato anterior (Estado del Entorno, Repositorio, Salud de Ramas,
> Última Sesión, Issues Listos, PRs Abiertas, Ideas en Backlog, Advertencias) no se eliminan
> ni se resumen — se **reagrupan** bajo 3 preguntas raíz. Ningún dato se pierde, solo cambia
> el agrupamiento visual.

**Mapeo sección anterior → pregunta raíz:**

| Pregunta raíz | Secciones que responde | Fuente |
|---|---|---|
| 1. Continuidad — ¿dónde lo dejé? | "Última Sesión" (Pendiente, Próximo paso) | Paso 0 (Engram, bloqueante) |
| 2. Estado real — ¿en qué condición está todo, mío y ajeno? | "Estado del Entorno", "Repositorio", "Salud de Ramas", "Issues Listos", "PRs Abiertas", "Advertencias" (gates + drift + manifest + worktrees huérfanos) | Paso 2 (script) + Paso 3 (gates) |
| 3. Próximo movimiento — ¿qué es lo más razonable hacer ahora? | "Ideas en Backlog", "Próxima Acción Recomendada", Stack de sesión, Capability Menu | Paso 2 (script) + Paso 5/6 |

**Formato de salida:**

```
## 1. Continuidad — ¿dónde lo dejé?
| Campo | Valor |
|---|---|
| Pendiente (última sesión) | <de session_summary #ID, texto completo, no preview> |
| Próximo paso sugerido | <next_step> |
| Fuente | Engram (#ID) / fallback current-session.json |
| Sesión anterior cerrada (UTC, hora de red) | <de la línea "Cierre (UTC, hora de red): ..." dentro de mem_session_summary, o current-session.json.last_updated si Engram no la tiene> |
| Extraído ahora (UTC, hora de red) | <timestamp del ítem 2.5 del Paso 0, o aviso de fallback a reloj local> |

## 2. Estado real — mío
| Check | Estado |
|---|---|
| git / gh / engram | ✓/✗ (detallar cuál si alguno falla) |
| Repo | <repo_name> — topics: <lista o "sin topics"> |
| Clasificación (Issue #303) | <repo_type: harness/personal/cliente> |
| Branch | <nombre> |
| Sin rastrear | N archivos |
| Cambios sin commit | N |
| Último commit | <hash> "<mensaje>" |

### Herramientas MCP
| Nombre | Ubicación (config) | Objetivo | Cargada en contexto |
|---|---|---|---|
| <nombre> | <archivo/sección de config> | <una línea> | ✓ / ✗ (deferred) |

> Fuente "configuradas": `.claude/settings.json` (`permissions.allow`, `enabledPlugins`) —
> estático, no cambia salir del Paso 2, delegable a un subagente de solo lectura si el volumen
> lo justifica (`.aura/rules/subagent-dispatch.md`). Fuente "cargada en contexto": el
> `<system-reminder>` de deferred tools de esta sesión — **no delegable**, es estado vivo del
> orquestador. Nota conocida (Issue #337, inventario 2026-09-21): un MCP server puede llegar
> por instalación **global** del usuario (ej. Engram vía `~/.claude/plugins/`) sin aparecer en
> `enabledPlugins` de este repo — en ese caso listar igual la tool (aparece en
> `permissions.allow`) con la ubicación real de su config, no asumir que "no está en
> settings.json" == "no configurada".

### Hooks activos
| Nombre | Ubicación (config) | Matcher/Evento | Objetivo |
|---|---|---|---|
| <nombre> | `.claude/settings.json` → `<bloque>` | <matcher> | <una línea> |

> Los hooks no tienen columna "cargada en contexto" — no son tools invocables, corren
> automáticamente en cada evento.

## 2. Estado real — ajeno / repo
| Check | Estado |
|---|---|
| Ramas para limpiar | N (detalle si aplica) |
| Worktrees adicionales | N |
| Issues ready | N (tabla #/título si N>0) |
| PRs abiertas | N (tabla #/título/rama/base si N>0) |
| Gates (datos sensibles / stranded / drift / manifest / base-branch) | ✓ limpio / ⚠ detalle |

## 3. Próximo movimiento
| Opción | Detalle |
|---|---|
| Recomendada | <issue/acción concreta> |
| Ideas en backlog | N (omitir fila si 0) |
| Stack activo | <perfil> |
```

Cierre del resumen, línea nueva (capa de visibilidad, no de enforcement):
```
✓ Contexto previo recuperado (Paso 0) · N chequeos obtenidos por script (Paso 2) · 0 gathering manual
```

### Formato de conversión de hora de red a timezone local (Issue #337)

Cada timestamp de red mostrado en la tabla "1. Continuidad" (`Sesión anterior cerrada`,
`Extraído ahora`) agrega entre paréntesis la conversión a `Timezone (IANA)` de
`AGENTS.local.md`:

```
2026-09-21T22:14:11 UTC (19:14:11 America/Santiago)
```

Si `AGENTS.local.md` no tiene el campo `Timezone (IANA)`: mostrar solo el valor UTC + el
aviso `⚠ Timezone no configurado en AGENTS.local.md — mostrando solo UTC` (una sola vez en
Advertencias, no repetido por cada fila).

### Advertencias — casos especiales a incluir cuando aplican

- Si `harness_update_available: true` (del hook), incluir una sola línea en "Gates" o como
  fila de la tabla "Estado real — ajeno / repo":
  - **Canal `submodule`** (ausente o `"submodule"`):
    `⚠ Harness vX.Y.Z disponible (actual: vA.B.C) — /harness-update para detalle`
    (`X.Y.Z` = `harness_latest_version`, `A.B.C` = versión local actual del harness)
  - **Canal `plugin`** (`harness_update_channel == "plugin"`):
    `⚠ Harness vX.Y.Z disponible (actual: vA.B.C) — actualizar con: claude plugin update {{plugin_id}}`
    (`{{plugin_id}}` = `harness_update_plugin_id`)
  - El detalle completo del CHANGELOG **no se vuelca** en el resumen — solo aparece al correr
    `/harness-update` o `claude plugin update` explícitamente. Ambos canales son mutuamente
    excluyentes por construcción en el hook.
- Si `harness_update_check_error` viene presente en el JSON del hook, incluir:
  `⚠ Chequeo de actualización del harness no pudo ejecutarse: <harness_update_check_error>`
  (distingue "se chequeó, no hay update" de "el chequeo nunca corrió" — Issue #111)
- Si `aura_submodule_initialized: true` (del hook):
  `⚠ .aura estaba sin inicializar — se corrió 'git submodule update --init .aura' automáticamente`
- Si `git worktree list` devuelve más de una entrada (Paso 2): una línea por worktree
  adicional detectado y la propuesta de limpieza — ver `agents/github.md` → "Regla
  anti-worktree"

---

## Paso 5 — Stack de Sesión

Determinar el stack tecnológico antes de presentar el menú:

**5a — Detección automática:** usar `detected_stack` del Paso 2 (ítem 11) si el hook disparó;
si no, buscar en la raíz del proyecto:
```
pyproject.toml / setup.py  → Python
package.json               → Node.js / TypeScript
Cargo.toml                 → Rust
go.mod                     → Go
```

Si se detecta → mostrar: `Stack detectado: [lenguaje/framework]. ¿Correcto? [S/n]`

**5b — Sin detección:** Invocar `skills/stack-selection/SKILL.md` (lista de 24 perfiles).

**5c — Ya existe `.agent/memory/session-stack.json`:** Leer (`session_stack` del Paso 2, ítem
12, si el hook disparó) y confirmar con el usuario que sigue siendo válido.

Una vez confirmado, el stack queda disponible para todos los pasos siguientes.

---

## Paso 6 — Capability Menu

Presentar el menú contextual. Incluir solo las secciones que aplican:

```
## ¿Qué hacemos hoy?

**Stack activo:** [nombre del perfil detectado o seleccionado]

### Continuar trabajo          ← solo si hay issues con label `ready`
  ✓ Issue #N — [título]
  ✓ Issue #M — [título]

### Nuevo trabajo
  📋 Planificar nuevas tareas       → /plan-work
  💡 Brainstorm de idea             → /brainstorm
  🚀 Crear proyecto desde cero      → wizard nuevo proyecto

### Calidad y documentación
  📖 Verificar documentación        → /doc-check
  🔍 Code review                    → /request-review
  ✅ Cerrar rama lista              → /finish-branch

### Investigación y mejora
  🔬 Auto-research del harness      → /auto-research
  🐛 Debug de problema              → systematic-debugging
  🔧 Cambiar stack de sesión        → /stack

> Escribí el número del issue, el nombre de la opción, o describí qué querés hacer.
```

**Tabla de derivación:**

| Respuesta del usuario | Acción |
|-----------------------|--------|
| Número de issue / "continuamos" | Invocar `protocols/task_start.md` con el issue |
| "Planificar" / "algo nuevo" / describe trabajo | Preguntar: "¿Tenés un diseño o spec previa?" → Si sí: `/plan-work`. Si no: recomendar `/brainstorm` primero |
| "Brainstorm" | Invocar `/brainstorm` |
| "Proyecto nuevo" / "desde cero" | Invocar stack-selection → wizard de estructura inicial |
| "Doc-check" / "documentación" | Invocar `/doc-check` |
| "Review" / "code review" | Invocar `/request-review` |
| "Cerrar rama" / "finish" | Invocar `/finish-branch` |
| "Auto-research" | Invocar `/auto-research` |
| "/stack" / "cambiar stack" | Invocar `skills/stack-selection/SKILL.md` |
| No hay issues ready ni next_step | Invocar `/plan-work` automáticamente |

**Regla:** No comenzar trabajo sin que el usuario haya confirmado la dirección.

---

## Reglas

1. **No ejecutar nada** hasta que el usuario apruebe la acción
2. **Presentar siempre el resumen** aunque sea sesión nueva
3. **Verificar herramientas** antes de operar
4. **Si no hay contexto previo**: crear estructura de memoria

---

##Errores Comunes

| Error | Solución |
|-------|----------|
| gh no autenticado | Sugerir `gh auth login` |
| Engram no disponible | Continuar sin Engram (fallback declarado en Paso 0) |
| current-session.json no existe | Crear estructura básica |
| Rama sucia | Preguntar si quieres limpiar |
