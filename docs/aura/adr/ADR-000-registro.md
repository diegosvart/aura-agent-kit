# Registro de ADRs

> Índice de Architecture Decision Records del harness. Cada ADR captura una decisión, su
> problema y las alternativas descartadas — el residuo permanente de un spec efímero
> (`docs/aura/specs/`, gitignored). Ver `docs/aura/adr/ADR-TEMPLATE.md` para el formato.

| # | Título | Fecha | Estado | Área |
|---|--------|-------|--------|------|
| [001](ADR-001-task-checkpoint.md) | Protocolo de checkpoint mid-session tras cerrar una unidad de trabajo | 2026-05-14 | accepted | harness |
| [002](ADR-002-adr-en-finish-branch.md) | Integrar escritura de ADR en el flujo de finish-branch | 2026-08-01 | accepted | harness |
| [003](ADR-003-politica-versionado-artefactos.md) | Política de versionado de artefactos generados por el agente | 2026-08-01 | accepted | harness |
| [004](ADR-004-session-start-detecta-prs-abiertas.md) | session_start.md consulta PRs abiertas contra GitHub, no solo estado local | 2026-08-04 | accepted | harness |

## Estados posibles

- `proposed` — decisión propuesta, aún no implementada
- `accepted` — decisión tomada e implementada
- `superseded` — reemplazada por un ADR posterior (referenciar cuál)
- `deprecated` — ya no aplica, sin reemplazo directo
