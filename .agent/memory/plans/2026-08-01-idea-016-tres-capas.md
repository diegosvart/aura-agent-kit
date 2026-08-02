---
status: done
approved_at: 2026-08-01
done_at: 2026-08-01
---

# Plan — Idea [016]: 3 capas restantes del barrido de scripting determinístico

## Contexto

Continuación de la idea [016] (`.agent/memory/ideas.md`) tras implementar `classify-branch.sh`
(Issue #71/PR #72) y `post-merge.sh` (Issue #74/PR #75) en esta misma sesión. Quedan 3 ítems:
`apply-branch-protection.sh`, `new-branch-for-issue.sh`, y git hooks nativos. El usuario pidió
explícitamente: "limpiar el repo" = validar y reportar estado (nunca merge automático), y
"proseguir en looping" = implementar los 3 ítems restantes secuencialmente sin pausar entre cada
uno para pedir confirmación.

Decisión clave tomada en esta sesión sobre los git hooks (antes descartados en Tier 1 por
requerir setup manual): usar el hook `SessionStart` de Claude Code (`.claude/hooks/session-start.ps1`,
ya versionado y auto-cargado) para setear `core.hooksPath` automáticamente — elimina el paso
manual que motivó dejarlos fuera de Tier 1, sin agregar fricción al flujo del usuario.

## Alcance

### 1. `skills/agentic-dev-loop/scripts/apply-branch-protection.sh <owner>/<repo> <branch>`

Encapsula el heredoc JSON de `agents/github.md:78-96`:
```json
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false
}
```
Vía `gh api -X PUT repos/<owner>/<repo>/branches/<branch>/protection --input -`. PUT es
idempotente por naturaleza (siempre fija el estado deseado). stdout: confirmación con el estado
aplicado. stderr + exit 1 si `gh api` falla. Reemplaza el bloque "Aplicar protección (si falta)"
en `agents/github.md`.

### 2. `skills/agentic-dev-loop/scripts/new-branch-for-issue.sh <owner>/<repo> <issue_n> <type> <slug>`

`type` ∈ `feature|fix|chore|hotfix` (tabla de `agents/github.md:20-25`). Resuelve prefijo y rama
base (`hotfix`→`main`; el resto→`develop`), valida `type` contra la lista (error claro si no
matchea), hace `git fetch origin <base> && git checkout <base> && git pull origin <base>` y
`git checkout -b <type>/issue-<issue_n>-<slug>`. stdout: nombre de la rama creada. stderr + exit
1 si la rama ya existe o el checkout falla. Reemplaza el bloque de creación de rama en
`agents/github.md` y la referencia en `protocols/task_start.md`.

### 3. Git hooks nativos con auto-setup

- **`.githooks/pre-push`** (nuevo, bash, shebang `#!/usr/bin/env bash`): lee stdin con el formato
  estándar de `pre-push` (`<local ref> <local sha1> <remote ref> <remote sha1>`), rechaza
  (exit 1) si `<remote ref>` es `refs/heads/develop` o `refs/heads/main` — mismo set protegido
  que `git-guard.ps1` (`.claude/hooks/git-guard.ps1:64`).
- **`.claude/hooks/session-start.ps1`**: agregar chequeo idempotente al inicio — si
  `git config --get core.hooksPath` no devuelve `.githooks`, ejecutar
  `git config core.hooksPath .githooks` y loguear la acción (mismo estilo fail-open que
  `git-guard.ps1`, no debe romper el hook si falla).
- **`skills/harness-update/scripts/apply-update.sh`**: extender la sincronización (hoy solo
  copia `.claude/hooks/*.ps1`, ver líneas 39-57) para copiar también `.githooks/pre-push` al
  repo consumidor — evita repetir el gap de packaging ya corregido en Tier 1 (Issue #66,
  `integrations/claude-code/settings.json` sin sección `hooks`).

## Verificación (sin test suite formal, mismo patrón que Issues #71/#74)

- shellcheck limpio en los 3 scripts nuevos.
- `apply-branch-protection.sh`: correr contra `develop` de este repo, confirmar que el resultado
  de `gh api .../protection` sigue coincidiendo con lo ya verificado en session_start (force_push
  false, deletions false, require_pr true) — no debe romper la protección existente.
- `new-branch-for-issue.sh`: crear una rama de prueba real (`chore/issue-<N>-test`), confirmar
  base correcta y limpiar.
- `.githooks/pre-push`: simular con un push de prueba a una rama no protegida (debe pasar) y
  confirmar el rechazo del caso `develop`/`main` sin depender de un push real (revisar la lógica
  contra el formato stdin documentado de Git, o probar con `GIT_TEST` en una rama descartable).
- `session-start.ps1`: correr y confirmar `git config --get core.hooksPath` queda en `.githooks`
  tras una corrida limpia (sin el valor seteado de antes).

## Flujo de trabajo

Por cada ítem: Issue → rama `feature/issue-N-...` desde `develop` → implementación →
verificación → commit (`Closes #N`) → push → PR vía `open-pr.sh` (sin merge — el usuario decide
qué mergear). Se repiten los 3 ítems en secuencia sin pausar a pedir confirmación entre cada uno
("looping"). Al final, reportar tabla de estado (issues/PRs abiertos) para que el usuario decida
merges.

## Archivos críticos

- `agents/github.md` — reemplazo de los 2 bloques de prosa (protección, creación de rama)
- `protocols/task_start.md` — referencia a `new-branch-for-issue.sh`
- `.claude/hooks/session-start.ps1` — auto-setup de `core.hooksPath`
- `.claude/hooks/git-guard.ps1` — fuente de verdad del set `protected` a replicar en `.githooks/pre-push`
- `skills/harness-update/scripts/apply-update.sh` — extensión de sincronización
- Precedentes de estilo: `skills/repo-integrity/scripts/classify-branch.sh`,
  `skills/agentic-dev-loop/scripts/post-merge.sh`
