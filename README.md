# Aura Agent Kit

Un framework de trabajo para agentes IA que convierte a Claude Code en un partner de desarrollo estructurado: con memoria persistente entre sesiones, protocolos de inicio y cierre, ciclo de vida de objetivos y automatización del flujo git/GitHub.

---

## Prerrequisitos

| Herramienta | Versión | Rol |
|-------------|---------|-----|
| [Claude Code](https://claude.ai/code) | latest | IDE / CLI principal |
| [PowerShell](https://github.com/PowerShell/PowerShell) | 7+ | Ejecución de hooks |
| [gh CLI](https://cli.github.com/) | 2.0+ | Operaciones GitHub |
| [Engram](https://github.com/The-Pocket/PocketFlow-Tutorial-Codebase-Knowledge) | latest | Memoria persistente (opcional pero recomendado) |

## Compatibilidad

| SO | Claude Code | Hooks PS1 |
|----|-------------|-----------|
| Windows 10/11 | ✓ | ✓ |
| macOS | ✓ | ✓ (pwsh requerido) |
| Linux | ✓ | ✓ (pwsh requerido) |

> Los hooks requieren PowerShell 7+ (`pwsh`). En macOS/Linux: `brew install powershell` o ver [instrucciones oficiales](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).

---

## Instalación

### Opción A — Clonar directo (proyecto nuevo)

```bash
git clone https://github.com/diegosvart/aura-agent-kit.git mi-proyecto
cd mi-proyecto
```

### Opción B — Agregar a proyecto existente

```bash
# Desde la raíz de tu proyecto
git submodule add https://github.com/diegosvart/aura-agent-kit.git .aura

# Agregar entry point al CLAUDE.md existente (o crear uno)
echo "" >> CLAUDE.md
echo "<!-- aura:begin -->" >> CLAUDE.md
echo "@.aura/CLAUDE.md" >> CLAUDE.md
echo "<!-- aura:end -->" >> CLAUDE.md

# Copiar hooks (Claude Code los requiere en .claude/hooks/)
mkdir -p .claude/hooks
cp .aura/.claude/hooks/*.ps1 .claude/hooks/
```

Luego editar `.claude/settings.json` para registrar los hooks (ver [QUICKSTART.md](QUICKSTART.md)).

### Registrar el plugin (skills y comandos invocables)

Paso único por máquina, para que las skills (`skills/*/SKILL.md`) y comandos
(`commands/*.md`) queden invocables como `aura:<nombre>` / `/aura:<nombre>` vía el Skill
tool nativo de Claude Code (ver ADR-008):

```bash
# Desde la raíz del repo (o .aura/ si se instaló como submodule)
claude plugin marketplace add .
claude plugin install aura@aura-agent-kit --scope project
```

El registro del marketplace es estado de usuario/máquina (`~/.claude/plugins/`), no se
versiona — cada desarrollador lo corre una vez, igual que `gh auth login`. Si el contenido
de `skills/*.md` cambia después de instalar, correr `claude plugin update aura@aura-agent-kit`
para refrescar la caché.

### Opción C — Solo plugin, sin submodule

Para no vendorizar `.aura/` en el repo consumidor: registrar el marketplace apuntando al
repositorio real en GitHub (no una ruta local) e instalar el plugin directamente.

```bash
claude plugin marketplace add diegosvart/aura-agent-kit
claude plugin install aura@aura-agent-kit --scope project
```

Los hooks (`.claude/hooks/*.ps1`) no se distribuyen automáticamente por esta vía — copiarlos
una vez desde el `installPath` que reporta `claude plugin list --json` (ver
[QUICKSTART.md](QUICKSTART.md) Opción C para el paso a paso completo, incluyendo el registro
en `settings.json`). Sin ese paso, `session-start.ps1` nunca corre y el harness no detecta
nada — ver ADR-009.

### Desinstalar / revertir

```bash
# Remover submodule
git submodule deinit -f .aura
git rm -f .aura
rm -rf .git/modules/.aura

# Revertir CLAUDE.md (eliminar bloque entre marcadores aura:begin/end)
# Eliminar hooks copiados
rm .claude/hooks/session-start.ps1 .claude/hooks/session-resume.ps1 .claude/hooks/session-end.ps1
```

---

## Ciclo de Trabajo

```
/idea "objetivo"          Capturar idea o objetivo de alto nivel
        │
        ▼
/idea <N>                 Explorar con perspectivas PM → Planner → Engineer
        │
        ▼
/brainstorm               Diseño colaborativo (si el objetivo necesita spec)
        │
        ▼
/plan-work                Crear issues en GitHub con label ready
        │
        ▼
task_start (automático)   El agente toma el issue y ejecuta
        │
        ▼
/finish-branch            Verificar, commitear y abrir PR
        │
        ▼
/request-review           Solicitar code review formal
        │
        ▼
merge + close issue       Ciclo completo
```

**En cada sesión**, el harness ejecuta automáticamente:
- Al iniciar: recopila estado git, issues ready, sesión anterior → presenta resumen
- Al cerrar: guarda memoria en Engram + `current-session.json`

---

## Comandos

| Comando | Qué hace |
|---------|----------|
| `/idea <texto>` | Registra un objetivo nuevo (1 turno, no interrumpe) |
| `/idea <N>` | Explora el objetivo N con 3 perspectivas (PM, Planner, Engineer) |
| `/idea promote <N>` | Promueve objetivo a `/plan-work` |
| `/brainstorm` | Diseño colaborativo de una feature o idea |
| `/plan-work` | Convierte requerimientos en GitHub issues |
| `/finish-branch` | Prepara rama para PR (checklist + opciones) |
| `/request-review` | Solicita code review formal en la PR |
| `/auto-research` | Detecta fricción en el harness y propone mejoras |
| `/doc-check` | Verifica consistencia de documentación |
| `/stack` | Detecta o cambia el stack tecnológico de sesión |
| `/harness-update` | Actualiza el harness a la última versión (submodule o plugin, detecta el canal solo) |

---

## Estructura

```
aura-agent-kit/
├── AGENTS.md              ← Identidad, pilares, router (siempre cargado)
├── CLAUDE.md              ← Entry point para Claude Code
├── QUICKSTART.md          ← Guía de inicio rápido
│
├── .claude/
│   ├── settings.json      ← Permisos, registro de hooks y del plugin (enabledPlugins)
│   ├── hooks/             ← PS1: session-start, session-resume, session-end
│   └── rules/             ← Reglas de comportamiento del agente
│
├── .claude-plugin/
│   ├── plugin.json        ← Manifiesto del plugin `aura` (ADR-008)
│   └── marketplace.json   ← Marketplace local para registrar el plugin
│
├── protocols/             ← session_start, session_end, task_start, router
├── agents/                ← Especialistas: github, language, infra, reviewer, challenger
├── skills/                ← Skills invocables (`aura:<nombre>`): idea-management, issue-planning, brainstorming...
├── commands/              ← Comandos invocables (`/aura:<nombre>`): /idea, /plan-work, /finish-branch...
│
└── .agent/
    └── memory/
        ├── ideas.md           ← Backlog de objetivos con ciclo de vida
        └── current-session.json ← Estado de sesión actual
```

---

## Los 7 Pilares

| # | Pilar | Regla |
|---|-------|-------|
| P1 | CLI > MCP | Si existe CLI que alcanza, no usar MCP |
| P2 | Diseño antes de código | Sin spec aprobada → sin código |
| P3 | TDD siempre | Test primero, ver fallar, luego implementar |
| P4 | Hipótesis antes de cambiar el harness | Sin hipótesis escrita → no modificar protocolos |
| P5 | Memoria distribuida | Engram + current-session.json al cerrar |
| P6 | Stack-agnóstico | Detectar stack antes de asumir herramientas |
| P7 | Evolución con validación | Proponer mejoras como opción, nunca imponer |

---

## Actualizar el harness

**Recomendado, para cualquier canal de instalación:**

```
/harness-update
```

Detecta solo si instalaste como submodule o como plugin (ver ADR-009) y aplica la
actualización completa (checkout de tag o `claude plugin update`, resync de hooks,
`CLAUDE.md` y permisos). Ver `skills/harness-update/SKILL.md` para el detalle.

<details>
<summary>Manual (solo canal submodule, sin resync de hooks/permisos)</summary>

```bash
git -C .aura pull origin main
cp .aura/.claude/hooks/*.ps1 .claude/hooks/
```

</details>

---

## Licencia

MIT — Ver [LICENSE](LICENSE)

Creado por [Diego Morales](https://github.com/diegosvart) · Aura Insight IT
