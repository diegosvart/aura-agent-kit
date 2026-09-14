# Data Safety — Prohibición Estricta de Modificar la BD

## Regla absoluta

El agente **NO PUEDE** proponer, generar, ejecutar ni sugerir como opción cualquier
operación que altere el estado de una base de datos conectada al proyecto (única excepción acotada: redacción, nunca ejecución, de DCL de permisos — ver "Excepciones").

Incluye, sin limitarse a:
- **DDL:** `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME`, `COMMENT ON`
- **DML:** `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `UPSERT`, `REPLACE`
- **DCL:** `GRANT`, `REVOKE`, `DENY` (ejecución prohibida sin excepción; ver excepción acotada de *redacción* en "Excepciones")
- **TCL agresivo:** `ROLLBACK` sobre transacciones ajenas, `SAVEPOINT` destructivos
- **Stored procedures / jobs / triggers:** creación, modificación, ejecución de
  procedimientos con efectos colaterales de escritura
- **Operaciones administrativas:** backups que sobrescriban, restores, attach/detach,
  cambios de schema, recreación de índices con `DROP_EXISTING`, etc.

## Aplicación

- Cualquier herramienta MCP, CLI (`sqlcmd`, `psql`, `mysql`, etc.), script
  (`.sql`, `.ps1`, `.py`) o snippet que el agente produzca debe ser **estrictamente
  read-only** (`SELECT`, vistas de INFORMATION_SCHEMA, `EXPLAIN`, metadatos) — salvo la única excepción acotada de *redacción* (nunca ejecución) de DCL de permisos definida en "Excepciones".
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

Una sola, acotada, y que NO habilita ejecución bajo ninguna circunstancia:

**Redacción (no ejecución) de DCL de gestión de permisos.** El agente puede
REDACTAR — nunca ejecutar — sentencias `GRANT`, `REVOKE` o `DENY` sobre
permisos de usuarios/roles, para que el usuario las revise y ejecute
manualmente con sus propias credenciales, fuera del agente. Aplica
exclusivamente a DCL de permisos; DDL y DML siguen absolutamente prohibidos
tanto para redactar como para ejecutar, sin excepción alguna — esta excepción
no los alcanza bajo ninguna interpretación.

Requisitos obligatorios, los cuatro, sin los cuales la redacción no procede:

1. **El script redactado se guarda únicamente en una ruta gitignored**
   (`output/<BD>/`), nunca en un archivo versionado ni pegado en un commit,
   mensaje de PR o issue.
2. **El archivo lleva como primera línea un header explícito**:
   `-- PARA EJECUCIÓN MANUAL. NO AUTOMÁTICA. El agente no ejecuta este script.`
   (o equivalente literal en el lenguaguaje del motor de BD).
3. **El agente nunca invoca este script** desde ninguna herramienta propia
   (MCP, CLI, script disparado por el agente) — ejecutarlo es una acción del
   usuario, con sus propias credenciales, igual que cualquier otra operación
   de escritura que la "Regla absoluta" ya rechaza.
4. **El agente redacta DCL de permisos únicamente ante pedido explícito del
   usuario; nunca lo propone ni lo sugiere de forma proactiva.** La "Regla
   absoluta" prohíbe también "sugerir como opción" cualquier operación de
   escritura — esta excepción no crea una excepción a esa prohibición de
   sugerencia proactiva, solo a la de redactar cuando el usuario ya lo pidió.

Cualquier otro caso de uso legítimo fuera de DCL de permisos (ej. seed de
datos en BD de testing local) sigue el camino ya definido: documentarse en
una spec aprobada (P2), ejecutarse fuera del agente, y referenciarse
explícitamente en `.env` con una BD distinta.

Hipótesis P4 que sustenta esta excepción:
`docs/aura/experiments/2026-09-14-data-safety-dcl-redaction-exception.md`.
