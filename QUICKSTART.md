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

### Proyecto nuevo

```bash
git clone https://github.com/diegosvart/aura-agent-kit.git mi-proyecto
cd mi-proyecto
claude .
```

### Proyecto existente

```bash
# Agregar como submodule
git submodule add https://github.com/diegosvart/aura-agent-kit.git .aura

# Registrar entry point en CLAUDE.md
printf '\n<!-- aura:begin -->\n@.aura/CLAUDE.md\n<!-- aura:end -->\n' >> CLAUDE.md

# Copiar hooks
mkdir -p .claude/hooks
cp .aura/.claude/hooks/*.ps1 .claude/hooks/
```

---

## Paso 3 — Registrar hooks en `settings.json`

Agregar al `.claude/settings.json` de tu proyecto (mergear si ya existe):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/session-start.ps1" }] }
    ],
    "SessionStart[resume]": [
      { "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/session-resume.ps1" }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "pwsh -NonInteractive -File .claude/hooks/session-end.ps1", "timeout": 60 }] }
    ]
  }
}
```

---

## Paso 4 — Primera sesión

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
| Agente no sigue protocolos | Verificar que `CLAUDE.md` existe en la raíz |
| Conflicto con CLAUDE.md existente | Usar marcadores `<!-- aura:begin/end -->` en lugar de reemplazar |

---

## Desinstalar

```bash
git submodule deinit -f .aura
git rm -f .aura
rm -rf .git/modules/.aura
# Eliminar bloque <!-- aura:begin --> ... <!-- aura:end --> de CLAUDE.md
rm .claude/hooks/session-start.ps1 .claude/hooks/session-resume.ps1 .claude/hooks/session-end.ps1
```
