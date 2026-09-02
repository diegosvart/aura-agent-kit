---
status: done
---

# Plan — Continuar investigación `Skill(aura:auto-research)` + limpiar worktree colgado

## Context

Sesión anterior (2026-09-02, obs Engram #551/#552/#554) descartó dos hipótesis para
`Skill(aura:auto-research)` → `"Unknown skill: aura:auto-research"`:
1. `enabledPlugins` vacío (Issue #172/PR #173) — descartado, causa contribuyente ya corregida.
2. Frontmatter faltante en los 16 `SKILL.md` — descartado, todos tienen `name`/`description` OK.

Quedó una hipótesis sin confirmar: el marketplace `aura-local` apuntaba a un **worktree
efímero** (`.claude/worktrees/fix+issue-plugin-registration`) en vez del checkout principal.
Se corrigió (`source: Directory (C:\repos\aura-agent-kit)`) pero no se pudo verificar en la
misma sesión — el listado de skills se fija al inicio de sesión.

**Esta sesión (nueva, fuera de ese worktree) ya verificó**: `Skill(aura:auto-research)`
sigue fallando con el marketplace apuntando al checkout principal → **el path efímero
tampoco era la causa raíz** (o no la única). Confirmado con `claude plugin marketplace list`
/ `claude plugin list`: `aura-local` sigue `Directory (C:\repos\aura-agent-kit)`, plugin
`aura@aura-local` enabled en ambos scopes (user y project).

El usuario pidió, si esto pasaba, seguir con la hipótesis pendiente #2 del ledger: probar
`source: GitHub` en vez de `Directory` — el repo (`diegosvart/aura-agent-kit`) ya es público,
así que es viable sin cambios de visibilidad.

Además, el usuario reporta desde el dashboard de sesiones que un worktree quedó sin cerrar:
`C:\repos\aura-agent-kit\.claude\worktrees\worktree-conflict-brainstorm`, con el aviso
"has commits that are not pushed anywhere". Investigado en esta sesión: esa rama es
`docs/project-log-bookkeeping-close` (71eb39d, "docs(project-log): registrar PR #166 y
ledger retroactivo de v2.4.1"). Confirmado con `git merge-base --is-ancestor` y
`git ls-remote`: el contenido **ya está en develop** vía squash-merge (commit `e81b1b6`,
PR #167 — mismo mensaje, distinto hash), y la rama remota fue borrada tras el merge. El
worktree no tiene trabajo perdido: es un residuo post-merge, no un caso de pérdida real.

## Approach

### 1. Probar `source: GitHub` para el marketplace `aura-local`

Mismo patrón que la corrección anterior (obs #552), pero apuntando a GitHub en vez de a un
path local:

```bash
claude plugin uninstall aura@aura-local
claude plugin marketplace remove aura-local
claude plugin marketplace add diegosvart/aura-agent-kit
claude plugin install aura@aura-local
```

Verificar después:
- `claude plugin marketplace list` → `aura-local` debe mostrar `Source: GitHub
  (diegosvart/aura-agent-kit)`.
- `claude plugin list` → `aura@aura-local` debe seguir `enabled` (scope user y/o project).
- `git status --short` sobre `.claude/settings.json` — la sesión anterior (obs #554)
  encontró que estos comandos CLI pueden reescribir `enabledPlugins` a `{}` en el
  `.claude/settings.json` del proyecto activo. Si eso ocurre acá (checkout principal, no un
  worktree), restaurarlo a `{"aura@aura-local": true}` antes de terminar.

**No se puede confirmar el fix en esta misma sesión** — el listado de skills se fija al
inicio de sesión, mismo patrón documentado en ADR-008 y en obs #552. Este plan deja
explícito en Engram que la próxima sesión nueva debe probar `Skill(aura:auto-research)`
como primer paso.

Si tras esto **sigue fallando en la próxima sesión nueva** → se agotaron las hipótesis de
configuración local (enabledPlugins, frontmatter, Directory vs GitHub). Próximo paso fuera
del alcance de este plan: enviar el feedback de producto ya dejado en borrador (obs #551
menciona `SendFeedback` usado en esa sesión) o consultar al agente `claude-code-guide`.

### 2. Limpiar el worktree colgado `worktree-conflict-brainstorm`

Solo tras confirmar (ya hecho arriba) que no hay trabajo sin mergear:

```bash
git worktree remove ".claude/worktrees/worktree-conflict-brainstorm"
git branch -d docs/project-log-bookkeeping-close
```

Si `worktree remove` falla por estar "locked" o con cambios (no debería, `git status` en el
worktree mostró "nothing to commit, working tree clean"), usar `git worktree remove --force`
recién ahí, nunca de entrada.

### 3. Documentar en Engram

`mem_save` con `topic_key: bug/skill-aura-not-registered` (evoluciona el mismo tema entre
sesiones, mismo patrón que project-log) resumiendo:
- Hipótesis worktree-efímero: descartada esta sesión.
- Resultado de probar `source: GitHub`.
- Estado del worktree colgado: limpiado, contenido ya estaba en develop vía PR #167.

## Verification

- `claude plugin marketplace list` muestra `aura-local` como `Source: GitHub`.
- `git status --short .claude/settings.json` sin diff inesperado (o restaurado si el CLI lo
  tocó).
- `git worktree list` ya no incluye `worktree-conflict-brainstorm`.
- `git branch` ya no incluye `docs/project-log-bookkeeping-close`.
- Observación nueva en Engram con `topic_key: bug/skill-aura-not-registered`.
- **Pendiente, fuera de esta sesión:** abrir sesión nueva y correr `Skill(aura:auto-research)`
  como primer paso, antes de cualquier otra cosa.

## Resultado (confirmado en sesión nueva, 2026-09-02)

`Skill(aura:auto-research)` carga correctamente el contenido del comando — ya no devuelve
"Unknown skill: aura:auto-research". Causa raíz real: un marketplace `aura-local` con
`source: Directory` (sea cual sea el path local) no hace que Claude Code registre las
skills del plugin para el Skill tool nativo; `source: GitHub` sí. Detalle completo en
Engram (`topic_key: bug/skill-aura-not-registered`, obs #556).

Pendiente de seguimiento (fuera de este plan):
- Confirmar estabilidad del fix en próximas sesiones.
- Investigar duplicación de `aura@aura-local` en scope `project` (`claude plugin list`
  muestra la entrada dos veces).
- Documentar el flujo "editar skill local → push → `claude plugin marketplace update`"
  como parte del workflow de desarrollo del harness (implica que cambios locales a
  `skills/*/SKILL.md` no se reflejan hasta pushear a GitHub).
