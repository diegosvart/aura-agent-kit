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
- `{{PROJECT_CONTEXT}}` (archivo de contexto del proyecto)
- `{{MATRIZ_PLANIFICACION}}` (si existe)
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

El hook `.claude/hooks/session-start.ps1` corre en los matchers `startup`/`resume`/`clear` y
emite un único JSON cubriendo estos 16 ítems:

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
| 13 | 4 scripts de repo-integrity | `check-release-drift.sh`, `check-repo-manifest.sh`, `check-base-branch.sh`, `check-orphaned-worktrees.sh` — stdout capturado, solo aparece si imprimieron algo (fail-silent) |
| 14 | Candidatos a trabajo stranded | ramas ahead de `develop` con commits `Closes/Fixes/Resolves #N` |
| 15 | Ideas en backlog | cuenta `## [` en `ideas.md` |
| 16 | Update del harness disponible | compara tag local de `.aura` vs. remoto (caché 30 min) o versión de plugin instalada vs. marketplace |

**Si el JSON del hook ya está disponible en el contexto** (campos como `branch`,
`issues_ready`, `open_prs`, `repo_visibility`, `repo_integrity`, `last_session`,
`harness_update_available` presentes): usar esos datos directamente para el Paso 3 y el Paso 4
— no repetir ninguna de las llamadas de la tabla de arriba.

**Si el hook no disparó** (sesión sin hooks configurados, o el JSON no llegó): ejecutar
manualmente los comandos equivalentes:

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

# 4 scripts de repo-integrity (fail-silent si no imprimen nada)
bash skills/repo-integrity/scripts/check-release-drift.sh
bash skills/repo-integrity/scripts/check-repo-manifest.sh
bash skills/repo-integrity/scripts/check-base-branch.sh
bash skills/repo-integrity/scripts/check-orphaned-worktrees.sh
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

## Paso 3 — Gates (usa datos del Paso 2)

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

## 2. Estado real — mío
| Check | Estado |
|---|---|
| git / gh / engram | ✓/✗ (detallar cuál si alguno falla) |
| Repo | <repo_name> — topics: <lista o "sin topics"> |
| Branch | <nombre> |
| Sin rastrear | N archivos |
| Cambios sin commit | N |
| Último commit | <hash> "<mensaje>" |

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
