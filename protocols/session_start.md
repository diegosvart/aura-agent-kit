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
- **Ejecutar directamente paso 5** (mem_context) y luego paso 6 (resumen)
- **Repo health** (branch protection de main/develop) → omitir; solo ejecutar bajo demanda o
  una vez por semana
- Esto reduce las tool calls de ~10 a **2** (visibilidad + mem_context)
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

---

## Paso 5 — Memoria Engram (si MCP disponible)

```bash
mem_context(
  limit=10,
  project="{{PROJECT_NAME}}"
)
```

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
- **Pendiente:** <tareas de session.json>
- **Próximo paso:** <next_step>

## Issues Listos (label: ready)
| # | Título | Bloque |
|---|--------|--------|
| ... | ... | ... |

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