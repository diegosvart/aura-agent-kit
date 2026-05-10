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

## Paso 4 — Identidad local (opcional pero recomendado)

```bash
cp .aura/AGENTS.local.example.md AGENTS.local.md
# Editar AGENTS.local.md con tu rol, nombre y cómo operás
```

Este archivo es gitignoreado — es tuyo, no del repositorio.

---

## Paso 5 — Reglas opt-in

`.aura/CLAUDE.md` carga solo `harness-core.md` por defecto. Para activar reglas adicionales, editar `.aura/CLAUDE.md` en tu proyecto y descomentar las que quieras:

```markdown
@.aura/rules/design-flow.md      # Brainstorm antes de planificar
@.aura/rules/repo-integrity.md   # Detectar trabajo stranded
@.aura/rules/routing-menu.md     # Menú post-tarea
@.aura/rules/coding.md           # Convenciones de código
```

---

## Paso 6 — Primera sesión

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

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| Hooks no se ejecutan | Verificar paths en `settings.json` y que `pwsh` está en PATH |
| `gh` no autenticado | `gh auth login` |
| Agente no sigue protocolos | Verificar que `CLAUDE.md` contiene el bloque `<!-- aura:begin -->` |
| Conflicto con CLAUDE.md existente | El script usa append-only — revisar marcadores manualmente |
| Submodule desactualizado | `git submodule update --remote .aura` |

---

## Desinstalar

```bash
git submodule deinit -f .aura
git rm -f .aura
rm -rf .git/modules/.aura
# Eliminar bloque <!-- aura:begin --> ... <!-- aura:end --> de CLAUDE.md
rm .claude/hooks/session-start.ps1 .claude/hooks/session-resume.ps1 .claude/hooks/session-end.ps1 .claude/hooks/git-guard.ps1 .claude/hooks/context-guard.ps1
```
