# Protocolo — Session Start

> **Cuándo:** Al inicio de cada sesión de trabajo.
> **Obligatorio:** Sí.

---

## Paso 1 — Leer Contexto (obligatorio)

Leer en paralelo:
- `AGENTS.md` (este archivo, si no se cargó antes)
- `{{PROJECT_CONTEXT}}` (archivo de contexto del proyecto)
- `{{MATRIZ_PLANIFICACION}}` (si existe)
- `.agent/memory/current-session.json` (si existe)
- `docs/adr/README.md` (decisiones arquitecturales)

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

## Próxima Acción Recomendada
**Issue #N** — [título]
Rama sugerida: `{{TIPO}}/{{CODIGO}}-{{descripcion}}`

## Advertencias
> ⚠ [Si hay problemas claros]
```

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
| "Planificar" / "algo nuevo" / describe trabajo | Invocar `/plan-work` |
| "Brainstorm" | Invocar `/brainstorm` |
| "Proyecto nuevo" / "desde cero" | Invocar stack-selection → wizard de estructura inicial |
| "Doc-check" / "documentación" | Invocar `/doc-check` |
| "Review" / "code review" | Invocar `/request-review` |
| "Cerrar rama" / "finish" | Invocar `/finish-branch` |
| "Auto-research" | Invocar `/auto-research` |
| "Debug" | Activar `skills/systematic-debugging/SKILL.md` |
| "/stack" / "cambiar stack" | Invocar `skills/stack-selection/SKILL.md` |
| No hay issues ready y no hay next_step | Invocar `/plan-work` automáticamente |

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