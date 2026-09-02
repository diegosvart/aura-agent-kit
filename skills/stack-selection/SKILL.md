---
name: stack-selection
description: Detecta o selecciona el stack tecnológico de la sesión y lo persiste en session-stack.json. Usar al iniciar sesión sin stack detectado, o al invocar /stack.
---

# Skill — Stack Selection

> **Cuándo usar:** Al iniciar sesión si no hay `session-stack.json`, o cuando el usuario invoca `/stack`.
> **Output:** Escribe `.agent/memory/session-stack.json` con el stack confirmado.

---

## Flujo

### Paso 1 — Detectar stack existente

Buscar en la raíz del proyecto:

```
pyproject.toml / setup.py / setup.cfg  → Python
package.json                            → Node.js / TypeScript
Cargo.toml                              → Rust
go.mod                                  → Go
*.csproj / *.sln                        → C# / .NET
```

Si se detecta un archivo de configuración, inferir framework desde su contenido:
- `pyproject.toml` con `fastapi` → perfil `fastapi` (ID 4)
- `pyproject.toml` con `django` → perfil `django-rest` (ID 5)
- `package.json` con `next` → perfil `nextjs-app` (ID 2)
- `package.json` con `express` → perfil `express-ts` (ID 7)
- etc.

### Paso 2 — Confirmar o seleccionar

**Si se detectó stack:**
```
Detecté: Python + FastAPI (desde pyproject.toml)
→ Perfil sugerido: #4 fastapi

¿Usamos este stack? [S/n] o escribí otro número para cambiar.
```

**Si no se detectó:**
Mostrar el catálogo completo:

```
## ¿Qué stack usamos en esta sesión?

**Web Frontend**
  1. React SPA       — React + TypeScript + Vite + Tailwind + Vitest
  2. Next.js App     — Next.js + TypeScript + Tailwind + Playwright
  3. Vue 3           — Vue 3 + TypeScript + Vite + Tailwind + Vitest

**API Backend — Python**
  4. FastAPI         — Python + FastAPI + SQLAlchemy + PostgreSQL + pytest
  5. Django REST     — Python + Django REST Framework + PostgreSQL + pytest
  6. Flask Ligero    — Python + Flask + SQLAlchemy + SQLite + pytest

**API Backend — TypeScript/Node**
  7. Express TS      — Node.js + Express + TypeScript + Prisma + PostgreSQL + Jest
  8. Fastify TS      — Fastify + TypeScript + Drizzle + PostgreSQL + Vitest
  9. Hono/Bun        — Hono + TypeScript + Bun + SQLite + Vitest

**Full Stack TypeScript**
 10. T3 Stack        — Next.js + TypeScript + Prisma + PostgreSQL + tRPC
 11. Remix           — Remix + TypeScript + Prisma + PostgreSQL + Vitest
 12. Nuxt            — Nuxt.js + TypeScript + Drizzle + PostgreSQL + Vitest

**Integración / Automatización**
 13. Python Webhooks — Python + httpx + Pydantic + GitHub Actions + pytest
 14. Python Pipelines— Python + Prefect + SQLAlchemy + PostgreSQL + pytest
 15. Node Automation — TypeScript + Node + Axios + Bun + cron + Vitest

**AI / LLM Apps**
 16. Anthropic + FastAPI — Python + Anthropic SDK + FastAPI + pgvector + pytest
 17. Vercel AI SDK   — TypeScript + Vercel AI SDK + Next.js + pgvector + Vitest
 18. LangChain       — Python + LangChain + FastAPI + Chroma + pytest

**Go**
 19. Gin + GORM      — Go + Gin + GORM + PostgreSQL + testify
 20. Echo + sqlc     — Go + Echo + sqlc + PostgreSQL + testify
 21. Fiber + Ent     — Go + Fiber + Ent + PostgreSQL + testify

**CLI / Herramientas**
 22. Python Typer    — Python + Typer + Rich + pytest
 23. Go Cobra        — Go + Cobra + pflag + testify
 24. Rust Clap       — Rust + clap + tokio + cargo test

  0. Custom          — Definir stack libre (4 preguntas)

> Escribí el número del perfil.
```

### Paso 3 — Flujo custom (si eligió 0)

Hacer 4 preguntas cortas, una por vez:

```
1. ¿Lenguaje principal? (Python / TypeScript / Go / Rust / Otro)
2. ¿Tipo de proyecto? (Web / API / CLI / Automatización / AI / Otro)
3. ¿Base de datos? (PostgreSQL / MySQL / MongoDB / SQLite / Ninguna)
4. ¿Framework de testing? (pytest / vitest / jest / go test / Otro)
```

### Paso 4 — Escribir session-stack.json

Una vez confirmado el perfil, escribir en `.agent/memory/session-stack.json`:

```json
{
  "profile_id": <número>,
  "profile_name": "<nombre-del-perfil>",
  "detected_from": "pyproject.toml | package.json | Cargo.toml | go.mod | user-selection | custom",
  "language": "<lenguaje>",
  "framework": "<framework>",
  "test_runner": "<test-runner>",
  "linter": "<linter>",
  "package_manager": "<package-manager>",
  "database": "<base-de-datos | null>",
  "extras": [],
  "confirmed_at": "<ISO timestamp>"
}
```

---

## Tabla de Perfiles — Detalle Completo

| ID | Nombre | Lenguaje | Framework | Linter | Test Runner | Package Mgr | DB |
|----|--------|----------|-----------|--------|-------------|-------------|-----|
| 1 | react-spa | TypeScript | React + Vite | eslint | vitest | npm/pnpm | — |
| 2 | nextjs-app | TypeScript | Next.js | eslint | playwright | npm/pnpm | — |
| 3 | vue3 | TypeScript | Vue 3 + Vite | eslint | vitest | npm/pnpm | — |
| 4 | fastapi | Python | FastAPI | ruff | pytest | poetry | PostgreSQL |
| 5 | django-rest | Python | Django REST | ruff | pytest | poetry | PostgreSQL |
| 6 | flask-lite | Python | Flask | ruff | pytest | pip | SQLite |
| 7 | express-ts | TypeScript | Express | eslint | jest | npm | PostgreSQL |
| 8 | fastify-ts | TypeScript | Fastify | eslint | vitest | npm/pnpm | PostgreSQL |
| 9 | hono-bun | TypeScript | Hono | eslint | vitest | bun | SQLite |
| 10 | t3-stack | TypeScript | Next.js + tRPC | eslint | vitest | npm/pnpm | PostgreSQL |
| 11 | remix | TypeScript | Remix | eslint | vitest | npm/pnpm | PostgreSQL |
| 12 | nuxt | TypeScript | Nuxt.js | eslint | vitest | npm/pnpm | PostgreSQL |
| 13 | python-webhooks | Python | httpx + Pydantic | ruff | pytest | pip/poetry | — |
| 14 | python-pipelines | Python | Prefect | ruff | pytest | poetry | PostgreSQL |
| 15 | node-automation | TypeScript | Node + Axios | eslint | vitest | bun | — |
| 16 | anthropic-fastapi | Python | Anthropic SDK + FastAPI | ruff | pytest | poetry | pgvector |
| 17 | vercel-ai | TypeScript | Vercel AI + Next.js | eslint | vitest | npm/pnpm | pgvector |
| 18 | langchain | Python | LangChain + FastAPI | ruff | pytest | poetry | Chroma |
| 19 | gin-gorm | Go | Gin + GORM | golangci-lint | go test / testify | go mod | PostgreSQL |
| 20 | echo-sqlc | Go | Echo + sqlc | golangci-lint | go test / testify | go mod | PostgreSQL |
| 21 | fiber-ent | Go | Fiber + Ent | golangci-lint | go test / testify | go mod | PostgreSQL |
| 22 | python-typer | Python | Typer + Rich | ruff | pytest | pip/poetry | — |
| 23 | go-cobra | Go | Cobra + pflag | golangci-lint | go test / testify | go mod | — |
| 24 | rust-clap | Rust | clap + tokio | clippy | cargo test | cargo | — |

---

## Reglas

1. **Nunca auto-seleccionar** sin confirmar con el usuario
2. **Un stack por sesión** — si el usuario cambia de stack mid-session, actualizar session-stack.json
3. **Custom siempre disponible** — nunca forzar un perfil predefinido
4. **Si el usuario nombra tecnologías** (ej. "voy a trabajar en FastAPI"), mapear automáticamente al perfil más cercano y confirmar

---

## Integración con Agentes

Una vez escrito `session-stack.json`, los siguientes agentes lo consumen:
- `agents/language.md` — linter, test runner, package manager
- `protocols/task_start.md` — contexto de herramientas para la tarea
- `protocols/session_end.md` — ejecutar el linter/test correcto

---

## Errores Comunes

| Situación | Acción |
|-----------|--------|
| Múltiples pyproject.toml en el repo | Preguntar cuál es el principal |
| package.json sin framework reconocible | Mostrar lista completa |
| Usuario no sabe su stack | Ofrecer opción 0 (custom con preguntas guiadas) |
| session-stack.json existe pero el usuario quiere cambiar | Sobreescribir con el nuevo |
