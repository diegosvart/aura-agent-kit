# Data Safety — Prohibición Estricta de Modificar la BD

## Regla absoluta

El agente **NO PUEDE** proponer, generar, ejecutar ni sugerir como opción cualquier
operación que altere el estado de una base de datos conectada al proyecto (únicas dos excepciones acotadas: redacción, nunca ejecución, de DCL de permisos y de DDL de vistas — ver "Excepciones").

Incluye, sin limitarse a:
- **DDL:** `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `RENAME`, `COMMENT ON` (ejecución prohibida sin excepción; ver excepción acotada de *redacción* de DDL de vistas en "Excepciones")
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
  read-only** (`SELECT`, vistas de INFORMATION_SCHEMA, `EXPLAIN`, metadatos) — salvo las dos excepciones acotadas de *redacción* (nunca ejecución) de DCL de permisos y de DDL de vistas definidas en "Excepciones".
- Si el usuario pide explícitamente una operación de escritura: **rehusar** y
  redirigir a que la ejecute manualmente con sus propias herramientas y permisos,
  fuera del agente. Única salvedad: la *redacción* (nunca la ejecución) que
  permiten las dos excepciones de "Excepciones", bajo sus requisitos.
- Si una herramienta MCP futura expone capacidades de escritura, debe ser
  bloqueada por defecto en `.claude/settings.json` → `permissions.deny`.

## Por qué existe esta regla

- SchemaCrawler MCP es read-only **por diseño** (sólo metadatos vía
  `INFORMATION_SCHEMA`). Esta regla refuerza esa propiedad a nivel de agente
  para que ningún canal alternativo la viole.
- El usuario de BD del proyecto (`<usuario>` en `<BD>`) tiene `db_datareader`;
  cualquier intento de escritura va a fallar igual, pero el agente no debe
  siquiera intentarlo ni proponerlo.
- Pérdida o corrupción de datos es irreversible y desproporcionada al beneficio
  de cualquier automatización.

## Excepciones

Dos, acotadas, y ninguna habilita ejecución bajo ninguna circunstancia:

### 1. Redacción (no ejecución) de DCL de gestión de permisos

El agente puede
REDACTAR — nunca ejecutar — sentencias `GRANT`, `REVOKE` o `DENY` sobre
permisos de usuarios/roles, para que el usuario las revise y ejecute
manualmente con sus propias credenciales, fuera del agente. Aplica
exclusivamente a DCL de permisos; el DML y el DDL fuera de la excepción 2
siguen absolutamente prohibidos tanto para redactar como para ejecutar — esta
excepción no los alcanza bajo ninguna interpretación.

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

Hipótesis P4 que sustenta esta excepción:
`docs/aura/experiments/2026-09-14-data-safety-dcl-redaction-exception.md`.

### 2. Redacción (no ejecución) de DDL de vistas

El agente puede REDACTAR — nunca ejecutar — `ALTER VIEW` o `CREATE VIEW` de **una
vista cuyo cuerpo es un `SELECT` de solo lectura**, para que el usuario lo revise
y lo aplique manualmente con sus propias credenciales, fuera del agente. Existe
porque el trabajo de validar vistas consiste en llevar a una vista un `SELECT`
que el agente ya ejecutó y comparó en solo lectura; sin la excepción, ese paso
quedaría en una zona gris o se rehacería a mano en cada vista.

Alcance, estrictamente:

- Solo `ALTER VIEW` / `CREATE VIEW`. Nada de `DROP`, `sp_rename`, `SELECT INTO`,
  índices, tablas, procedimientos, triggers, funciones ni cambios de schema.
- El cuerpo de la vista no puede leer fuera de la base de datos del proyecto: sin
  `OPENROWSET`, `OPENQUERY`, `OPENDATASOURCE`, servidores vinculados ni `xp_*`.
- El cuerpo de la vista debe ser el mismo `SELECT` que el agente ya ejecutó y
  validó en solo lectura (sin efectos de escritura).
- La sintaxis debe ser la soportada por la versión del motor (el agente la
  verifica en solo lectura, por ejemplo `@@VERSION`): por ejemplo, SQL Server
  anterior a 2016 SP1 no admite `CREATE OR ALTER`. Si la vista ya existe, se
  prefiere `ALTER VIEW`, que conserva sus permisos.

Requisitos obligatorios, sin los cuales la redacción no procede:

1. **Los mismos requisitos 1, 2 y 3 de la excepción 1**: ruta gitignored
   (`output/<BD>/`), header `-- PARA EJECUCIÓN MANUAL. NO AUTOMÁTICA. El agente
   no ejecuta este script.` como primera línea, y el agente nunca lo invoca.
2. **Spec aprobada que menciona expresamente este uso.** La redacción debe estar
   prevista de forma explícita (qué vista, para qué) en una spec aprobada por el
   usuario (P2); un pedido verbal o una spec que no mencione la redacción de DDL
   de vistas no basta. El agente no la sugiere de forma proactiva fuera de ese
   marco.
3. **Después de que el usuario lo aplica, el agente solo verifica con `SELECT`**
   (vista contra su `SELECT` de origen); jamás reintenta ni corrige la vista
   por su cuenta en la BD.
4. **Verificación determinista**: todo archivo de DDL de vistas debe contener
   únicamente el header, comentarios y sentencias `ALTER VIEW` / `CREATE VIEW`
   (más `SELECT` de verificación); una verificación de solo lectura lo comprueba
   antes de entregarlo al usuario (un lint, o una revisión determinista
   equivalente que defina el proyecto consumidor).

Además, el archivo puede incluir, en bloques separados, un `SELECT` de
verificación y el `ALTER VIEW` de rollback con la definición anterior, capturada
antes en solo lectura mediante `SELECT` (por ejemplo `OBJECT_DEFINITION()` o
`sys.sql_modules`; no `sp_helptext`, que es un procedimiento almacenado).

Cualquier otro caso de uso legítimo fuera de estas dos excepciones (ej. seed de
datos en BD de testing local) sigue el camino ya definido: documentarse en
una spec aprobada (P2), ejecutarse fuera del agente, y referenciarse
explícitamente en `.env` con una BD distinta.

Hipótesis P4 que sustenta la excepción 2: ver el cuerpo del PR #411 de
`aura-agent-kit` (el experimento local `docs/aura/experiments/` está gitignored).
Resumen: en las primeras N=10 vistas el tiempo medio por vista validada baja
respecto de la línea base manual, con 0 sentencias fuera de `ALTER VIEW` /
`CREATE VIEW` y 0 ejecuciones por el agente.
