# Configuración de API Keys — OpenCode & Claude Code

> **Objetivo:** Unificar la configuración de proveedores de API keys para ambos agentes.

---

## Estructura del Archivo

```
opencode/
└── api-keys.md          ← Este archivo (guía + referencias)
└── providers.json       ← Configuración de providers (reemplaza opencode.json del proyecto)
```

---

## Referencia: Configuración Actual del Proyecto

El proyecto actual usa esta configuración en `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://localhost:11434/v1",
        "apiKey": "ollama"
      },
      "models": {
        "gemma4:e2b-32k": { "name": "gemma4:e2b-32k" },
        "gemma4:e2b": { "name": "gemma4:e2b" }
      }
    }
  },
  "mcp": {
    "engram": {
      "type": "local",
      "command": ["engram", "mcp", "--tools=agent"],
      "enabled": true
    }
  }
}
```

---

## OpenCode — Proveedores

### Cómo agregar un nuevo proveedor

**Paso 1: Agregar credenciales con `/connect`**

```bash
# En OpenCode, ejecutar:
/connect

# Seleccionar el proveedor y pegar la API key
# Las credenciales se almacenan en: ~/.local/share/opencode/auth.json
```

**Paso 2: Configurar el provider en `opencode.json`**

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "mi-proveedor": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Mi Proveedor",
      "options": {
        "baseURL": "https://api.miproveedor.com/v1"
      },
      "models": {
        "mi-modelo": {
          "name": "Mi Modelo"
        }
      }
    }
  }
}
```

### Proveedores Soportados

| Proveedor | npm | Notas |
|-----------|-----|-------|
| OpenAI | (built-in) | |
| Anthropic | (built-in) | |
| Google Gemini | (built-in) | |
| Groq | (built-in) | |
| Azure OpenAI | (built-in) | Requiere endpoint |
| AWS Bedrock | (built-in) | Credenciales AWS |
| Google Vertex AI | (built-in) | Project + Location |
| OpenRouter | (built-in) | |
| Ollama | `@ai-sdk/openai-compatible` | Local, OpenAI-compatible |
| Custom (OpenAI-compatible) | `@ai-sdk/openai-compatible` | Cualquier API REST |
| Custom (Responses API) | `@ai-sdk/openai` | Si usa `/v1/responses` |

### Variables de Entorno en Config

```json
{
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}"
      }
    },
    "openai": {
      "options": {
        "apiKey": "{file:~/.secrets/openai-key}"
      }
    }
  }
}
```

**Sintaxis:**
- `{env:VARIABLE}` → toma valor de variable de entorno
- `{file:path}` → lee clave desde archivo

---

## Claude Code — Proveedores

### Cómo configurar API Keys

**Opción 1: Variables de entorno (recomendado)**

```bash
# En tu shell (~/.bashrc, ~/.zshrc, etc.)
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Opción 2: En `settings.json`**

```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-..."
  }
}
```

### Variables de Entorno Principales

| Variable | Propósito |
|----------|-----------|
| `ANTHROPIC_API_KEY` | API key directa (prioriza sobre suscripción) |
| `ANTHROPIC_MODEL` | Modelo por defecto |
| `ANTHROPIC_BASE_URL` | Proxy/gateway custom |
| `ANTHROPIC_TIMEOUT` | Timeout en ms (default: 60000) |

### Proveedores Alternativos

#### AWS Bedrock

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

#### Google Vertex AI

```bash
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION="us-east5"
export ANTHROPIC_VERTEX_PROJECT_ID="your-project-id"
```

#### Microsoft Foundry

```bash
export ANTHROPIC_FOUNDRY_API_KEY="..."
export ANTHROPIC_FOUNDRY_RESOURCE="my-resource"
```

### Ubicación de Configuración

| Scope | Archivo | Notas |
|-------|---------|-------|
| User (global) | `~/.claude/settings.json` | Todos los proyectos |
| Project | `.claude/settings.json` | Compartido con equipo |
| Shell | `~/.bashrc`, `~/.zshrc` | Solo esta sesión |

### Prioridad de Carga

```
CLI flags > environment variables > project settings.json > global settings.json
```

---

## Comparativa: OpenCode vs Claude Code

| Aspecto | OpenCode | Claude Code |
|---------|----------|-------------|
| **Auth principal** | `/connect` + config JSON | `ANTHROPIC_API_KEY` env var |
| **Credenciales** | `~/.local/share/opencode/auth.json` | Env vars o settings.json |
| **Multi-provider** | Soportado (75+ providers) | Principalmente Anthropic |
| **Model override** | Por config | Por env var |
| **Proveedor custom** | npm + config JSON | Solo vía proxy/baseURL |

---

## Proveedores Comunes — Configuración

### Anthropic (Claude)

**OpenCode:**
```json
{
  "model": "anthropic/claude-sonnet-4-6"
}
```
(Se configura automáticamente si tienes credenciales en `/connect`)

**Claude Code:**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Ollama (Local)

**OpenCode:**
```json
{
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://localhost:11434/v1",
        "apiKey": "ollama"
      },
      "models": {
        "llama3": { "name": "Llama 3" },
        "gemma4:e2b": { "name": "Gemma 4" }
      }
    }
  }
}
```

**Claude Code:**
Ollama no es natively soportado. Usar con proxy:
```bash
export ANTHROPIC_BASE_URL="http://localhost:11434/v1"
export ANTHROPIC_API_KEY="ollama"  # Ollama no valida keys locales
```

### OpenAI

**OpenCode:**
```json
{
  "provider": {
    "openai": {
      "options": {
        "apiKey": "{env:OPENAI_API_KEY}"
      },
      "models": {
        "gpt-4o": { "name": "GPT-4o" },
        "gpt-4o-mini": { "name": "GPT-4o Mini" }
      }
    }
  }
}
```

**Claude Code:**
```bash
export ANTHROPIC_API_KEY="sk-..."  # Claude Code solo usa Anthropic
```
(Claude Code no soporta OpenAI directamente)

### Azure OpenAI

**OpenCode:**
```json
{
  "provider": {
    "azure": {
      "options": {
        "baseURL": "https://tu-resource.openai.azure.com",
        "apiKey": "{env:AZURE_OPENAI_API_KEY}"
      },
      "models": {
        "gpt-4o": { "name": "GPT-4o" }
      }
    }
  }
}
```

**Claude Code:**
```bash
export ANTHROPIC_BASE_URL="https://tu-resource.openai.azure.com/openai/deployments/tu-deploy"
export ANTHROPIC_API_KEY="..."
```

---

## Estructura Sugerida para el Harness

```
my-harness/opencode/
├── api-keys.md              ← Este archivo
└── providers.json          ← Template de configuración
```

### providers.json (Template)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-6",
  "provider": {
    "anthropic": {
      "options": {
        "apiKey": "{env:ANTHROPIC_API_KEY}"
      }
    },
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1",
        "apiKey": "ollama"
      },
      "models": {
        "llama3": { "name": "Llama 3 8B" },
        "gemma4:e2b": { "name": "Gemma 4 2B" }
      }
    }
  },
  "mcp": {
    "engram": {
      "type": "local",
      "command": ["engram", "mcp", "--tools=agent"],
      "enabled": true
    }
  }
}
```

---

## Notas de Seguridad

| Práctica | OpenCode | Claude Code |
|----------|----------|-------------|
| **Nunca hardcodear keys** | Usar `{env:...}` | Usar env vars |
| **Archivo de keys** | `{file:path}` | No soportado |
| **Protegidos por defecto** | `.env` no accesible | `.env` en deny list |
| **Rotación** | `opencode auth list` | Revocar en consola |

---

## Referencias

- [OpenCode Providers](https://opencode.ai/docs/providers/)
- [OpenCode Config](https://opencode.ai/docs/config/)
- [Claude Code Env Vars](https://code.claude.com/docs/en/env-vars)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)