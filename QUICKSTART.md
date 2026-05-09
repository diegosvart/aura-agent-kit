# Quick Start — Aura Agent Kit

> **Objetivo:** Empezar a trabajar en <2 minutos, sin configuración. **v1.1.0**

---

## Requisitos Mínimos

| Herramienta | Versión mínima | Para qué |
|-------------|----------------|----------|
| git | cualquier | Control de versiones |
| gh CLI | 2.0+ | GitHub (issues, PRs) |
| engram |latest | Memoria persistente |

```
# Verificar
git --version
gh --version
where engram
```

---

## Inicializar un Proyecto

### Paso 1: Copiar el kit

```bash
# En el proyecto nuevo
mkdir -p .agent/agents .agent/protocols .agent/memory

# Copiar archivos del kit (ajusta la ruta)
cp -r /ruta/a/aura-agent-kit/agents/* .agent/agents/
cp -r /ruta/a/aura-agent-kit/protocols/* .agent/protocols/
cp /ruta/a/aura-agent-kit/AGENTS.md .
```

### Paso 2: Seleccionar tu IDE

Copiá el adaptador correspondiente a tu IDE. Ver [`integrations/README.md`](integrations/README.md) para instrucciones completas.

| IDE | Comando rápido |
|-----|---------------|
| Codex / Zed | Sin setup — `AGENTS.md` ya es leído nativo |
| Claude Code | `cp integrations/claude-code/CLAUDE.md . && mkdir -p .claude && cp integrations/claude-code/settings.json .claude/` |
| Copilot | `mkdir -p .github && cp integrations/copilot/copilot-instructions.md .github/` |
| Cursor | `mkdir -p .cursor/rules && cp integrations/cursor/rules/* .cursor/rules/` |
| Windsurf | `mkdir -p .windsurf/rules && cp integrations/windsurf/rules/* .windsurf/rules/` |
| Aider | `cp integrations/aider/aider.conf.yml .aider.conf.yml && cp integrations/aider/CONVENTIONS.md .` |
| Antigravity | `cp integrations/antigravity/GEMINI.md .` |
| OpenCode | `cp integrations/opencode/opencode.json .` |

### Paso 3: Proteger ramas en GitHub

Para que GitHub refuerce las mismas reglas que el harness (no push directo a `main`/`develop`):

> **Requisito:** El repo debe ser **público** o tener GitHub Pro.

```bash
# Hacer el repo público (si es privado y sin Pro)
gh repo edit {OWNER}/{REPO} --visibility public --accept-visibility-change-consequences

# Proteger main
gh api -X PUT repos/{OWNER}/{REPO}/branches/main/protection --input - <<'EOF'
{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":{"required_approving_review_count":0,"dismiss_stale_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF

# Proteger develop
gh api -X PUT repos/{OWNER}/{REPO}/branches/develop/protection --input - <<'EOF'
{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":{"required_approving_review_count":0,"dismiss_stale_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF
```

El agente verifica estas protecciones automáticamente al inicio de cada sesión (Paso 3 del protocolo session_start).

### Paso 4: Configurar tu IDE (legacy)

**OpenCode** (`opencode.json` en el proyecto):
```json
{
  "instructions": [
    "AGENTS.md",
    ".agent/protocols/session_start.md",
    ".agent/memory/current-session.json"
  ],
  "mcp": {
    "engram": {
      "type": "local",
      "command": ["engram", "mcp", "--tools=agent"],
      "enabled": true
    }
  }
}
```

**Claude Code** (`.claude/settings.json`):
```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(gh:*)",
      "Bash(python:*)",
      "Bash(node:*)",
      "Read(**)",
      "Write(src/**)",
      "Write(tests/**)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Write(.env:*)"
    ]
  },
  "env": {
    "GIT_AUTHOR_NAME": "Tu Nombre",
    "GIT_AUTHOR_EMAIL": "tu@email.com"
  }
}
```

### Paso 5: Crear estructura de memoria

`.agent/memory/current-session.json`:
```json
{
  "last_updated": "2026-05-01T00:00:00Z",
  "branch": "main",
  "focus": "inicial",
  "next_step": "primera tarea",
  "pending": []
}
```

---

## Listo para Usar

### Session Start (lo que el agente hace al inicio)

1. **Git** → verificar branch, status, última sesión
2. **gh CLI** → listar issues con label `ready`
3. **Engram** → cargar contexto de sesión anterior
4. **Presentar** → resumen al usuario, esperar confirmación

### Ciclo de Trabajo

```
Usuario propone tarea
        ↓
Agente presenta plan
        ↓
Usuario aprueba
        ↓
Agente ejecuta (linter → tests → commit → push → PR)
        ↓
Agente guarda memoria en Engram
        ↓
Agente pregunta: "¿Qué sigue?"
```

---

## Comandos que el Agente Usa

| Comando | Para qué |
|---------|----------|
| `git branch --show-current` | Rama actual |
| `git status --short` | Estado rápido |
| `gh issue list --label ready` | Issues listos |
| `gh pr create --base develop` | Crear PR |
| `python -m ruff check .` | Linter (Python) |
| `pytest tests/ -q` | Tests (Python) |

---

## Estructura que el Agente Crea

```
.proyecto/
├── .agent/
│   ├── agents/           ← especializados
│   ├── protocols/       ← session_start, session_end
│   └── memory/          ← current-session.json
├── docs/
│   └── adr/             ← decisiones arquitecturales
└── .github/
    └── workflows/       ← CI/CD
```

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| gh no autenticado | `gh auth login` |
| Engram no funciona | `pip install engram` o verificar PATH |
| No hay issues `ready` | Crear issue con label `ready` |
| No sabe el stack | Agregar al inicio del AGENTS.md del proyecto |

---

## Notas de Seguridad

- **Nunca commitear** `.env`, keys, tokens
- **gh CLI** usa PAT, no necesita MCP de GitHub
- **Engram** guarda en local, no sube a la nube

---

## Siguiente

El kit está diseñado para evolucionar. El agente sugerirá mejoras en cada sesión.

> "Instrumento de precisión: afínalo a tu flujo."