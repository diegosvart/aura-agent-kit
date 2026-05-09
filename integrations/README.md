# Aura Agent Kit — Multi-IDE Compatibility

> **Principio:** `AGENTS.md` es la fuente de verdad. Los adaptadores son wrappers livianos que lo referencian.
> Actualizar `AGENTS.md` propaga a todos los IDEs automáticamente.

---

## Matriz de Compatibilidad

| IDE | Setup requerido | Archivos a copiar | Destino en tu proyecto |
|-----|----------------|-------------------|------------------------|
| **OpenAI Codex** | Ninguno ✓ | — | `AGENTS.md` ya es leído nativamente |
| **Zed** | Ninguno ✓ | — | `AGENTS.md` ya es leído nativamente |
| **Claude Code** | Mínimo | `claude-code/CLAUDE.md` → raíz | `./CLAUDE.md` |
| | | `claude-code/settings.json` → `.claude/` | `./.claude/settings.json` |
| **GitHub Copilot** | Mínimo | `copilot/copilot-instructions.md` → `.github/` | `./.github/copilot-instructions.md` |
| **Cursor** | Mínimo | `cursor/rules/aura-identity.mdc` → `.cursor/rules/` | `./.cursor/rules/aura-identity.mdc` |
| | | `cursor/rules/aura-workflow.mdc` → `.cursor/rules/` | `./.cursor/rules/aura-workflow.mdc` |
| **Windsurf** | Mínimo | `windsurf/rules/aura-harness.md` → `.windsurf/rules/` | `./.windsurf/rules/aura-harness.md` |
| **Aider** | Mínimo | `aider/aider.conf.yml` → raíz | `./.aider.conf.yml` |
| | | `aider/CONVENTIONS.md` → raíz | `./CONVENTIONS.md` |
| **Antigravity** | Mínimo | `antigravity/GEMINI.md` → raíz | `./GEMINI.md` |
| **OpenCode** | Mínimo | `opencode/opencode.json` → raíz | `./opencode.json` |

---

## Instalación por IDE

### OpenAI Codex / Zed
```bash
# Sin setup. AGENTS.md es leído automáticamente.
# Solo asegurate de que AGENTS.md está en la raíz del proyecto.
```

### Claude Code
```bash
mkdir -p .claude
cp path/to/aura-agent-kit/integrations/claude-code/CLAUDE.md .
cp path/to/aura-agent-kit/integrations/claude-code/settings.json .claude/settings.json
```

### GitHub Copilot
```bash
mkdir -p .github
cp path/to/aura-agent-kit/integrations/copilot/copilot-instructions.md .github/copilot-instructions.md
```

### Cursor
```bash
mkdir -p .cursor/rules
cp path/to/aura-agent-kit/integrations/cursor/rules/aura-identity.mdc .cursor/rules/
cp path/to/aura-agent-kit/integrations/cursor/rules/aura-workflow.mdc .cursor/rules/
```

### Windsurf
```bash
mkdir -p .windsurf/rules
cp path/to/aura-agent-kit/integrations/windsurf/rules/aura-harness.md .windsurf/rules/
```

### Aider
```bash
cp path/to/aura-agent-kit/integrations/aider/aider.conf.yml .aider.conf.yml
cp path/to/aura-agent-kit/integrations/aider/CONVENTIONS.md CONVENTIONS.md
```

### Antigravity
```bash
cp path/to/aura-agent-kit/integrations/antigravity/GEMINI.md GEMINI.md
```

### OpenCode
```bash
cp path/to/aura-agent-kit/integrations/opencode/opencode.json opencode.json
# Editar opencode.json para ajustar model y api key
```

---

## Qué incluye cada adaptador

| Adaptador | Contiene | Referencia externa |
|-----------|----------|-------------------|
| `claude-code/CLAUDE.md` | Entrada + instrucción de cargar AGENTS.md | Sí → `AGENTS.md`, `protocols/router.md` |
| `copilot/copilot-instructions.md` | Identidad + pilares + flujo (inline) | No (Copilot no lo soporta) |
| `cursor/aura-identity.mdc` | Identidad + 7 pilares (alwaysApply) | No (siempre cargado, muy liviano) |
| `cursor/aura-workflow.mdc` | Workflow + router (on-demand) | No |
| `windsurf/aura-harness.md` | Identidad + pilares + flujo (inline) | No |
| `aider/aider.conf.yml` | Instrucción de leer AGENTS.md | Sí → `AGENTS.md`, `protocols/router.md` |
| `aider/CONVENTIONS.md` | Convenciones de commits y branches | No |
| `antigravity/GEMINI.md` | Override de permisos (mínimo) | Sí → `AGENTS.md` nativo |
| `opencode/opencode.json` | Config completa con instructions + MCP | Sí → `AGENTS.md`, `protocols/` |

---

## Notas

- **MCP Engram** solo está disponible en Claude Code y OpenCode. Para otros IDEs, la memoria es manual via `current-session.json`.
- **Antigravity** lee `AGENTS.md` nativamente desde v1.20.3. `GEMINI.md` solo agrega permisos IDE-específicos.
- **Continue.dev** requiere configuración en `~/.continue/config.yaml` (global, no por proyecto). Consultar `opencode/api-keys.md` para referencia de providers.
