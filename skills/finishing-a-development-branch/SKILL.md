---
name: finishing-a-development-branch
description: Use when all tasks in a branch are complete and you're ready to close the work
---

# Finishing a Development Branch

## Overview

When all tasks are complete, verify the branch is ready and offer options for next steps.

## When to Use

- All tasks in the plan are done
- Tests pass
- Code review approved (if applicable)

## Pre-Finish Checklist

- [ ] All tests pass
- [ ] Linter clean
- [ ] No debug code
- [ ] Changes committed
- [ ] Branch is up to date with base

## Health Check

```bash
# Verify tests pass
pytest tests/ -v

# Verify linter passes  
ruff check .

# Check branch status
git status

# Verify no untracked files that should be tracked
git diff --stat
```

## Pre-PR: Escribir ADR

**Cuándo:** Después del Health Check, antes de `gh pr create` (Opción 1) — en la misma rama,
como parte del mismo commit o uno separado.

**Obligatorio para:** ramas `feat/*` y `docs/*`.
**Opcional para:** ramas `chore/*` y `fix/*` menores (a criterio del agente — un fix de una
línea no necesita ADR; un fix que cambia comportamiento documentado sí).

Pasos:

1. Determinar si el tipo de rama activa la obligación (prefijo `feat/`, `docs/`, `chore/`,
   `fix/` — ver tabla de tipos en `agents/github.md`).
2. Si aplica (obligatorio, u opcional y el agente decide que agrega valor):
   - Copiar `docs/aura/adr/ADR-TEMPLATE.md` a `docs/aura/adr/ADR-NNN-<slug>.md` (`NNN` =
     siguiente número disponible, ver `docs/aura/adr/ADR-000-registro.md`).
   - Completar los 6 campos del template. Si el campo **Problema** no se puede completar con
     claridad, es señal de que la funcionalidad no debería haberse implementado así — revisar
     antes de forzar el ADR.
   - Agregar la fila correspondiente a `docs/aura/adr/ADR-000-registro.md`.
   - Commitear el ADR en la misma rama (mismo commit del cambio o uno separado tipo
     `docs(adr): ADR-NNN <título>`).
3. Si no aplica (chore/fix menor sin ADR): continuar sin bloquear el flujo.

Ver infraestructura completa: `docs/aura/adr/ADR-TEMPLATE.md`, `docs/aura/adr/ADR-000-registro.md`.

## Present Options

After verification, present to user:

```markdown
## Branch Ready: [branch-name]

**Status:** ✅ All checks passed

### Options:

1. **Create PR** → Merge to develop
   - Creates pull request with conventional title
   - Links to issue if applicable
   - Triggers CI if configured

2. **Commit & Push** → Keep branch for later PR
   - Commits all changes
   - Pushes to remote
   - Branch stays open for more work

3. **Squash commits** → Clean history
   - Combines all commits into one
   - Clean history in main/develop

4. **Discard branch** → Start fresh
   - Branch deleted locally and remotely
   - Only if work is not needed

5. **Request Review** → Solicitar code review formal
   - Invoca pre-review con `agents/reviewer.md`
   - Luego abre review request en la PR con `/request-review`
   - Recomendado antes de merge a develop en proyectos de equipo

### Recommendation: [X]
**Reason:** [based on context]
```

## Common Actions

### Option 1: Create PR
```bash
# Antes: si el tipo de rama lo requiere, completar "Pre-PR: Escribir ADR" y commitear
gh pr create --base develop --fill
```

### Option 2: Push Branch
```bash
git push -u origin branch-name
```

### Option 3: Squash
```bash
git rebase -i HEAD~N  # N = number of commits
```

### Option 4: Discard (with confirmation)
```bash
git branch -d branch-name
git push origin --delete branch-name
```

### Option 5: Request Review
```bash
# Pre-review con reviewer agent
# Leer agents/reviewer.md para checklist de calidad

# Luego asignar reviewer a la PR
gh pr edit <PR_NUMBER> --add-reviewer <REVIEWER>
# O usar /request-review skill
```

## Post-PR: Task Checkpoint

**Cuándo:** Inmediatamente después de confirmar que la PR fue creada o mergeada (Opción 1).  
**Obligatorio:** Sí — corre siempre, no es condicional.

Ejecutar `protocols/task-checkpoint.md` en orden:

1. `mem_session_summary` — guardar resumen de la tarea completada en Engram
2. Actualizar `.agent/memory/current-session.json` — `next_step` apuntando al próximo trabajo
3. Evaluar señales de contexto extenso y sugerir `/compact` si corresponde

Ver protocolo completo: `protocols/task-checkpoint.md`

---

## Remember

- Always verify before presenting options
- Don't assume user's preference - ask
- Be ready to explain each option
- If Option 1 (Create PR) is chosen, always offer Option 5 (Request Review) as next step
- After PR is confirmed → always run `protocols/task-checkpoint.md`