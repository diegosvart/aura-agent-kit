# Protocolo — Session Start

> **Cuándo:** Al inicio de cada sesión de trabajo.
> **Obligatorio:** Sí.

---

## Hook Fast-Path (leer primero)

Si el contexto ya contiene el JSON del hook `session-start.ps1` (campos `branch`, `issues_ready`, `last_session`, `harness_update_available`, `harness_latest_version` presentes):

- **Saltear pasos 2, 3 y 4** — los datos ya están disponibles en el hook output
- **Excepción:** correr igual `gh repo view --json visibility -q .visibility` y aplicar el
  **Gate de datos sensibles** (ver Paso 3 → "Salud del Repositorio") — es una sola llamada
  barata y protege contra el escenario que motivó esa regla; no se salta ni con hook output
  presente
- **Excepción:** correr igual `gh pr list --state open` (ver Paso 4 → "PRs Abiertas") — el
  hook no trae este dato y una PR abierta es la señal más directa de trabajo a un paso de
  cerrarse; no se salta ni con hook output presente (ver Issue #109 — el gap real que
  motivó este paso: una PR abierta quedó invisible en el resumen porque nada en el fast-path
  ni en el hook la consultaba)
- **Ejecutar directamente paso 5** (mem_context) y luego paso 6 (resumen)
- **Repo health** (branch protection de main/develop) → omitir; solo ejecutar bajo demanda o
  una vez por semana
- Esto reduce las tool calls de ~10 a **3** (visibilidad + PRs abiertas + mem_context)
- **Nota:** El hook también inyecta `harness_update_available` (boolean) y `harness_latest_version` (string); ver Paso 6 para cómo mostrar la línea de aviso

Si el hook output NO está presente → ejecutar el protocolo completo desde el Paso 2.

---

## Paso 1 — Leer Contexto (obligatorio)

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

Si se detecta esta condición, incluirla en la sección "Advertencias" del resumen ejecutivo
(Paso 6) antes de continuar.

---

## Paso 2 — Estado del Entorno

Ejecutar (según sistema operativo):

```bash
# Rama actual
git branch --show-current
git status --short

# Últimos commits
git log --oneline -5

# GitHub CLI
gh auth status --hostname github.com 2>&1 || echo "gh: no autenticado"

# Stash
git stash list

# Engram (si está disponible)
where engram 2>nul || echo "engram: no disponible"
```

---

## Paso 3 — Salud de Ramas (obligatorio)

Detectar ramas que requieren limpieza:

```bash
# Ramas locales ya mergeadas en develop
git branch --merged develop | grep -v "^\*\|main\|develop"

# Ramas remotas ya mergeadas en origin/develop
git branch -r --merged origin/develop | grep -v "origin/HEAD\|origin/main\|origin/develop"

# Ramas locales sin remote (gone)
git branch -vv | grep ": gone]"

# Verificar referencias obsoletas
git remote prune origin --dry-run
```

Incluir en el resumen si hay ramas que requieren limpieza.

### Integridad Repo-Remote (si gh autenticado)

Ejecutar solo si `gh auth status` pasó en Paso 2.

Invocar `skills/repo-integrity/SKILL.md` con la lista de ramas candidatas (las que tienen commits ahead de develop). El skill clasifica cada rama vía `skills/repo-integrity/scripts/classify-branch.sh <owner>/<repo> <rama>` (no reconstruir el algoritmo en prosa).

Si se detecta trabajo stranded → **DETENER aquí**. No continuar al Paso 4 hasta que el usuario resuelva.

### Salud del Repositorio (si gh autenticado)

Ejecutar solo si `gh auth status` pasó en Paso 2:

```bash
# Visibilidad del repo
gh repo view --json visibility -q .visibility

# Protección de main
gh api repos/{{OWNER}}/{{REPO}}/branches/main/protection \
  --jq '{force_push: .allow_force_pushes.enabled, deletions: .allow_deletions.enabled, require_pr: (.required_pull_request_reviews != null)}' \
  2>/dev/null || echo "main: sin protección"

# Protección de develop
gh api repos/{{OWNER}}/{{REPO}}/branches/develop/protection \
  --jq '{force_push: .allow_force_pushes.enabled, deletions: .allow_deletions.enabled, require_pr: (.required_pull_request_reviews != null)}' \
  2>/dev/null || echo "develop: sin protección"
```

Incluir en el resumen ejecutivo (Paso 6) con este formato:

```
## Salud del Repositorio
| Check             | Estado                                |
|-------------------|----------------------------------------|
| Visibilidad       | private ✓  / public ⚠ (requiere confirmación) |
| main protegida    | ✓ require PR, no force push           |
| develop protegida | ✓ require PR, no force push           |
```

Si algún check falla → sugerir el comando exacto para corregirlo (ver `agents/github.md`).

### Drift de Release (main vs. develop)

Chequeo local, no requiere `gh` — corre siempre que existan ambas ramas:

```bash
bash skills/repo-integrity/scripts/check-release-drift.sh
```

Si imprime una línea `DRIFT: ...` → incluirla tal cual en la sección "Advertencias" del
Resumen Ejecutivo (Paso 6), con la acción sugerida: aplicar el sync-back de
`agents/github.md` → "Proceso de Release" antes de continuar. Si no imprime nada, no
mostrar ninguna línea (chequeo silencioso, igual que "PRs Abiertas" cuando la lista viene
vacía no se omite el paso, pero acá sí se omite la línea si no hay hallazgo — es una
advertencia condicional, no un estado a reportar siempre).

Ver Issue #120 y PR #119 (aura-agent-kit) para el caso real que motivó este chequeo: un
consumidor externo actualizó `.aura` a `develop` en vez de a un tag exacto y recibió una
versión reportada incorrecta porque el tag había quedado fuera de la ancestría de `develop`.

#### Gate de datos sensibles (si `visibility == public`)

Si la visibilidad es **pública** y el proyecto maneja datos de un cliente real
(heurística: existe `output/` gitignored, o config local-only en `config/*.json`
gitignored, o el objetivo del proyecto es reverse-engineering de una BD real) →
**DETENER aquí, antes del Paso 6.** No presentar el resumen ejecutivo ni el Paso 6 hasta
que el usuario responda.

Preguntar textualmente:
> "El repo es **público** y este proyecto maneja datos de un cliente real. ¿Confirmás que
> no hay datos sensibles versionados, o preferís pasarlo a privado ahora
> (`gh repo edit --visibility private`)?"

Ver `.claude/rules/sensitive-data-safety.md` para el catálogo completo de qué cuenta
como sensible. Registrar la respuesta del usuario en la sección "Advertencias" del
resumen ejecutivo.

---

## Paso 4 — Issues Listos (si aplica)

```bash
gh issue list \
  --repo {{OWNER}}/{{REPO}} \
  --label ready --state open \
  --json number,title,labels \
  --limit 20
```

### PRs Abiertas (obligatorio, si `gh` autenticado)

Ejecutar siempre, con o sin hook fast-path (ver excepción en "Hook Fast-Path" arriba). Una
PR abierta es la señal más directa de trabajo pendiente — más cercana a cerrarse que un
issue `ready` sin código todavía — y ningún otro paso del protocolo la detecta: Paso 3 solo
mira ramas ya mergeadas/huérfanas o *stranded* (issue cerrado sin PR), nunca PRs con issue
todavía abierto (el caso normal).

```bash
gh pr list \
  --repo {{OWNER}}/{{REPO}} \
  --state open \
  --json number,title,headRefName,baseRefName,mergeable \
  --limit 20
```

Incluir el resultado en el resumen ejecutivo (Paso 6), sección "PRs Abiertas". Si la lista
viene vacía, mostrar "✓ Sin PRs abiertas" en esa sección — no omitirla, para que quede claro
que se verificó y no que se saltó el chequeo.

---

## Paso 5 — Memoria Engram (si MCP disponible)

```bash
mem_context(
  limit=10,
  project="{{PROJECT_NAME}}"
)
```

### Fallback — Engram no disponible o sin resultados

> **Desde ADR-006:** `current-session.json` existe únicamente para este caso — es un puntero
> local no versionado (gitignored), nunca la fuente primaria.

Si `mem_context` falla (error de MCP) o devuelve vacío: leer `.agent/memory/current-session.json`
(si existe) y usar sus 3 campos (`last_updated`, `branch`, `next_step`) para poblar la sección
"Última Sesión" del Resumen Ejecutivo (Paso 6), en vez de dejarla vacía. Incluir en
"Advertencias":
```
⚠ Engram no disponible — mostrando puntero local de current-session.json (posiblemente desactualizado)
```
Si tampoco existe `current-session.json`, continuar sin esa sección (comportamiento actual).

---

## Paso 5.5 — Reporte de Observability de la Sesión Anterior (fail-open)

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
```

Si el archivo no existe, está vacío, o el script devolvió error → omitir esta sección por
completo (no mostrar un bloque vacío ni un mensaje de error).

---

## Paso 6 — Resumen Ejecutivo (formato obligatorio)

```
## Estado del Entorno
| Herramienta | Estado | Nota |
|-------------|--------|------|
| git         | ✓/✗   | versión |
| gh          | ✓/✗   | autenticado o error |
| engram      | ✓/✗   | disponible o no |

## Repositorio
- **Branch:** <nombre>
- **Sin rastrear:** N archivos
- **Cambios sin commit:** N
- **Último commit:** <hash> "<mensaje>"

## Salud de Ramas
> Si hay ramas sucias: mostrar tabla con acción sugerida
> Si todo limpio: "✓ Ramas limpias"

## Última Sesión
- **Pendiente:** <tareas — de Engram (Paso 5); si Engram no disponible, del puntero local current-session.json>
- **Próximo paso:** <next_step>

## Issues Listos (label: ready)
| # | Título | Bloque |
|---|--------|--------|
| ... | ... | ... |

## PRs Abiertas
> Si hay PRs abiertas: tabla `# | Título | Rama | Base | Mergeable`
> Si no hay: "✓ Sin PRs abiertas"

## Ideas en Backlog
> N ideas — revisar con `/ideas` o abrir `.agent/memory/ideas.md`
> (Si ideas_count == 0: omitir esta sección)

## Próxima Acción Recomendada
**Issue #N** — [título]
Rama sugerida: `{{TIPO}}/{{CODIGO}}-{{descripcion}}`

## Advertencias
> ⚠ [Si hay problemas claros]
> ⚠ Si `harness_update_available: true` (del hook), incluir una sola línea:
>   `⚠ Harness vX.Y.Z disponible (actual: vA.B.C) — /harness-update para detalle`
>   (sustituyendo X.Y.Z por `harness_latest_version` y A.B.C por la versión local actual del harness)
> ⚠ Si `harness_update_check_error` viene presente en el JSON del hook, incluir una sola línea:
>   `⚠ Chequeo de actualización del harness no pudo ejecutarse: <harness_update_check_error>`
>   (distingue "se chequeó, no hay update" de "el chequeo nunca corrió" — Issue #111)
```

### Nota sobre la línea de aviso de actualización del harness

Si el hook `session-start.ps1` inyecta `harness_update_available: true`, incluir en la
sección "Advertencias" del Resumen Ejecutivo una sola línea con el formato exacto:

```
⚠ Harness vX.Y.Z disponible (actual: vA.B.C) — /harness-update para detalle
```

**Importante:**
- Sustituir `X.Y.Z` con el valor de `harness_latest_version` (del hook)
- Sustituir `A.B.C` con la versión local actual del harness (de `version.txt` o similar)
- Esta línea va **siempre en la sección "Advertencias"**, no como bloque separado
- El detalle completo del CHANGELOG **NO se vuelca** en el resumen ejecutivo — solo aparece
  al correr `/harness-update` explícitamente
- Esto evita repetir el mismo bloque de texto sesión tras sesión mientras el usuario no actualiza

---

## Paso 7 — Stack de Sesión

Determinar el stack tecnológico antes de presentar el menú:

**7a — Detección automática:**
```
Buscar en la raíz del proyecto:
  pyproject.toml / setup.py  → Python
  package.json               → Node.js / TypeScript
  Cargo.toml                 → Rust
  go.mod                     → Go
```

Si se detecta → mostrar: `Stack detectado: [lenguaje/framework]. ¿Correcto? [S/n]`

**7b — Sin detección:** Invocar `skills/stack-selection/SKILL.md` (lista de 24 perfiles).

**7c — Ya existe `.agent/memory/session-stack.json`:** Leer y confirmar con el usuario que sigue siendo válido.

Una vez confirmado, el stack queda disponible para todos los pasos siguientes.

---

## Paso 8 — Capability Menu

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
| Engram no disponible | Continuar sin Engram |
| current-session.json no existe | Crear estructura básica |
| Rama sucia | Preguntar si quieres limpiar |