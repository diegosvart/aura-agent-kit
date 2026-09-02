# Quick Start — Aura Agent Kit

> Estar funcionando en menos de 10 minutos.

---

## Paso 1 — Prerrequisitos

```bash
claude --version      # Claude Code CLI
gh --version          # GitHub CLI
pwsh --version        # PowerShell 7+
```

Si falta `gh`: [cli.github.com](https://cli.github.com/)  
Si falta `pwsh`: [aka.ms/install-powershell](https://aka.ms/install-powershell)

```bash
gh auth login
```

---

## Paso 2 — Instalar

### Opción A — Script automático (recomendado)

Desde la raíz de tu proyecto:

```bash
# Windows
pwsh -File .aura/install.ps1

# macOS / Linux
bash .aura/install.sh
```

El script:
- Agrega el harness como submodule en `.aura/`
- Hace append en `CLAUDE.md` con marcadores `<!-- aura:begin/end -->` (no sobreescribe)
- Copia los hooks a `.claude/hooks/` (no sobreescribe los existentes)

### Opción B — Manual

```bash
# 1. Agregar submodule
git submodule add https://github.com/diegosvart/aura-agent-kit.git .aura

# 2. Registrar entry point en CLAUDE.md (append-only)
printf '\n<!-- aura:begin -->\n@.aura/CLAUDE.md\n<!-- aura:end -->\n' >> CLAUDE.md

# 3. Copiar hooks
mkdir -p .claude/hooks
cp .aura/.claude/hooks/*.ps1 .claude/hooks/
```

### Opción C — Solo plugin, sin submodule

Sin vendorizar `.aura/` en el repo. El harness se instala y se actualiza 100% vía el
mecanismo de plugins de Claude Code (ver ADR-009).

```bash
# 1. Registrar el marketplace apuntando al repo real en GitHub — NO una ruta local
#    (una ruta local, ./.aura o ".", asume que ya existe un submodule vendorizado; acá no)
claude plugin marketplace add diegosvart/aura-agent-kit

# 2. Instalar el plugin
claude plugin install aura@aura-agent-kit --scope project

# 3. Los hooks no llegan solos por esta vía -- copiarlos una vez desde el installPath
#    real que reporta Claude Code (no asumir la ruta, puede variar por versión/SO):
INSTALL_PATH=$(claude plugin list --json | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(next(p['installPath'] for p in d if p['id']=='aura@aura-agent-kit'))")
mkdir -p .claude/hooks
cp "$INSTALL_PATH"/.claude/hooks/*.ps1 .claude/hooks/
```

Continuar con el **Paso 3** (registrar hooks en `settings.json`, igual que las otras
opciones) — **saltear el Paso 4** (el plugin ya quedó instalado acá). Para actualizar más
adelante, `/harness-update` detecta este canal solo (no hace falta repetir estos pasos a
mano).

---

## Paso 3 — Registrar hooks en `settings.json`

Agregar al `.claude/settings.json` de tu proyecto (mergear si ya existe):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/context-guard.ps1", "timeout": 5 }] }
    ],
    "PreToolUse": [
      { "matcher": "Bash",       "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/git-guard.ps1", "timeout": 5 }] },
      { "matcher": "PowerShell", "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/git-guard.ps1", "timeout": 5 }] }
    ],
    "SessionStart": [
      { "matcher": "startup", "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/session-start.ps1", "timeout": 30 }] },
      { "matcher": "resume",  "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/session-resume.ps1", "timeout": 30 }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/session-end.ps1", "timeout": 60 }] }
    ]
  }
}
```

---

## Paso 4 — Registrar el plugin (skills y comandos invocables)

> Solo si instalaste con Opción A o B (submodule). Si usaste Opción C, este paso ya quedó
> hecho — seguir directo al Paso 5.

Para que las skills (`skills/*/SKILL.md`) y comandos (`commands/*.md`) queden invocables como
`aura:<nombre>` / `/aura:<nombre>` vía el Skill tool nativo (ver ADR-008):

```bash
# Desde la raíz de tu proyecto (donde vive .aura/)
claude plugin marketplace add ./.aura
claude plugin install aura@aura-agent-kit --scope project
```

Paso único por máquina — el registro del marketplace es estado de usuario
(`~/.claude/plugins/`), no se versiona. Si `skills/*.md` cambia después de instalar, correr
`claude plugin update aura@aura-agent-kit`.

---

## Paso 5 — Identidad local (opcional pero recomendado)

```bash
cp .aura/AGENTS.local.example.md AGENTS.local.md
# Editar AGENTS.local.md con tu rol, nombre y cómo operás
```

Este archivo es gitignoreado — es tuyo, no del repositorio.

---

## Paso 6 — Reglas opt-in

`.aura/CLAUDE.md` carga solo `harness-core.md` por defecto. Para activar reglas adicionales, editar `.aura/CLAUDE.md` en tu proyecto y descomentar las que quieras:

```markdown
@.aura/rules/design-flow.md      # Brainstorm antes de planificar
@.aura/rules/repo-integrity.md   # Detectar trabajo stranded
@.aura/rules/routing-menu.md     # Menú post-tarea
@.aura/rules/coding.md           # Convenciones de código
```

---

## Paso 7 — Primera sesión

```bash
claude .
```

El agente presenta automáticamente: estado del repo, issues `ready`, resumen de última sesión y menú de opciones.

Si no aparece → verificar Paso 3.

---

## Primeros comandos

| Comando | Para qué |
|---------|----------|
| `/idea "objetivo"` | Registrar una idea o objetivo |
| `/plan-work` | Crear issues desde una descripción |
| `/brainstorm` | Diseñar antes de codear |
| `/finish-branch` | Preparar rama para PR |
| `/harness-update` | Actualizar el harness a la última versión (detecta canal solo) |

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| Hooks no se ejecutan | Verificar paths en `settings.json` y que `pwsh` está en PATH |
| `gh` no autenticado | `gh auth login` |
| Agente no sigue protocolos | Verificar que `CLAUDE.md` contiene el bloque `<!-- aura:begin -->` |
| Conflicto con CLAUDE.md existente | El script usa append-only — revisar marcadores manualmente |
| Submodule desactualizado | `git submodule update --remote .aura`, o simplemente `/harness-update` |
| Harness desactualizado (cualquier canal) | `/harness-update` — detecta submodule o plugin solo, ver ADR-009 |

---

## Desinstalar

**Opción A/B (submodule):**
```bash
git submodule deinit -f .aura
git rm -f .aura
rm -rf .git/modules/.aura
# Eliminar bloque <!-- aura:begin --> ... <!-- aura:end --> de CLAUDE.md
rm .claude/hooks/session-start.ps1 .claude/hooks/session-resume.ps1 .claude/hooks/session-end.ps1 .claude/hooks/git-guard.ps1 .claude/hooks/context-guard.ps1
```

**Opción C (solo plugin):**
```bash
claude plugin uninstall aura@aura-agent-kit
rm .claude/hooks/session-start.ps1 .claude/hooks/session-resume.ps1 .claude/hooks/session-end.ps1 .claude/hooks/git-guard.ps1 .claude/hooks/context-guard.ps1
```
