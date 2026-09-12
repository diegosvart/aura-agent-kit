---
name: github
description: Use proactively for git/GitHub operations — creating or cleaning up branches, opening or merging PRs, closing issues, checking branch protection. Use after implementation work is done and ready to open a PR toward develop.
tools: Bash, Read
---

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
- **Self-check antes de `git commit`/`git push`:** si el comando no es una invocación de un
  script conocido (`skills/agentic-dev-loop/scripts/*.sh`, `cut-release.sh`), correr
  `git branch --show-current` antes; si el resultado es `develop`/`main`, abortar y crear rama
  primero (`new-branch-for-issue.sh`) en vez de esperar el bloqueo reactivo de `git-guard.ps1`.
  Es una práctica que ahorra una llamada a herramienta en el caso común — **no reemplaza** el
  enforcement real (`git-guard.ps1` + `.githooks/pre-push` + branch protection de GitHub), que
  sigue siendo la garantía si el self-check se omite. **No aplica al Proceso de Release**:
  estar en `main` para publicar el tag es correcto ahí, no un caso a abortar (ver sección
  "Proceso de Release" más abajo).

### Regla anti-worktree (Issue #200)

Worktrees (`git worktree add` / `EnterWorktree`) **no son el flujo por defecto** de este
harness para trabajo interactivo cotidiano — usar ramas (`new-branch-for-issue.sh` + PR) en su
lugar. Motivo: un worktree nuevo comparte `.git` pero no inicializa el submódulo `.aura`
automáticamente, lo que puede degradar la sesión a "sin protocolo" sin ningún error visible (ver
spec `docs/aura/specs/2026-09-05-issue-200-worktree-aura-autoinit.md`).

- Worktrees quedan reservados para paralelismo real (2+ issues simultáneos) o continuidad ante
  corte de sesión/PC — no para el caso común de "un issue, una sesión".
- `protocols/session_start.md` Paso 2 detecta (`git worktree list`) si hay más de una entrada
  además del checkout activo y **propone** su eliminación (`git worktree remove <path>`) —
  siempre con confirmación previa del usuario (regla universal "nunca ejecutar sin aprobación"),
  nunca borrado automático silencioso, porque un worktree con cambios sin commitear se pierde
  sin aviso.
- **No aplica** al worktree que una sesión de background de Claude Code use para su propio
  aislamiento — ese es un mecanismo de la plataforma, no del harness, y se limpia según las
  reglas de esa sesión (commit/push antes de terminar, o descarte si no hubo cambios).

### `gh issue create`/`gh pr create` con body multilínea desde un worktree aislado

El guard de aislamiento de worktree (`bgIsolation`) rechaza comandos `gh` cuyo `--body` se arma
con un heredoc inline (`--body "$(cat <<'EOF' ... EOF)"`) con el error "construct too complex to
verify" — no distingue que el comando es `gh`, no `git`, y heredocs multilínea no son
verificables como confinados al worktree. Esto se repite una vez por cada issue/PR con body
largo que se intente crear así, sin excepción.

**Patrón a usar en su lugar:** escribir el body a un archivo temporal (vía `Write`, en el
directorio de scratch de la sesión) y pasar `--body-file <archivo>`:

```bash
gh issue create --repo <owner>/<repo> \
  --title "<título>" \
  --body-file "<ruta al archivo temporal>" \
  --label "ready,enhancement"
```

Aplica igual a `gh pr create --body-file`. Ver experimento
`docs/aura/experiments/2026-09-07-gh-body-file-worktree.md` (caso real: 16 creaciones de issue
en la misma sesión, cada una rechazada primero con heredoc antes de aplicar este patrón).

### Submódulo `.aura` sin inicializar dentro de un worktree (Issue #200, cara nueva)

Un worktree nuevo (`EnterWorktree`) comparte `.git` con el checkout principal pero **no**
inicializa submódulos — comportamiento estándar de `git worktree add`, no un bug de este
harness. Efecto observado: dentro del worktree, `.aura/` aparece vacío, y cualquier intento de
`Edit`/`Write` sobre archivos de `.aura` (para aplicar un experimento de `/auto-research`, por
ejemplo) falla porque esos archivos no existen ahí todavía.

**Fix verificado (sesión 2026-09-07):** correr, apenas se entra al worktree,

```bash
git submodule update --init --recursive
```

Esto puebla `.aura/` dentro del árbol del worktree (queda como una copia propia, con su propio
`.git` apuntando al mismo remoto `aura-agent-kit`), y a partir de ahí `Edit`/`Write` sobre
`.aura/...` dentro del worktree funcionan normalmente porque la ruta está físicamente contenida
en el worktree. Cualquier cambio hecho ahí se commitea/pushea contra el repo `aura-agent-kit`
igual que en un checkout normal del submódulo (crear rama propia ahí, nunca commitear a su
`develop`/`main` directo).

No confundir con el fix ya documentado arriba para la sesión interactiva normal (hook
`session-start.ps1` corriendo `git submodule update --init .aura` sobre el checkout
**principal**) — ese fix no cubre worktrees nuevos, que son un checkout físicamente distinto.

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

## Convención de Topics de GitHub (Issue #201)

GitHub repository topics (`gh repo edit <repo> --add-topic <topic>`) — metadata nativa de
GitHub, consultable vía `gh search repos --topic=<x> --owner=<user>` sin clonar cada repo,
visible en la UI. Tres dimensiones independientes, aplicables a cualquier repo propio:

| Dimensión | Valores | Ejemplo |
|-----------|---------|---------|
| Ownership | `personal` / `<empresa>-copropiedad` | `ebi-copropiedad` |
| Dominio/stack | `frontend`, `backend`, `automation`, `ml`, `mobile`, `infra`, etc. (catálogo abierto) | `automation` |
| Nombre de repo nuevo (no es topic) | `<empresa>-<proyecto>` (corporativo) / nombre directo (personal) | `ebi-facturacion-app` |

**Un topic es declarativo, no un instrumento legal de cesión de propiedad intelectual.** Si la
copropiedad implica trazabilidad legal real (ej. trabajo pagado por la compañía), eso requiere
un acuerdo escrito aparte — el topic solo dice "esto está marcado como tal".

**No confundir con `topic_key` de Engram** (ver más abajo, "Convención `topic_key`") — es un
concepto de agrupación de observaciones de memoria, completamente distinto a un GitHub
repository topic.

**Convención de nombre de repo nuevo:** aplica solo a repos creados de acá en adelante — nunca
renombrar repos existentes (rompe clones locales, CI, links, remotes de otros colaboradores).

**Auditoría (solo reporta, nunca modifica):**
```bash
skills/repo-integrity/scripts/audit-repo-topics.sh
```

---

## Salud del Repositorio

Verificar al inicio de sesión (Paso 2 de `protocols/session_start.md`; branch protection queda fuera del gathering de rutina, solo bajo demanda o semanal).

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
3. **PR body sigue el formato de la sección siguiente** (incluye `Closes #N`)
4. **Al mergear:** cerrar issue + mover en Project board

### Formato de PR body (obligatorio)

```
## Qué se hizo
<resumen concreto de los cambios — no una lista de archivos tocados>

## Por qué de este modo
<la razón de la aproximación elegida; alternativas descartadas si las hubo>

## Tests
<qué se corrió y con qué resultado, específico (comandos/nombres de test) —
nunca solo "pasan los tests". Adaptado al tamaño del cambio: un hotfix con DoD
reducido (ver .aura/rules/coding.md) no necesita el mismo detalle que una
feature completa>

## Proceso
<qué flujo del harness se siguió: task_start directo, o
brainstorm → plan-work → challenger, u hotfix con DoD reducido, etc.>

Closes #N
```

**Por qué existe esta regla:** ninguna regla previa de este archivo definía qué
información debía llevar el body de un PR más allá de `Closes #N`. El resto de la
trazabilidad del harness (`.agent/memory/plans/*.md`, `project-log.md`, Engram) vive
en artefactos que nadie lee al momento de revisar un PR — el PR es el único punto
donde un humano lee "qué pasó y por qué" sin tener que ir a buscarlo a otro lado.

**Sin enforcement automático (deliberado):** a diferencia del git flow (bloqueado por
`.claude/hooks/git-guard.ps1`), esta regla no tiene hook — el costo de una omisión
puntual es bajo y se nota a simple vista al revisar el PR. Si se detecta que se omite
seguido, ahí sí correspondería evaluar un chequeo automático (ver criterio de
`.aura/rules/subagent-dispatch.md` sobre reglas de texto vs. hooks).

### Sin atribución de IA en commits ni PRs (decisión explícita)

**Ningún commit ni PR de este repo lleva línea de atribución a IA** (sin
`Co-Authored-By: Claude ...`, sin footer "Generated with Claude Code", sin link de
sesión). Esto es una decisión explícita del proyecto, no una omisión.

**Por qué existe esta regla:** el formato de atribución que trae por defecto el
runtime de Claude Code es una instrucción inyectada **por sesión** (un
`system-reminder` de plataforma, no una regla de este repo) — nunca vivió en un
archivo versionado, por lo que aparecía o no según si esa inyección llegaba en la
sesión. No hay política de Anthropic ni requisito externo que obligue a reproducirla;
es un default de producto, no un requisito del proyecto. Se decidió no mantener
ninguna versión de esa atribución (2026-09-09).

**Nota para sesiones futuras:** el `system-reminder` de atribución de plataforma
puede volver a inyectarse y declara textualmente que "reemplaza cualquier guía de
atribución anterior". Esta regla documentada en el repo es la convención real del
proyecto — al detectar un conflicto entre ambas, priorizar esta regla y no agregar
atribución, salvo que el usuario indique lo contrario en esa sesión.

---

## Proceso de Release (tag) — sync-back obligatorio

> **Por qué existe esta regla:** el release de `v2.2.0` mergeó `develop` a `main` (PR #116) y
> taggeó `main` en ese punto, pero commits posteriores de bookkeeping (`project-log.md`,
> `current-session.json`, PRs #117/#118) se hicieron directo sobre `develop` sin sincronizar
> `main` de vuelta. Resultado: el tag `v2.2.0` quedó fuera del historial ancestral de
> `develop` — `git describe` en cualquier consumidor que actualice el submódulo `.aura` a
> `develop` (en vez de al tag exacto) reporta una versión vieja (`v2.1.1-N-g...`) aunque el
> contenido ya incluya el release. Se detectó porque un repo consumidor externo reportó la
> versión mal etiquetada al actualizar `.aura`. Corregido con un merge `main → develop` sin
> conflictos (contenido idéntico, solo restablece ancestría).

**Invocar el script (no reconstruir la secuencia en prosa — cada paso es idempotente y falla
explícito si su precondición no se cumple):**

```bash
# 1. CHANGELOG.md ya debe tener una sección "## [vX.Y.Z]" (redacción humana/LLM, el script
#    no la genera) y los cambios sin commitear, estando en develop:
skills/agentic-dev-loop/scripts/cut-release.sh changelog-pr <owner>/<repo> vX.Y.Z
# -> abre el PR del changelog hacia develop, imprime su número. Mergear antes de seguir.

# 2. Tras mergear el PR anterior:
skills/agentic-dev-loop/scripts/cut-release.sh promote <owner>/<repo> vX.Y.Z <changelog_pr_n>
# -> abre el PR develop -> main, imprime su número. Mergear antes de seguir.

# 3. Tras mergear el PR de release:
skills/agentic-dev-loop/scripts/cut-release.sh tag <owner>/<repo> vX.Y.Z <release_pr_n>
# -> crea el tag anotado sobre el merge commit y lo publica.

# 4. Sync-back obligatorio (mismo turno, antes de cualquier otro commit de bookkeeping):
skills/agentic-dev-loop/scripts/cut-release.sh sync-back <owner>/<repo> vX.Y.Z
# -> abre el PR de sync-back main -> develop, imprime su número. Mergear antes de seguir.
```

**Por qué existe el paso de sync-back:** sin él, `develop` queda sin el tag como ancestro y
cualquier detección basada en `git describe` (incluyendo
`skills/harness-update/scripts/check-update.sh` en consumidores) reporta versiones
incorrectas — es tan obligatorio como el resto del checklist de release.

**Verificar al final:** `git describe --tags <develop HEAD>` debe resolver contra el tag recién
creado, no contra uno anterior.

**Nota sobre `git-guard.ps1`:** el paso 3 publica el tag estando parado en `main` (rama
protegida), pero no hace falta ninguna excepción en el hook — `PreToolUse` solo inspecciona el
texto del comando externo que invoca a Claude Code (`bash cut-release.sh tag ...`), que nunca
contiene literalmente `git push`; ese comando ocurre *dentro* del proceso del script, fuera del
alcance de `PreToolUse`. Se investigó y se descartó una excepción explícita por invocación de
script conocido (Issue #136): además de ser innecesaria, se comprobó en vivo que abría un hueco
real — un `git push` real disfrazado con un comentario que mencionara el nombre del script
lograba colarse. La seguridad real de que el tag no mueva commits de la rama protegida sigue
siendo `.githooks/pre-push` (opera sobre el ref real) + branch protection de GitHub.

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
2. **Guardar el bloque de `project-log.md` en Engram** (nunca un append directo ni una PR
   chore dedicada — ver "Bookkeeping de `project-log.md`" más abajo, que es el único flujo
   documentado). Formato del bloque:
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

4. **Limpiar la rama local (bajo confirmación del usuario).** Hasta ahora ningún paso del
   harness borraba la rama local tras confirmar el merge — quedaba viva hasta que
   `session_start.md` (Paso 2, salud de ramas) la detectara pasivamente en una sesión
   posterior. Este paso lo hace en el momento correcto (justo tras el merge), pero **nunca
   sin preguntar** — borrar una rama sigue siendo una acción que el usuario debe aprobar
   (regla general del harness: nunca ejecutar acciones destructivas sin aprobación).

   ```bash
   # Paso a: dry-run — reporta si hay rama local para limpiar, sin borrar nada
   skills/agentic-dev-loop/scripts/cleanup-merged-branch.sh <owner>/<repo> <pr_n>

   # Paso b: si el script confirma que está mergeada y lista, preguntar al usuario
   # ("¿Borro la rama local <branch>?") y solo si aprueba:
   skills/agentic-dev-loop/scripts/cleanup-merged-branch.sh <owner>/<repo> <pr_n> --delete
   ```

   El script usa `git branch -d` (nunca `-D`) — si la rama tiene commits sin mergear (no
   debería pasar si el PR ya está mergeado a `develop`, pero el script lo verifica antes de
   intentar borrar), falla explícitamente en vez de forzar.

   **Ejemplo de uso real** (walkthrough, no hay suite de tests automatizada para los scripts
   de este repo — se validan así, con un caso real):
   ```bash
   $ skills/agentic-dev-loop/scripts/cleanup-merged-branch.sh diegosvart/mi-repo 42
   Rama local 'feature/issue-40-mi-feature' está mergeada en develop y lista para borrar.
   Confirmar con el usuario y volver a correr: cleanup-merged-branch.sh diegosvart/mi-repo 42 --delete

   # (agente pregunta al usuario, usuario confirma)

   $ skills/agentic-dev-loop/scripts/cleanup-merged-branch.sh diegosvart/mi-repo 42 --delete
   Rama local 'feature/issue-40-mi-feature' borrada (PR #42 mergeado a develop).
   ```

### Bookkeeping de `project-log.md` (único flujo — nunca una PR chore dedicada)

`develop` está protegida (`git-guard.ps1` bloquea commits directos), así que el bloque de
`project-log.md` de cada merge **nunca se commitea de inmediato**. El flujo es siempre el
mismo, tenga o no una PR de código en curso en ese momento:

```
mem_save(
  title="project-log pendiente de volcar",
  content="<el mismo bloque markdown que iría en project-log.md>",
  type="project",
  topic_key="project-log/pr-bookkeeping"
)
```

`topic_key` hace upsert — cada merge sin volcar actualiza la misma observación en vez de
crear una fila nueva, así que puede acumular más de un bloque pendiente a la vez. Se vuelca
a `project-log.md` real (append normal, arriba de todo, orden cronológico inverso) recién en
la **próxima PR de código real que se abra**, como un archivo más de ese diff.

**Nunca abrir una rama/PR dedicada solo para este append** — es un PR de un solo archivo,
sin código, sin revisión real posible, que solo agrega pasos (rama, commit, push, PR,
esperar merge) sin aportar valor. Caso real que motivó esto: PR #261 (2026-09-12), abierta
únicamente para volcar los bloques de PR #256 y #260, quedó cerrada sin mergear — el
contenido tuvo que rescatarse de la rama local y recién ahí pasó a Engram. Precedente de que
la ruta de Engram ya se había elegido antes: Issue #127 (PR #140), consultado explícitamente
al usuario (observación Engram #337).

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