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

**Categoría de riesgo elevado: `.agent/memory/plans/*.md`.** El ledger de planes
aprobados (`AGENTS.md` → "Al aprobar un plan") SÍ se versiona por defecto (ver
`docs/aura/adr/ADR-003-politica-versionado-artefactos.md`), pero es el punto donde ya
ocurrió una fuga real: un plan que documenta una investigación técnica terminó con
folios/OC reales extraídos de datos de muestra del cliente. Al escribir o actualizar un
plan, aplicar este mismo checklist ANTES de commitearlo — un plan no es un canal
distinto de cualquier otro archivo versionado.

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

## Enforcement (no depende solo de que el agente se acuerde)

`.claude/hooks/sensitive-data-guard.ps1` (PreToolUse, mismo patrón que `git-guard.ps1`)
bloquea `git commit` a nivel de herramienta cuando el contenido a commitear matchea:

1. Una **denylist local exacta** — `.claude/sensitive-terms.local.txt` (gitignored,
   nunca commiteado), con los términos reales del proyecto actual (cliente, sponsor,
   stakeholders nombrados).
2. **Patrones genéricos** siempre activos: RUT chileno, IP privada, `password=`/`pwd=`.

Esto es **defensa en profundidad**, no reemplaza el barrido manual: un dato sensible
mencionado por primera vez (ej. un stakeholder nuevo, aún no agregado a la denylist)
sigue dependiendo de que el barrido de esta regla se aplique conscientemente antes de
commitear. Al identificar un término sensible nuevo, agregarlo a
`.claude/sensitive-terms.local.txt` en el mismo momento.

**Por qué existe el hook y no solo esta regla:** esta misma regla ya existía en texto
cuando ocurrió un incidente idéntico en otro proyecto (`crawler-mcp-diagram`,
2026-07-15, ver `docs/aura/adr/ADR-003-politica-versionado-artefactos.md`), y volvió a
ocurrir en este repo poco después (`.agent/memory/plans/2026-08-12-vault-develop-issues.md`,
nombre real de cliente pusheado a `main`/`develop`, remediado vía `git filter-branch`).
Una regla en markdown depende de que el agente la recuerde aplicar en cada commit; el
hook no.

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
