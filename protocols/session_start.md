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

## Paso 7 — Confirmar con Usuario y Derivar

Presentar al usuario la próxima acción recomendada y esperar su respuesta:

> "¿Continuamos con [next_step] o hay algo nuevo?"

**Según la respuesta, derivar:**

| Respuesta del usuario | Acción |
|-----------------------|--------|
| "Continuamos" / confirma next_step | Invocar `protocols/task_start.md` con el issue pendiente |
| "Algo nuevo" / describe trabajo nuevo | Invocar `/plan-work` → `skills/issue-planning/SKILL.md` |
| "Quiero ver el estado" / "revisemos" | Listar issues abiertos con `gh issue list --state open` y presentar opciones |
| No hay next_step ni issues ready | Invocar `/plan-work` automáticamente |

**Regla:** No comenzar trabajo sin que el usuario haya confirmado la dirección. Si hay issues con label `ready`, presentarlos como opciones antes de proponer trabajo nuevo.

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