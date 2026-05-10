# SDD — Session Onboarding: Capability Discovery + Stack Selection

**Fecha:** 2026-05-09
**Issue:** #9
**Estado:** Aprobado

---

## Problema

Al iniciar sesión el agente no presenta las capacidades disponibles ni captura el stack tecnológico. El usuario no sabe qué puede hacer el harness ni con qué herramientas trabaja en esta sesión.

**Síntomas:**
- Paso 7 pregunta "¿Continuamos o algo nuevo?" sin mostrar opciones
- El stack se auto-detecta en cada tarea pero no se persiste ni se confirma
- Un usuario nuevo no puede descubrir comandos como `/doc-check`, `/brainstorm`, `/auto-research`

---

## Decisiones de Diseño

### D1 — Capability menu en Paso 7

El Paso 7 se reemplaza por un menú estructurado con secciones contextuales. Las secciones que no aplican se omiten (ej. "Continuar trabajo" solo si hay issues `ready`).

**Por qué aquí:** Es el punto natural post-resumen, antes de cualquier acción. No requiere protocolo nuevo.

### D2 — Stack detection antes del menú (nuevo Paso 8)

El stack se detecta en Paso 8 (antes de que el usuario elija acción). Flujo:
1. Buscar archivos de configuración del proyecto
2. Si encontrado → confirmar con usuario
3. Si no encontrado → activar `skills/stack-selection/SKILL.md`
4. Escribir `.agent/memory/session-stack.json`

**Por qué Paso 8 y no dentro de Paso 7:** El stack es contexto de sesión, no una acción. Tenerlo resuelto antes del menú permite mostrar `**Stack activo:**` en el menú.

### D3 — session-stack.json como fuente de verdad del stack

El archivo `.agent/memory/session-stack.json` persiste el stack de la sesión. Lo leen:
- `agents/language.md` — para linter, test runner, package manager
- `protocols/task_start.md` — para cargar herramientas correctas
- El capability menu — para mostrar "Stack activo"

**Prioridad de stack:** session-stack.json > auto-detección de archivos > default Python

### D4 — Stack selection como skill reutilizable

`skills/stack-selection/SKILL.md` es invocado tanto desde session_start (Paso 8) como desde el comando `/stack` mid-session. El usuario puede cambiar de stack en cualquier momento.

### D5 — Lista numerada de 24 perfiles + opción custom

UX: lista numerada agrupada por categoría. El usuario escribe el número o "0" para custom. Si elige custom, el agente hace 4 preguntas cortas (lenguaje, tipo, base de datos, testing).

### D6 — Perfiles cubren los stacks prioritarios del usuario

8 categorías × 3 variantes = 24 perfiles. Prioridad: TypeScript full-stack, Python (FastAPI/Django), Python integrations, AI/LLM, Go.

### D7 — Wizard para nuevo proyecto

Cuando el usuario elige "Crear proyecto desde cero" en el capability menu, el agente:
1. Activa stack-selection para elegir el stack
2. Sugiere estructura de directorios inicial
3. Ofrece crear el repo en GitHub
4. Crea el primer issue de setup

---

## Perfiles de Stack — Catálogo Completo

### Web Frontend
| ID | Nombre | Stack |
|----|--------|-------|
| 1 | react-spa | React + TypeScript + Vite + Tailwind + Vitest |
| 2 | nextjs-app | Next.js + TypeScript + Tailwind + Playwright |
| 3 | vue3 | Vue 3 + TypeScript + Vite + Tailwind + Vitest |

### API Backend — Python
| ID | Nombre | Stack |
|----|--------|-------|
| 4 | fastapi | Python + FastAPI + SQLAlchemy + PostgreSQL + pytest |
| 5 | django-rest | Python + Django REST Framework + PostgreSQL + pytest |
| 6 | flask-lite | Python + Flask + SQLAlchemy + SQLite + pytest |

### API Backend — TypeScript/Node
| ID | Nombre | Stack |
|----|--------|-------|
| 7 | express-ts | Node.js + Express + TypeScript + Prisma + PostgreSQL + Jest |
| 8 | fastify-ts | Fastify + TypeScript + Drizzle + PostgreSQL + Vitest |
| 9 | hono-bun | Hono + TypeScript + Bun + SQLite + Vitest |

### Full Stack TypeScript
| ID | Nombre | Stack |
|----|--------|-------|
| 10 | t3-stack | Next.js + TypeScript + Prisma + PostgreSQL + tRPC |
| 11 | remix | Remix + TypeScript + Prisma + PostgreSQL + Vitest |
| 12 | nuxt | Nuxt.js + TypeScript + Drizzle + PostgreSQL + Vitest |

### Integración / Automatización
| ID | Nombre | Stack |
|----|--------|-------|
| 13 | python-webhooks | Python + httpx + Pydantic + GitHub Actions + pytest |
| 14 | python-pipelines | Python + Prefect + SQLAlchemy + PostgreSQL + pytest |
| 15 | node-automation | TypeScript + Node + Axios + Bun + cron + Vitest |

### AI / LLM Apps
| ID | Nombre | Stack |
|----|--------|-------|
| 16 | anthropic-fastapi | Python + Anthropic SDK + FastAPI + pgvector + pytest |
| 17 | vercel-ai | TypeScript + Vercel AI SDK + Next.js + pgvector + Vitest |
| 18 | langchain | Python + LangChain + FastAPI + Chroma + pytest |

### Go
| ID | Nombre | Stack |
|----|--------|-------|
| 19 | gin-gorm | Go + Gin + GORM + PostgreSQL + testify |
| 20 | echo-sqlc | Go + Echo + sqlc + PostgreSQL + testify |
| 21 | fiber-ent | Go + Fiber + Ent + PostgreSQL + testify |

### CLI / Herramientas
| ID | Nombre | Stack |
|----|--------|-------|
| 22 | python-typer | Python + Typer + Rich + pytest |
| 23 | go-cobra | Go + Cobra + pflag + testify |
| 24 | rust-clap | Rust + clap + tokio + cargo test |

**Opción 0:** Custom — 4 preguntas para stack libre

---

## Formato session-stack.json

```json
{
  "profile_id": 4,
  "profile_name": "fastapi",
  "detected_from": "pyproject.toml",
  "language": "python",
  "framework": "fastapi",
  "test_runner": "pytest",
  "linter": "ruff",
  "package_manager": "poetry",
  "database": "postgresql",
  "extras": ["docker", "sqlalchemy"],
  "confirmed_at": "2026-05-09T10:00:00Z"
}
```

---

## Anti-patrones

| Anti-patrón | Por qué evitarlo |
|-------------|-----------------|
| Preguntar el stack en cada tarea | session-stack.json persiste la elección para toda la sesión |
| Mostrar todas las secciones del menú siempre | Ruido — solo mostrar lo que aplica al contexto actual |
| Duplicar stack info en session.json y session-stack.json | Dos fuentes de verdad → inconsistencia |
| Auto-seleccionar stack sin confirmar | El usuario puede tener múltiples pyproject.toml |
