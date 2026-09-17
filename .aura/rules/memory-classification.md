# Memory Classification — Política de `mem_save` por Tipo de Repo

## Regla principal (Issue #303, D3)

Antes de cada `mem_save`, leer `.agent/memory/repo-classification.json` si existe (ver
`protocols/session_start.md` → Gate de Clasificación de Repo) y aplicar la tabla D3 según
`repo_type`:

| `repo_type` | Qué puede guardar `mem_save` | Scope por defecto |
|---|---|---|
| `harness` | Todo — es el propio dogfooding, ya público | `project` |
| `personal` | Todo — sin terceros expuestos | `project` |
| `cliente` | **Prohibido:** nombres reales de cliente/empresa, RUTs, IPs internas, credenciales, montos/folios/datos de negocio real, nombres de personas reales del cliente. **Permitido:** decisiones técnicas, patrones, bugs, convenciones — usando placeholders genéricos (`<cliente>`, `ACME`) igual que ya exige `.claude/rules/sensitive-data-safety.md` para contenido versionado | `project`, con el mismo checklist de sensibilidad aplicado al **texto a guardar**, no solo a diffs de git |

Si `.agent/memory/repo-classification.json` no existe todavía, el Gate de
`protocols/session_start.md` ya bloquea la sesión con una pregunta antes de continuar — no
debería llegarse a un `mem_save` sin clasificación resuelta.

## Por qué esta regla vive acá y no en el skill de memoria de Engram

El skill `engram:memory` (protocolo "cuándo guardar") vive fuera de este repositorio, en el
plugin instalado globalmente (`~/.claude/plugins/cache/engram/engram/<version>/skills/memory/SKILL.md`)
— no es un archivo versionado de `aura-agent-kit`, no se puede editar desde acá de forma que
el cambio viaje con el repo (una edición local se pierde en la próxima actualización del
plugin y no se comparte con otro consumidor del harness). Esta regla es el puente: vive en
`.aura/rules/`, versionada junto al resto del harness, y complementa — no reemplaza — el
protocolo proactivo de guardado que ya trae el skill del plugin.

**Pendiente de decisión (fuera del alcance de este archivo):** si esta regla debe sumarse a la
lista de "6 reglas fijas" que `CLAUDE.md`/`AGENTS.md` cargan siempre (`harness-core`,
`design-flow`, `repo-integrity`, `routing-menu`, `coding`, `subagent-dispatch`) — eso cambia
un número que `AGENTS.md` documenta explícitamente como fijo para ambos roles del repo (Rol A
dogfooding / Rol B dependencia embebida) y no es una decisión que corresponda tomar dentro del
Paso 3 del plan de Issue #303. Por ahora, `protocols/session_start.md` referencia este archivo
desde el Gate de Clasificación de Repo (Paso 3) para que quede alcanzable sin forzar ese
cambio de alcance.

## Excepciones

Ninguna — mismo criterio que `.claude/rules/sensitive-data-safety.md`, del cual esta regla es
una extensión a la superficie de `mem_save` (MCP), no cubierta hasta ahora (esa regla cubre
commits/PRs/issues/archivos versionados, no llamadas MCP).
