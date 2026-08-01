# Agente GitHub — Ramas, Issues, PRs, Merge

> **Propósito:** Gestionar toda la operativa de Git y GitHub para mantener el flujo de trabajo ordenado.

---

## Responsabilidades

1. **Gestión de ramas** — crear, cambiar, eliminar, sincronizar
2. **Gestión de Issues** — crear, leer, actualizar, cerrar
3. **Gestión de PRs/MRs** — crear, revisar, merges
4. **Verificaciones de seguridad** — proteger ramas, validar identidad

---

## Reglas de Operación

### Ramas

| Tipo | Prefijo | Base | Ejemplo |
|------|---------|------|---------|
| Feature | `feature/` | develop | `feature/issue-42-agregar-login` |
| Fix | `fix/` | develop | `fix/issue-15-corregir-error` |
| Chore | `chore/` | develop | `chore/issue-8-actualizar-dependencias` |
| Hotfix | `hotfix/` | main | `hotfix/issue-99-security-patch` |

### Convenciones

- **Nunca commit directo** a develop o main
- **Ramas cortas** — máximo 1-2 días de trabajo
- **Antes de crear rama:** verificar que develop está actualizada

---

## Comandos常用

### Verificación de entorno
```bash
git branch --show-current           # Rama actual
git status --short                  # Estado rápido
git log --oneline -5                # Últimos commits
gh auth status                      # GitHub CLI
```

### Salud de ramas
```bash
# Ramas locales mergeadas en develop
git branch --merged develop | grep -v "^\*\|main\|develop"

# Ramas remotas mergeadas en origin/develop
git branch -r --merged origin/develop | grep -v "origin/HEAD\|origin/main\|origin/develop"

# Ramas locales sin remote
git branch -vv | grep ": gone]"
```

### Creación de rama

Invocar el script (no reconstruir en prosa — resuelve prefijo y base correctos según el tipo):

```bash
skills/agentic-dev-loop/scripts/new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>
```

`<type>` ∈ `feature|fix|chore` (base `develop`) o `hotfix` (base `main`). stdout imprime el
nombre de la rama creada. Falla explícitamente (exit 1) si la rama ya existe o el checkout falla.

---

## Salud del Repositorio

Verificar al inicio de sesión (Paso 3 de `protocols/session_start.md`).

### Checklist

| Check | Comando | Estado esperado |
|-------|---------|----------------|
| gh autenticado | `gh auth status` | Logged in |
| Visibilidad | `gh repo view --json visibility -q .visibility` | `PUBLIC` |
| main protegida | `gh api repos/{owner}/{repo}/branches/main/protection` | 200 OK |
| develop protegida | `gh api repos/{owner}/{repo}/branches/develop/protection` | 200 OK |

### Aplicar protección (si falta)

Invocar el script (no reconstruir el JSON en prosa — es una operación de seguridad real, alto
riesgo si se arma mal a mano):

```bash
skills/agentic-dev-loop/scripts/apply-branch-protection.sh <owner>/<repo> <branch>
```

Idempotente — correrlo repetido siempre deja la rama en el mismo estado deseado (`required_pull_request_reviews`
con 0 approvals obligatorios, `allow_force_pushes: false`, `allow_deletions: false`,
`dismiss_stale_reviews: true`).

### Hacer repo público (si privado y sin Pro)

```bash
gh repo edit {OWNER}/{REPO} --visibility public --accept-visibility-change-consequences
```

### Qué protege cada regla

| Regla | Protege contra |
|-------|---------------|
| `required_pull_request_reviews` | Push directo a la rama (obliga PR) |
| `allow_force_pushes: false` | `git push --force` que sobrescribe historia |
| `allow_deletions: false` | `git push origin :main` que borra la rama |
| `dismiss_stale_reviews: true` | Aprobaciones stale tras nuevos commits |

### Coherencia con el harness

| Regla harness | Enforcement GitHub | Enforcement harness |
|---------------|-------------------|---------------------|
| No push directo a main/develop | ✓ require PR | ✓ session_end verifica rama |
| No force push | ✓ allow_force_pushes: false | ✓ settings.json deny |
| Feature branch obligatoria | ✓ solo merges via PR | ✓ task_start crea rama |

---

## Hooks de Seguridad

### Pre-commit (obligatorio)
1. Verificar que NO estamos en develop o main
2. **Barrido de contenido sensible** — aplicar `.claude/rules/sensitive-data-safety.md`
   sobre `git diff --cached`. Si detecta algo → DETENER y seguir el flujo "Qué hacer al
   detectar" de esa regla, no continuar al commit.
3. Ejecutar linter (detectado según tecnología)
4. Ejecutar tests (detectados según tecnología)

### Pre-push
1. Verificar upstream branch
2. **Barrido de contenido sensible** — aplicar `.claude/rules/sensitive-data-safety.md`
   sobre los mensajes de commit de la rama (`git log develop..HEAD`) y el cuerpo del PR a
   crear/actualizar. Si detecta algo → DETENER y seguir el flujo "Qué hacer al detectar".
3. Confirmar que PR apunta a develop (no main)
4. No hacer force push a ramas compartidas

---

## Integración con Issue

1. **Cada rama = un issue**
2. **PR title = convencionales commits** (feat: ..., fix: ..., etc.)
3. **PR body referencia el issue** (`Closes #N`)
4. **Al mergear:** cerrar issue + mover en Project board

---

## Al Mergear una PR a Develop (obligatorio, NO depende de cierre de sesión)

> **Por qué existe esta regla:** la documentación de "qué se implementó" solía depender de
> que el usuario dijera una frase de cierre de sesión (`session_end.md`) — poco confiable en
> la práctica (sesiones que terminan sin frase de cierre no dejaban registro). Se movió el
> trigger al evento objetivo que el agente controla directamente: el merge mismo.

Inmediatamente después de un `gh pr merge` exitoso (o al confirmar que un PR ya fue
mergeado, aunque no lo haya mergeado esta sesión):

1. **Actualizar el ledger de planes** si el trabajo mergeado corresponde a un plan aprobado:
   buscar el archivo en `.agent/memory/plans/<fecha>-<slug>.md` y actualizar su frontmatter
   a `status: done`, `pr: #N`, `commit: <hash del merge>`, `completed_at: <fecha>`. Si no
   existe un plan formal para ese trabajo, omitir este paso (no crear uno retroactivo salvo
   pedido explícito).
2. **Append a `.agent/memory/project-log.md`** — agregar un bloque nuevo ARRIBA de todo
   (orden cronológico inverso), nunca editar bloques anteriores. Formato:
   ```
   ## {{FECHA}} — PR #{{N}} — {{título del PR}}

   **Plan:** {{path al ledger si existe, o "no hubo plan formal"}}
   **Qué se agregó:** 2-3 líneas en lenguaje de negocio — qué cambió para el usuario/proyecto,
   no un resumen técnico de diff.
   **Archivos clave:** lista breve (3-6 archivos) de lo más relevante.
   ```
3. **Verificar el merge y cerrar el issue asociado** invocando el script (no reconstruir en
   prosa — cubre el gap conocido de default branch `main` vs. `develop`, que hace que GitHub
   no autocierre el issue):
   ```bash
   skills/agentic-dev-loop/scripts/post-merge.sh <owner>/<repo> <issue_n> <pr_n>
   ```
   Es idempotente (si el issue ya está cerrado, no hace nada) y falla explícitamente (exit 1,
   sin cerrar el issue) si el PR no está mergeado o fue mergeado contra una rama distinta de
   `develop`.

Este paso es **independiente** de si la sesión se cierra formalmente — se ejecuta en el
momento del merge, dentro del mismo turno en que se confirma el merge.

---

## gh CLI vs MCP GitHub

**Prefiere gh CLI sobre MCP GitHub** — menor consumo de tokens.

| Método | Tokens por operación | Cuándo usar |
|--------|---------------------|-------------|
| `gh issue list` | ~50-100 | **Recomendado** — siempre |
| `gh pr create` | ~100-200 | **Recomendado** |
| MCP GitHub | ~500-1000 | Solo si requiere features específicas del MCP |

**Regla:** Usar `gh` directamente en Bash. El MCP de GitHub consume más tokens porque parsea el output y devuelve objetos complejos.

---

## Dependencias

- **gh CLI** — para operaciones GitHub (preferido sobre MCP)
- **git** — control de versiones

---

## Errores Comunes y Soluciones

| Error | Solución |
|-------|----------|
| "refusing to merge unrelated histories" | Usar `git pull --allow-unrelated-histories` |
| "branch is behind develop" | Rebase o merge de develop |
| "cannot push to protected branch" | Crear PR en lugar de push directo |
| "detached HEAD" | Crear rama desde el commit |

---

## output esperado

- Rama creada desde develop
- Issue referenciado en commits/PRs
- PR hacia develop (no main)
- Issue cerrado al merge