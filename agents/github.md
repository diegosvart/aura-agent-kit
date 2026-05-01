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
```bash
git checkout develop && git pull origin develop
git checkout -b feature/issue-N-description
```

---

## Hooks de Seguridad

### Pre-commit (obligatorio)
1. Verificar que NO estamos en develop o main
2. Ejecutar linter (detectado según tecnología)
3. Ejecutar tests (detectados según tecnología)

### Pre-push
1. Verificar upstream branch
2. Confirmar que PR apunta a develop (no main)
3. No hacer force push a ramas compartidas

---

## Integración con Issue

1. **Cada rama = un issue**
2. **PR title = convencionales commits** (feat: ..., fix: ..., etc.)
3. **PR body referencia el issue** (`Closes #N`)
4. **Al mergear:** cerrar issue + mover en Project board

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