---
status: approved
---

# Plan — Clasificación de repos y política de memoria segura

**Spec:** `docs/aura/specs/2026-09-17-memoria-clasificacion-repos-design.md` (spec-validation PASS, challenger GO)

## Contexto

Engram guarda memoria en un SQLite local sin distinguir el tipo de repo. `mem_save` depende
100% de que el agente note si algo es sensible — mismo patrón que ya causó un incidente real
(folios/OC reales de un cliente filtrados a un plan versionado, ver
`.claude/rules/sensitive-data-safety.md`). Objetivo de fondo: estabilizar Aura Agent Kit
priorizando seguridad/privacidad sobre continuidad de memoria entre equipos (sync cross-machine
descartado por ahora — usuario trabaja en ≤5 repos a la vez).

Decisiones acordadas en brainstorm: clasificación declarativa explícita (D1), 3 categorías
`harness`/`personal`/`cliente` (D2), política de memoria por categoría (D3), enforcement
híbrido instrucción + hook duro (D4).

## Pasos

### Paso 1 — Spike: viabilidad del hook sobre `mem_save`
- **Qué:** Confirmar si `PreToolUse` puede matchear una tool MCP
  (`mcp__plugin_engram_engram__mem_save`) igual que matchea `Bash`. Si no es viable, D4 degrada
  a enforcement solo por instrucción — decidirlo acá, no a mitad de implementación.
- **Archivos:** ninguno (investigación) o un hook de prueba descartable
- **Seguridad:** ninguna — solo lectura/prueba local
- **Despacho:** INLINE (bloquea el resto del plan, resultado condiciona los pasos 3-4)

### Paso 2 — Esquema de clasificación
- **Qué:** Crear `.agent/memory/repo-classification.json` (este repo = `harness`) + lectura en
  `protocols/session_start.md` (pregunta bloqueante si falta) + paso de completarlo en
  `/new-project` y `/stack`
- **Archivos:** `.agent/memory/repo-classification.json`, `protocols/session_start.md`,
  `skills/new-project-setup/SKILL.md`, `skills/stack-selection/SKILL.md`
- **Seguridad:** archivo versionado, sin datos sensibles
- **Despacho:** DELEGAR (fork, aislable — no depende del hilo vivo)

### Paso 3 — Enforcement capa 1 (skill)
- **Qué:** Extender el skill de memoria de Engram con la tabla D3 — qué guardar según
  `repo_type`
- **Archivos:** skill de memoria de Engram (ruta exacta a confirmar en el spike)
- **Seguridad:** ninguna
- **Despacho:** DELEGAR (fork)

### Paso 4 — Enforcement capa 2 (hook duro), condicionado al resultado del Paso 1
- **Qué:** Si es viable, extender `.claude/hooks/sensitive-data-guard.ps1` (no crear uno
  nuevo — reusar matching existente) para interceptar `mem_save` cuando
  `repo_type == "cliente"`, reutilizando `.claude/sensitive-terms.local.txt`
- **Archivos:** `.claude/hooks/sensitive-data-guard.ps1` + su test
- **Seguridad:** cambio a hook de enforcement — requiere TDD (RED→GREEN) antes de mergear
- **Despacho:** INLINE (rama sensible de seguridad) o DELEGAR con verificación estricta — a
  decidir en la sesión de implementación según cómo salga el spike

### Paso 5 — Gobierno
- **Qué:** Sumar `repo-classification.json` a la tabla "Qué se Versiona" de `AGENTS.md`, y
  extender `.claude/rules/sensitive-data-safety.md` con el nuevo caso de `mem_save`
- **Archivos:** `AGENTS.md`, `.claude/rules/sensitive-data-safety.md`
- **Seguridad:** ninguna
- **Despacho:** INLINE (documentación de reglas del harness — bajo volumen)

### Paso 6 — PR + review + issue de seguimiento si el spike descarta el hook
- **Despacho:** INLINE (`agents/github.md`)

## Fuera de Alcance

- Sync de memoria entre máquinas (Git Sync / Engram Cloud) — evaluado y descartado por ahora.
- Separar `aura-agent-kit` en repo público (core) + repo privado (bitácora personal) — mejora
  futura relacionada, no depende de esta spec.
- Retención/expiración de memoria (TTL).

## Aprobación

Usuario: "Go" (2026-09-17). Próxima sesión arranca directo en Paso 1 (spike).
