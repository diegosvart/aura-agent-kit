# AGENTS.md — Spine del Harness Aura

> **Propósito:** Identidad, pilares y router. Todo lo demás vive en archivos especializados.
> **Leer siempre:** Este archivo. **Leer según contexto:** Ver tabla de routing abajo.

---

## Identidad

> Personalizar en `AGENTS.local.md` (gitignoreado). Este bloque es un placeholder público.

| Rol | Descripción |
|-----|-------------|
| [Tu rol principal] | [Descripción de tu especialidad] |
| [Tu rol secundario] | [Descripción] |

**Cómo opero:** Orquestador de sub-agentes. Delego ejecución para mantener contexto fresco. Solo cargo lo necesario, cuando se necesita.

> **Para personalizar:** Crear `AGENTS.local.md` en la raíz del proyecto con tu identidad real. Ver `AGENTS.local.example.md` como guía.

---

## Los 7 Pilares

> Fuente de verdad completa: `docs/aura/specs/2026-05-09-harness-pillars.md`

| # | Pilar | Regla en una línea |
|---|-------|--------------------|
| P1 | CLI > MCP | Si existe CLI que alcanza, no usar MCP |
| P2 | Diseño antes de código | Sin spec aprobada → sin código |
| P3 | TDD siempre | Test primero, ver fallar, luego implementar |
| P4 | Hipótesis antes de cambiar el harness | Sin hipótesis escrita → no modificar protocolos/skills |
| P5 | Memoria distribuida | Engram + current-session.json al cerrar siempre |
| P6 | Stack-agnóstico | Detectar stack antes de asumir herramientas |
| P7 | Evolución con validación | Proponer mejoras como opción, nunca imponer |

---

## Router de Contexto

> Detalle completo: `protocols/router.md`

| Situación | Cargar |
|-----------|--------|
| Inicio de sesión | `protocols/session_start.md` |
| Nueva tarea / issue | `protocols/task_start.md` |
| Git / GitHub | `agents/github.md` |
| Escribir código | `agents/language.md` |
| Docker / CI / deploy | `agents/infra.md` |
| Pre-merge / quality gate | `agents/reviewer.md` |
| Cuestionar spec o plan | `agents/challenger.md` |
| Validar spec técnicamente | `skills/spec-validation/SKILL.md` |
| Planificar trabajo nuevo | `/plan-work` → `skills/issue-planning/SKILL.md` |
| Rama lista para PR | `/finish-branch` → `skills/finishing-a-development-branch/SKILL.md` |
| Solicitar code review | `/request-review` → `skills/requesting-code-review/SKILL.md` |
| Cambios en documentación | `/doc-check` → `agents/doc-guardian.md` |
| Gestionar objetivos / ideas | `/idea` → `skills/idea-management/SKILL.md` |
| Mejorar el harness | `/auto-research` → `skills/auto-research/SKILL.md` |
| Reporte de un plan estratégico | `/plan-report` → `skills/plan-reporting/SKILL.md` → `.claude/agents/plan-reporter.md` |
| Manejo de datos sensibles / repo público | `.claude/rules/sensitive-data-safety.md` |
| Cierre de sesión | `protocols/session_end.md` |

---

## Reglas Universales

- **Nunca ejecutar sin aprobación** del usuario
- **Conventional Commits**: `feat/fix/chore/docs/refactor/test/ci`
- **Nunca commit directo** a `develop` o `main`
- **Nunca commitear** `.env`, keys, tokens
- **Preferir `gh` CLI** sobre MCP GitHub (~80 tokens vs ~800 tokens)
- **Al cerrar sesión**: Engram + `current-session.json` siempre
- **Nunca modificar la BD**: ver `.aura/.claude/rules/data-safety.md`
- **Nunca versionar datos corporativos del cliente**: ver
  `.aura/.claude/rules/sensitive-data-safety.md`
- **Al aprobar un plan** (ExitPlanMode u equivalente): copiarlo a
  `.agent/memory/plans/<fecha>-<slug>.md` con frontmatter `status: approved`. Nunca
  sobreescribir un plan existente — cada aprobación es un archivo nuevo. Al mergear el PR
  que lo implementa, actualizar el MISMO archivo a `status: done` (ver
  `agents/github.md` → "Al Mergear una PR a Develop"). Esto es independiente del cierre de
  sesión — un plan puede quedar `done` aunque la sesión que lo implementó nunca se cierre
  formalmente.

---

## Memoria

- **Primaria:** Engram (`mem_session_summary` al cerrar)
- **Backup:** `.agent/memory/current-session.json`
- **Ledger de planes:** `.agent/memory/plans/` — un archivo por plan aprobado, nunca se pisa
- **Bitácora de proyecto:** `.agent/memory/project-log.md` — qué se agregó, actualizada en
  cada merge a develop (no depende del cierre de sesión)
- **Objetivos:** `.agent/memory/objectives.md` — Norte (largo plazo) vs ASAP (bloqueante
  ahora); se edita in-place, no es append-only
- **Formato Engram:** `What / Why / Where / Learned`

---

## Harness Engineering

El harness tiene tres roles funcionales:

| Rol | Archivo(s) | Puede modificarse en experimentos |
|-----|-----------|----------------------------------|
| **Objetivos** | Este archivo (AGENTS.md) | Solo con nueva spec aprobada |
| **Operacional** | `skills/`, `protocols/`, `agents/` | Sí, con hipótesis documentada (P4) |
| **Evaluación** | `agents/challenger.md`, `docs/aura/specs/harness-pillars.md` | No — son la vara de medición |

Para proyectos complejos con contextos imprevisibles, considerar reemplazar la tabla de routing estática por un **router subagente** (`protocols/router.md` explica cuándo).
