# Sensitive Data Safety — Prohibición de Versionar Datos Corporativos del Cliente

## Regla absoluta

El agente **NO PUEDE** versionar (en archivos trackeados, mensajes de commit,
títulos/cuerpos de PR o issues, o archivos de memoria en `.agent/memory/`) datos
corporativos reales del cliente. El detalle de negocio real vive **solo local**, en
rutas explícitamente gitignored (ej. `output/<BD>/docs/`, `config/*.json` local-only,
`.env`).

## Cómo detectar (checklist accionable)

Cuenta como sensible cualquiera de estos:

- Nombres de cliente / empresas / razones sociales / marcas.
- Nombres reales de catálogos/BD (`<catálogo>.dbo.<tabla>`), instancias, hostnames.
- IPs internas, rangos de red, cadenas de conexión, credenciales, tokens, `.env`.
- Datos de negocio reales: RUTs, montos, folios, centros de costo con nombre real,
  listados de proveedores/clientes, cualquier extracción directa de la BD.
- Nombres de personas / usuarios reales del ERP.

Usar siempre placeholders genéricos en contenido versionado (`<cliente>`, `<empresa>`,
`ACME`, `<catálogo>`).

## Barrido pre-commit / pre-push (read-only)

Antes de commitear o pushear, correr un barrido read-only buscando el catálogo de arriba:

- **Pre-commit:** `git diff --cached` sobre los archivos staged.
- **Pre-push:** mensajes de commit de la rama (`git log develop..HEAD`) y el cuerpo del
  PR a crear/actualizar.

## Qué hacer al detectar (obligatorio, en orden)

1. **DETENER** — no commitear/pushear.
2. **ADVERTIR al usuario** citando el fragmento exacto y dónde aparece.
3. Si el repo es **público** → recomendar explícitamente pasarlo a privado
   (`gh repo edit --visibility private`) **o** anonimizar el contenido antes de continuar.
4. Si ya se pusheó → advertir que la reescritura de historial no elimina lo ya indexado
   externamente; ofrecer el patrón de remediación (`git reset --soft` al punto anterior +
   recommit + `push --force-with-lease`) **con autorización explícita del usuario** para
   el force-push.

## Aplicación

- Cualquier commit, PR, issue o archivo de memoria que el agente produzca debe pasar el
  barrido antes de proponerse como acción a ejecutar.
- El barrido es **read-only** (`git diff`, `git log`, revisión de texto) — nunca modifica
  historial sin autorización explícita del paso 4.

## Por qué existe esta regla

En sesiones anteriores de este harness ocurrieron incidentes reales de filtración de
información corporativa de un cliente a un repositorio que en ese momento era público:
un documento fuente y sus extracciones directas pusheados por error, nombres de
cliente/empresas aparecidos en texto ya versionado (commits, PRs, memoria), y un nombre
real de base de datos versionado por semanas en documentación. Cada incidente se corrigió
**después** de ocurrido. Esta regla mueve la detección a **antes** del push.

## Excepciones

Ninguna para contenido versionado. `output/<BD>/*`, `config/*.json` local-only y `.env`
son el canal correcto para el dato real (ya gitignored) — nunca versionar por esa vía
tampoco.
