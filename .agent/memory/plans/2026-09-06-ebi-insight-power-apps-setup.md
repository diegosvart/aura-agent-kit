---
status: done
---

# Plan — Setup inicial `ebi-insight-power-apps`

## Context

Repo remoto ya existe en GitHub: `diegosvart/ebi-insight-power-apps`, **privado, vacío** (sin
commits, sin rama default). Directorio local `C:\repos\ebi-insight-power-apps` **no existe
todavía** (verificado 2026-09-06).

**Decisiones ya tomadas con el usuario:**
- Canal de instalación del harness: **submodule pinneado a un tag** (`v2.7.0`, la última
  release), no `develop` flotante.
- Tipo de proyecto: **Canvas App puro** (Power Apps) — se gestiona con el plugin `canvas-apps`
  ya disponible en Claude Code (MCP `canvas-authoring`, `App.pa.yaml`). No hay runtime de
  código propio que detectar en `session-stack.json`.
- Identidad (`AGENTS.local.md`): Software Engineer Senior, Fullstack, Project Manager, AI
  Engineer. Contexto: desarrollos para proyectos TI. Español chileno formal, respuestas
  directas, seguir el flujo del submódulo Aura harness.

**Punto abierto sin resolver:** rama default del repo — `main` o `develop`. Fijarlo antes de
ejecutar el push inicial.

**Ejecutor sugerido:** esta spec ya está formalizada como skill reutilizable —
`skills/new-project-setup/SKILL.md` (PR #245, mergeada a `develop` en `aura-agent-kit`).
Ejecutar con `/new-project` en vez de reconstruir los pasos a mano.

## Approach

Ver `skills/new-project-setup/SKILL.md` para el procedimiento genérico completo (Pasos 0-9).
Aplicado a este proyecto:

1. **Paso 0 (decisiones):** ya resueltas arriba, salvo rama default — confirmar con el usuario
   al arrancar la ejecución.
2. **Paso 1-2:** verificar prerrequisitos (`gh repo view diegosvart/ebi-insight-power-apps`,
   directorio local libre) y clonar.
3. **Paso 3:** `git submodule add https://github.com/diegosvart/aura-agent-kit.git .aura`,
   pinnear a `v2.7.0` (o el tag más reciente si ya hay uno nuevo al momento de ejecutar —
   revalidar), `CLAUDE.md`, copiar hooks reales (leer `.aura/.claude/settings.json` del tag
   pinneado, no confiar en `QUICKSTART.md` de memoria), registrar plugin.
4. **Paso 4-5:** `AGENTS.local.md` con la identidad ya dada, `.gitignore` estándar del harness.
5. **Paso 6:** `session-stack.json` — perfil Canvas App (sin linter/tests tradicionales,
   calidad vía `canvas-authoring` MCP: `compile_canvas`, `get_appchecker_errors`,
   `get_accessibility_errors`).
6. **Paso 7:** commit + push a la rama default confirmada.
7. **Paso 8-9:** verificación (submodule pinneado, plugin registrado, commit en origin,
   `AGENTS.local.md` en la raíz) y handoff — informar que ya se puede correr `claude .` desde
   `C:\repos\ebi-insight-power-apps`.

## Archivos/acciones críticas
- `C:\repos\ebi-insight-power-apps\.aura` (submodule, pinnear a tag vigente al momento de
  ejecutar)
- `CLAUDE.md`, `AGENTS.local.md`, `.gitignore`, `.claude/settings.json`, `.claude/hooks/*.ps1`
- `.agent/memory/session-stack.json`
- Primer commit + push a `origin`

## Verificación
- `cd .aura && git describe --tags` → tag pinneado (no `develop` flotante).
- `claude plugin list --json` incluye `aura@aura-agent-kit` con `installPath` → `./.aura`.
- `claude .` en el repo nuevo ejecuta `session_start.md` sin errores de submódulo no
  inicializado.
- `git log --oneline -1` en GitHub muestra el commit de scaffold pusheado.
