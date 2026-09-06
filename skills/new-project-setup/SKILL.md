---
name: new-project-setup
description: Crea un nuevo repositorio consumidor del harness Aura de punta a punta — directorio local, clonado del remoto, submodule .aura pinneado a un tag, identidad, hooks y primer push — dejándolo listo para arrancar `claude .` y empezar a trabajar. Usar cuando el usuario quiere iniciar un proyecto nuevo con Aura instalado.
---

# Skill — New Project Setup

> **Propósito:** Dejar un repositorio nuevo (ya creado en GitHub, vacío) 100% operativo con el
> harness Aura instalado, de modo que una sesión de Claude Code arrancada ahí (`claude .`)
> corra `protocols/session_start.md` sin errores desde el primer momento.
> **Comando asociado:** `/new-project`
> **Origen:** procedimiento validado manualmente en dos scaffolds reales (`aura-harness-diagrams`,
> 2026-09-05; `ebi-insight-power-apps`, 2026-09-06) — formalizado acá para no repetir el
> levantamiento de `QUICKSTART.md`/`install.sh` cada vez.

---

## Cuándo Activar

- El usuario pide crear/iniciar/armar un proyecto nuevo con Aura instalado
- El usuario da una URL de un repo de GitHub (existente y vacío, o a crear) y pide dejarlo listo
- Router: caso compuesto "Proyecto nuevo desde cero" de `protocols/router.md`

**No usar para:** agregar el harness a un repo que ya tiene código e historial — ese caso es
`install.sh`/`QUICKSTART.md` directo (append-only sobre `CLAUDE.md` existente), no este wizard.

---

## Proceso

### Paso 0 — Recolectar decisiones (una pregunta a la vez, o todas juntas si el usuario ya las dio)

No asumir ninguna de estas — son decisiones reales con trade-offs, no detalles derivables:

1. **Repo remoto:** ¿URL de GitHub? ¿Ya existe o hay que crearlo (`gh repo create`)? Si ya
   existe, verificar con `gh repo view <owner>/<repo> --json visibility,isEmpty,defaultBranchRef`
   — nunca asumir que está vacío sin comprobarlo.
2. **Directorio local:** por convención, sibling de los demás repos del usuario (ver `ls`
   del directorio padre de proyectos existentes). Confirmar antes de crear.
3. **Canal de instalación del harness:**
   - **Submodule pinneado a un tag** (recomendado por defecto — reproducible, no `develop`
     flotante; ver Issue #120 para el incidente que motiva pinnear siempre a un tag concreto).
   - **Solo plugin** (sin vendorizar `.aura/`) — más liviano, canal más nuevo (ADR-009), usar
     si el usuario lo pide explícitamente.
4. **Stack del proyecto:** correr `skills/stack-selection/SKILL.md` si el proyecto va a tener
   código propio (linter/tests). Si es un proyecto sin runtime tradicional (ej. Canvas App de
   Power Apps vía plugin `canvas-apps`), no forzar un perfil de los 24 — declarar el perfil
   real (o "sin stack de código, gestionado por plugin X") en `session-stack.json`.
5. **Identidad (`AGENTS.local.md`):** rol principal/secundario, tono, cómo debe operar el
   agente en este proyecto. Si el usuario no lo da, ofrecer copiar el placeholder
   (`AGENTS.local.example.md`) para que lo edite después — nunca inventarlo.
6. **Rama default:** `main` o `develop` — un repo vacío no tiene rama default hasta el primer
   push; fijarlo ahora evita rehacer el flujo git del harness después.
7. **Reglas opt-in de `.aura/CLAUDE.md`:** por defecto solo carga `harness-core.md`. Preguntar
   si activar además `design-flow.md`, `repo-integrity.md`, `routing-menu.md`, `coding.md`
   (recomendado activarlas todas salvo que el usuario prefiera un harness minimal).

### Paso 1 — Verificar prerrequisitos (read-only)

```bash
gh auth status --hostname github.com
gh repo view <owner>/<repo> --json visibility,isEmpty,defaultBranchRef
ls <directorio-padre-destino>   # confirmar que el path local no existe ya
```

Si el repo remoto no existe: `gh repo create <owner>/<repo> --private` (o `--public` según lo
que pida el usuario) antes de continuar.

### Paso 2 — Clonar el repo remoto

```bash
git clone <url-repo> <path-local-destino>
```

Un repo vacío clona sin `HEAD` (sin commits) — es esperado, no un error.

### Paso 3 — Scaffold del harness (canal submodule — Opción B manual de `QUICKSTART.md`)

Ejecutar dentro del directorio local recién clonado:

```bash
# 3.1 — Submodule
git submodule add https://github.com/diegosvart/aura-agent-kit.git .aura
cd .aura && git checkout <tag-elegido> && cd ..   # nunca dejarlo flotando en develop

# 3.2 — CLAUDE.md (entry point)
printf '<!-- aura:begin -->\n@.aura/CLAUDE.md\n<!-- aura:end -->\n' > CLAUDE.md

# 3.3 — Hooks (copiar el set REAL vigente, no confiar en QUICKSTART.md si está desactualizado —
# verificar contra .aura/.claude/hooks/*.ps1 y el .claude/settings.json real de aura-agent-kit)
mkdir -p .claude/hooks
cp .aura/.claude/hooks/*.ps1 .claude/hooks/

# 3.4 — Registrar el plugin (skills/comandos invocables como aura:<nombre>)
claude plugin marketplace add ./.aura
claude plugin install aura@aura-agent-kit --scope project
```

**Antes de escribir `.claude/settings.json`:** leer el `.claude/settings.json` real de
`aura-agent-kit` en el tag pinneado (`.aura/.claude/settings.json` una vez agregado el
submodule) y clonar su bloque `hooks` completo — no copiar el ejemplo de `QUICKSTART.md` a
ciegas, puede estar desactualizado respecto a hooks nuevos (caso real: `sensitive-data-guard.ps1`
y `pr-base-guard.ps1` no aparecían documentados en `QUICKSTART.md` al momento de escribir esta
skill, pero sí estaban activos en `settings.json`).

### Paso 4 — Identidad y reglas opt-in

```bash
# AGENTS.local.md en la RAÍZ (nunca dentro de .aura/ — ver Issue #200)
```

Escribir `AGENTS.local.md` con la identidad recolectada en el Paso 0.5. Editar
`.aura/CLAUDE.md` para descomentar las reglas opt-in elegidas en el Paso 0.7.

### Paso 5 — `.gitignore`

Replicar como mínimo las entradas del harness fuente que protegen memoria/identidad local:
`AGENTS.local.md`, `.agent/memory/current-session.json`, `.agent/memory/backups/`,
`.agent/memory/observability/`, `.agent/memory/harness-update-check.json`,
`.claude/sensitive-terms.local.txt` — más las genéricas de OS/secrets/build del stack elegido.

### Paso 6 — Stack de sesión

Invocar `skills/stack-selection/SKILL.md` (o registrar directamente el perfil ya acordado en
el Paso 0.4) para escribir `.agent/memory/session-stack.json`.

### Paso 7 — Primer commit y push

```bash
git add -A
git commit -m "chore: scaffold inicial harness Aura <tag> + <stack>"
git push -u origin <rama-default-elegida>
```

Si la rama default de GitHub para el repo no coincide con la elegida en el Paso 0.6, ajustarla
(`gh repo edit --default-branch <rama>`) — ver `agents/github.md` para el flujo completo de
ramas del harness (`main`/`develop`).

### Paso 8 — Verificación (obligatoria antes de dar el setup por cerrado)

- [ ] `cd .aura && git describe --tags` devuelve el tag pinneado (no `develop` flotante)
- [ ] `claude plugin list --json` incluye `aura@aura-agent-kit` con `installPath` apuntando a `./.aura`
- [ ] El commit de scaffold aparece en `origin` (`git log --oneline -1` tras el push)
- [ ] `AGENTS.local.md` existe en la raíz del proyecto nuevo, no dentro de `.aura/`

### Paso 9 — Handoff

Informar al usuario que ya puede correr `claude .` desde el directorio nuevo — la sesión que se
abra ahí va a ejecutar `protocols/session_start.md` automáticamente. Esta skill no puede iniciar
esa sesión por él (corre en el repo fuente, `aura-agent-kit`, no en el proyecto nuevo).

Si el usuario ya tiene un primer alcance funcional definido, ofrecer seguir con `/plan-work`
**en la nueva sesión** (no acá) para crear el primer issue `ready`.

---

## Reglas

1. **Nunca asumir el estado del repo remoto** — siempre `gh repo view` antes de clonar/crear.
2. **Nunca pinnear el submodule a `develop`** salvo pedido explícito del usuario — ver Issue #120.
3. **`AGENTS.local.md` siempre en la raíz**, nunca dentro de `.aura/` — bug ya documentado
   (el import `@../AGENTS.local.md` de `.aura/CLAUDE.md` falla en silencio si está mal ubicado).
4. **No escribir `.claude/settings.json` de memoria** — leerlo del `.aura/` recién agregado en
   el tag pinneado, para no quedar desactualizado respecto a hooks nuevos.
5. **No ejecutar nada sin que el usuario haya confirmado las 7 decisiones del Paso 0.**

---

## Integración con Otras Skills

- `skills/stack-selection/SKILL.md` — Paso 6 (perfil de stack)
- `agents/github.md` — convención de ramas (`main`/`develop`) para el Paso 7
- `skills/issue-planning/SKILL.md` (`/plan-work`) — primer issue, en la sesión nueva, fuera del scope de esta skill

---

## Errores Comunes

| Situación | Acción |
|-----------|--------|
| Repo remoto no vacío (tiene commits) | Detener y preguntar si el usuario quiere clonar tal cual o esto es el caso de instalación sobre repo existente (usar `install.sh`/`QUICKSTART.md` directo, no esta skill) |
| `.claude/settings.json` de `QUICKSTART.md` desactualizado respecto a hooks reales | Leer siempre `.aura/.claude/settings.json` del tag pinneado como fuente de verdad, no el doc |
| Usuario no sabe qué canal de instalación quiere | Recomendar submodule pinneado por defecto, explicar el trade-off (Paso 0.3) |
| Proyecto sin stack de código tradicional (ej. Canvas App) | No forzar un perfil de los 24 de `stack-selection` — declarar el perfil real gestionado por su propio plugin |
