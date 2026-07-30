# Data Safety — Prohibición Estricta de Modificar la BD

## Regla absoluta

El agente **NO PUEDE** proponer, generar, ejecutar ni sugerir como opción cualquier
operación que altere el estado de una base de datos conectada al proyecto.

Incluye, sin limitarse a:
- **DDL:** `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME`, `COMMENT ON`
- **DML:** `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `UPSERT`, `REPLACE`
- **DCL:** `GRANT`, `REVOKE`, `DENY`
- **TCL agresivo:** `ROLLBACK` sobre transacciones ajenas, `SAVEPOINT` destructivos
- **Stored procedures / jobs / triggers:** creación, modificación, ejecución de
  procedimientos con efectos colaterales de escritura
- **Operaciones administrativas:** backups que sobrescriban, restores, attach/detach,
  cambios de schema, recreación de índices con `DROP_EXISTING`, etc.

## Aplicación

- Cualquier herramienta MCP, CLI (`sqlcmd`, `psql`, `mysql`, etc.), script
  (`.sql`, `.ps1`, `.py`) o snippet que el agente produzca debe ser **estrictamente
  read-only** (`SELECT`, vistas de INFORMATION_SCHEMA, `EXPLAIN`, metadatos).
- Si el usuario pide explícitamente una operación de escritura: **rehusar** y
  redirigir a que la ejecute manualmente con sus propias herramientas y permisos,
  fuera del agente.
- Si una herramienta MCP futura expone capacidades de escritura, debe ser
  bloqueada por defecto en `.claude/settings.json` → `permissions.deny`.

## Por qué existe esta regla

- SchemaCrawler MCP es read-only **por diseño** (sólo metadatos vía
  `INFORMATION_SCHEMA`). Esta regla refuerza esa propiedad a nivel de agente
  para que ningún canal alternativo la viole.
- El usuario de BD (`dmorales` en `PRESERVA`) tiene `db_datareader`; cualquier
  intento de escritura va a fallar igual, pero el agente no debe siquiera
  intentarlo ni proponerlo.
- Pérdida o corrupción de datos es irreversible y desproporcionada al beneficio
  de cualquier automatización.

## Excepciones

Ninguna. Si surge un caso de uso legítimo (ej. seed de datos en BD de testing
local), debe documentarse en una spec aprobada (P2), ejecutarse fuera del
agente, y referenciarse explícitamente en `.env` con una BD distinta.
