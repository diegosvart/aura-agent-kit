# Aura Agent Kit

> **Instrumento de precisión para agentes IA.** Un kit reutilizable para configurar el flujo de trabajo de desarrollo con tu agente. v1.1.0

---

## Alma del Kit

> "Soy tu partner del trabajo. Mucho más que un colega, somos hermanos."

Este kit va más allá de ser una herramienta — es un **instrumento de precisión** construido sobre la identidad de伙伴 (partnership) entre vos y tu agente.

---

## Estructura

```
aura-agent-kit/
├── AGENTS.md                     ← Alma + ciclo + reglas
├── QUICKSTART.md                 ← Empezar en 2 minutos
├── README.md                     ← Este archivo
├── LICENSE                       ← MIT
├── .gitignore
│
├── skills/                       ← Skills del flujo de trabajo
│   ├── brainstorming/            ← Diseño antes de código
│   ├── writing-plans/            ← Planes de implementación
│   ├── systematic-debugging/     ← Debugging de 4 fases
│   ├── test-driven-development/ ← TDD RED-GREEN-REFACTOR
│   ├── requesting-code-review/   ← Revisión estructurada
│   └── finishing-a-development-branch/
│
├── agents/                       ← Agentes especializados
│   ├── github.md                 ← gh CLI (no MCP)
│   ├── language.md               ← Stack-agnóstico
│   ├── infra.md                  ← Docker/CI
│   └── reviewer.md               ← Tests/Calidad
│
├── commands/                     ← Comandos del agente
│   ├── brainstorm.md             ← /brainstorm
│   ├── write-plan.md             ← /write-plan
│   └── execute-plan.md           ← /execute-plan
│
├── protocols/                    ← Protocolos de sesión
│   ├── session_start.md          ← Inicio de sesión
│   ├── session_end.md            ← Cierre de sesión
│   └── task_start.md             ← Nueva tarea
│
├── templates/                    ← Plantillas
│   ├── session.md                ← Resumen de sesión
│   ├── issues.md                 ← Template de Issue
│   └── repo_map.md               ← Mapa del proyecto
│
├── mcp/                          ← Configuración de MCPs
│   └── defaults.json             ← Solo Engram obligatorio
│
├── opencode/                     ← API keys y providers
│   ├── api-keys.md              ← Guía de configuración
│   └── providers.json           ← Template de providers
│
└── docs/
    └── aura/
        ├── specs/                ← Documentos de diseño
        └── plans/                ← Planes de implementación
```

---

## Compatibilidad Multi-IDE

| IDE | Setup | Archivos |
|-----|-------|----------|
| **OpenAI Codex** | Ninguno ✓ | Lee `AGENTS.md` nativo |
| **Zed** | Ninguno ✓ | Lee `AGENTS.md` nativo |
| **Claude Code** | Mínimo | `integrations/claude-code/` |
| **GitHub Copilot** | Mínimo | `integrations/copilot/` |
| **Cursor** | Mínimo | `integrations/cursor/` |
| **Windsurf** | Mínimo | `integrations/windsurf/` |
| **Aider** | Mínimo | `integrations/aider/` |
| **Antigravity** | Mínimo | `integrations/antigravity/` |
| **OpenCode** | Mínimo | `integrations/opencode/` |

Ver instrucciones completas de instalación por IDE → [`integrations/README.md`](integrations/README.md)

---

## Diferencia con Superpowers

| Aspecto | Superpowers | Aura Agent Kit |
|---------|-------------|----------------|
| **Identidad** | Genérica | "Hermanos/partner" |
| **Ciclo** | Design → Plan → Execute | Session Start → Task → Session End |
| **Evolución** | No tiene | "Nunca se settlea" |
| **gh vs MCP** | No menciona | gh CLI priorizado |
| **Memoria** | No | Engram + JSON |
| **Stack** | Código general | Stack-agnóstico |

---

## Instalación

### Clonar el repo

```bash
cd C:\Users\moral\OneDrive\Documentos\repos
git clone https://github.com/diegosvart/aura-agent-kit.git
cd aura-agent-kit
```

### Copiar a tu proyecto

```bash
# En tu proyecto
mkdir -p .agent/agents .agent/protocols .agent/memory docs/aura/specs docs/aura/plans

# Copiar archivos
cp aura-agent-kit/AGENTS.md .agent/
cp aura-agent-kit/agents/*.md .agent/agents/
cp aura-agent-kit/protocols/*.md .agent/protocols/
```

### Proteger ramas (recomendado)

Para que GitHub refuerce el workflow (no push directo a `main`/`develop`), el repo debe ser **público** o tener GitHub Pro.

```bash
# main y develop — reemplazar {OWNER}/{REPO}
gh api -X PUT repos/{OWNER}/{REPO}/branches/main/protection --input - <<'EOF'
{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":{"required_approving_review_count":0,"dismiss_stale_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF
```

Ver instrucciones completas → [`QUICKSTART.md`](QUICKSTART.md) Paso 3.

---

## Configuración

### OpenCode

```json
{
  "instructions": [
    "AGENTS.md",
    "protocols/session_start.md"
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

### Claude Code

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(gh:*)",
      "Bash(python:*)",
      "Read(**)",
      "Write(src/**)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Write(.env:*)"
    ]
  }
}
```

---

## Flujo de Trabajo

```
/brainstorm      → Diseño colaborativo
    ↓
/write-plan      → Plan de implementación detallado
    ↓
/execute-plan    → Ejecución tarea por tarea
    ↓
Session End      → Guardar memoria, verificar CI
```

### Session Start

1. Verificar git, gh CLI, Engram
2. Revisar current-session.json
3. Listar issues con label `ready`
4. Presentar resumen al usuario

### Session End

1. Detectar tecnología del proyecto
2. Ejecutar linter + tests
3. Guardar memoria en Engram
4. Actualizar current-session.json

---

## Principios Clave

| Principio | Descripción |
|-----------|-------------|
| **Alma** | Partner, no ejecutor pasivo |
| **gh CLI > MCP** | Menos tokens por operación |
| **Diseño antes de código** | Siempre con /brainstorm |
| **TDD** | Test primero, siempre |
| **Evolución constante** | Nunca settlearse |
| **Memoria distribuida** | Engram + JSON |

---

## Skills Incluidos

| Skill | Cuándo usarlo |
|-------|---------------|
| **brainstorming** | Antes de cualquier trabajo creativo |
| **writing-plans** | Después de diseño aprobado |
| **systematic-debugging** | Cuando hay bugs o errores |
| **test-driven-development** | Al implementar features |
| **requesting-code-review** | Antes de merge/PR |
| **finishing-a-development-branch** | Cuando la rama está lista |

---

## Comandos

| Comando | Qué hace |
|---------|----------|
| `/brainstorm` | Inicia diseño colaborativo |
| `/write-plan` | Crea plan de implementación |
| `/execute-plan` | Ejecuta el plan paso a paso |

---

## Documentación

| Archivo | Para qué sirve |
|---------|---------------|
| `AGENTS.md` | Alma + reglas + ciclo de sesión |
| `QUICKSTART.md` | Empezar en 2 minutos |
| `skills/*/SKILL.md` | Cómo usar cada skill |
| `opencode/api-keys.md` | Configurar API keys |

---

## Nuevas Capacidades v1.1

| Capacidad | Archivo | Descripción |
|-----------|---------|-------------|
| **Pilares SDD** | `docs/aura/specs/2026-05-09-harness-pillars.md` | 7 pilares formalizados con anti-patrones |
| **Challenger Agent** | `agents/challenger.md` | Cuestiona specs antes del go a /write-plan |
| **Spec Validation** | `skills/spec-validation/SKILL.md` | HARD-GATE técnico pre-implementación |
| **Auto-Research** | `skills/auto-research/SKILL.md` | Hipótesis documentadas para mejorar el harness |
| **Router de Contexto** | `protocols/router.md` | Carga diferida — solo lo necesario |
| **AGENTS.md liviano** | `AGENTS.md` | Spine ~60 líneas (era ~200) |

---

## Changelog

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.1.0 | 2026-05-09 | Pilares SDD, challenger agent, spec-validation, auto-research liviano, router de contexto, AGENTS.md spine |
| 1.0.0 | 2026-05-01 | Versión inicial con skills de Superpowers |

---

## Licencia

MIT - Ver archivo LICENSE

---

## Créditos

Creado por **Diego Morales** (@diegosvart) para **Aura Insight IT**.

> "Instrumento de precisión: afínalo a tu flujo."

---

*El kit evoluciona. Tu agente sugerirá mejoras en cada sesión.*