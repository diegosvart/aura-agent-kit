---
adr: 008
title: Registrar aura-agent-kit como plugin nativo de Claude Code
date: 2026-09-01
status: accepted
area: harness
---

# ADR-008: Registrar aura-agent-kit como plugin nativo de Claude Code

## Problema

Ninguna de las 15 skills (`skills/*/SKILL.md`) ni los 13 comandos (`commands/*.md`) del
harness eran invocables vía el Skill tool / slash commands nativos de Claude Code —
reproducido en vivo (`Skill(auto-research)` → `Unknown skill`). El agente siempre las leyó
manualmente siguiendo la tabla de routing de `AGENTS.md`/`protocols/router.md`, el mismo
patrón usado para `protocols/*.md`. Señalado antes como fricción suelta en Engram
(observación #543, 2026-09-01) sin issue abierto. Issue #170.

## Contexto

El repo ya tenía la estructura de carpetas de un plugin de Claude Code (`skills/`,
`commands/`, `agents/` en la raíz) y 6 archivos ya referenciaban el namespace `aura:<nombre>`
como si el plugin existiera (`agents/doc-guardian.md`, `commands/brainstorm.md`,
`commands/execute-plan.md`, `commands/write-plan.md`, `skills/writing-plans/SKILL.md`,
`skills/systematic-debugging/SKILL.md`). Nunca se creó `.claude-plugin/plugin.json` — sin
manifiesto, Claude Code nunca registró nada de esto.

Verificado con documentación oficial (`code.claude.com/docs/en/plugins.md`, `.../skills.md`,
`.../discover-plugins.md`) antes de decidir:
- `plugin.json` solo requiere `name`; descubrimiento de skills/comandos es automático por
  ruta (no hace falta indexarlas).
- El contenido actual de `commands/*.md` (prosa dirigida al agente, sin frontmatter) funciona
  tal cual como prompt del comando — confirmado con `claude plugin validate .` (0 errores,
  solo warnings de frontmatter faltante en `commands/*.md`/`agents/*.md`, no bloqueante).
- 8 de 15 `SKILL.md` no tenían el frontmatter YAML (`description`) requerido para que Claude
  Code registre una skill.

Se descartó mantener el modelo de solo-lectura-manual (shims en `.claude/skills/` apuntando
al contenido real) por ser un parche que no resuelve el problema de fondo y no aprovecha que
el usuario confirmó que AURA se construyó deliberadamente **sobre** Claude Code (no
cross-agent) — el mecanismo nativo de plugins es la herramienta correcta, no una desviación
de P6 (Stack-agnóstico, que aplica a detección de stack de *proyectos consumidores*, no al
propio harness).

## Decisión

1. `.claude-plugin/plugin.json` en la raíz del repo, `name: "aura"` (coincide con las 6
   referencias `aura:<nombre>` ya existentes en el repo).
2. `.claude-plugin/marketplace.json` que declara el plugin `aura` con `source: "./"` bajo el
   nombre de marketplace `aura-local` — permite registrar el repo como marketplace local vía
   `claude plugin marketplace add .` desde la raíz del repo.
3. Frontmatter YAML (`name`, `description`) agregado a las 8 skills que no lo tenían:
   `agentic-dev-loop`, `auto-research`, `idea-management`, `issue-planning`,
   `plan-reporting`, `repo-integrity`, `spec-validation`, `stack-selection`.
4. `.claude/settings.json` declara `enabledPlugins: {"aura@aura-local": true}` — habilita el
   plugin automáticamente para cualquiera que ya haya registrado el marketplace local.

**Limitación conocida (no resuelta por este ADR):** el registro del marketplace
(`claude plugin marketplace add .`) es estado de usuario/máquina (`~/.claude/plugins/`), no
versionable — cada desarrollador debe correrlo una vez, igual que `gh auth login`. Se
documenta como paso de setup en `README.md`/`QUICKSTART.md`, no se puede empaquetar en el
repo.

**Fuera de alcance de este ADR** (issue de seguimiento, no bloquea): propagar este mismo
registro a los repos consumidores que vendorizan el harness como `.aura/` (requiere tocar
`apply-update.sh`/`install.sh`, mayor radio de impacto). Tampoco se agregó frontmatter a
`commands/*.md` ni `agents/*.md` — son warnings no bloqueantes de `claude plugin validate`,
el contenido en prosa ya funciona sin frontmatter.

## Alternativas descartadas

- **Shims en `.claude/skills/<nombre>/SKILL.md`** apuntando al contenido real en
  `skills/<nombre>/SKILL.md`: evita el registro de plugin/marketplace, pero no resuelve la
  causa raíz (ausencia de manifiesto) y deja el comando `/aura:<nombre>` sin resolver, que ya
  estaba referenciado en 6 archivos del propio repo.
- **No hacer nada** (seguir leyendo manualmente vía `AGENTS.md`): descartado porque el
  usuario confirmó que viene notando esta fricción "hace tiempo" y es consistente con el
  hallazgo ya registrado en Engram.

## Consecuencias

- Cualquier desarrollador que clone este repo debe correr `claude plugin marketplace add .`
  una vez desde la raíz para que el plugin `aura` quede disponible localmente.
- Los cambios a `skills/*/SKILL.md` no se reflejan automáticamente para quien ya instaló el
  plugin — Claude Code cachea el contenido al instalar (`~/.claude/plugins/cache/`); hace
  falta `claude plugin update aura@aura-local` tras cambios de contenido.
- La verificación end-to-end (¿el Skill tool reconoce `aura:auto-research`?) solo puede
  confirmarse en una sesión nueva, no en la misma sesión donde se registra el plugin.

## Archivos afectados

`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.claude/settings.json`,
`skills/*/SKILL.md` (8 archivos con frontmatter agregado), `README.md`, `QUICKSTART.md`,
`skills/repo-integrity/manifest.txt`, `docs/aura/experiments/2026-09-01-plugin-registration.md`.
