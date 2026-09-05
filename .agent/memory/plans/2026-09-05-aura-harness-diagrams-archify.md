---
status: approved
---

# Plan — Repo `aura-harness-diagrams` (visualización del flujo diseñado del harness con Archify)

## Context

El usuario quiere **visualizar el flujo diseñado** del harness Aura (routing de
`protocols/router.md`, ciclo de vida de sesión, ciclo de vida de un issue) usando
[Archify](https://github.com/tt-a1i/archify) — una herramienta Node.js empaquetada como
"skill" que genera diagramas HTML/SVG a partir de un JSON IR (Intermediate Representation)
autoreado a mano (lanes, columnas, nodos, edges — no es un generador automático desde logs).

**Distinción crítica que el usuario marcó explícitamente (ya ha pasado antes por esta
confusión):**
- **`aura-agent-kit`** (este repo, `C:\repos\aura-agent-kit`) = **EL HARNESS FUENTE**. Es el
  proyecto que define y distribuye el harness (`AGENTS.md`, `protocols/`, `skills/`,
  `agents/`). Versión actual confirmada: **v2.6.0** (`CHANGELOG.md`, `.claude-plugin/plugin.json`,
  tag git, commit `6d01f98`). Rama default en GitHub: `develop`.
- **`aura-harness-diagrams`** (repo nuevo, a crear) = un **CONSUMIDOR** del harness, como
  cualquier otro proyecto que instala `.aura/` vía `install.sh`. NO es una copia ni una
  versión del harness — solo lo usa. Este repo nunca debe editarse como si fuera el harness
  fuente; los cambios al harness en sí siguen yendo a `aura-agent-kit`.

**Por qué repo separado (no meter esto en `aura-agent-kit`):** mismo patrón ya validado con
`aura-agent-kit-sandbox` — mantener el harness fuente stack-agnóstico (P6, declarado como
"bash-scripts + markdown" en `session-stack.json`) sin sumarle Node como dependencia. Además
reusable: cualquier otro proyecto que consuma Aura puede generar sus propios diagramas.

**Hallazgo clave que resuelve el problema de "sync"/drift:** el submodule `.aura/` dentro de
`aura-harness-diagrams` **es** el harness fuente en un commit fijo. El generador de diagramas
debe leer directamente de `.aura/protocols/router.md` (y equivalentes), no copiar contenido a
mano — así el drift se resuelve con el mecanismo que el harness ya tiene (`/harness-update`,
bump del submodule), sin inventar nada nuevo.

**Decisión de versionado (pregunta del usuario — "cuál es la mejor práctica"):** `install.sh`
NO fija tag — hace `git submodule add` contra la rama default (`develop`, bleeding edge). Para
un experimento que busca observar el comportamiento real y reproducible del harness sobre un
requerimiento nuevo, la mejor práctica es **pinnear a un release concreto, no a `develop`
flotante** — de lo contrario cualquier comportamiento observado es imposible de reproducir o
atribuir con certeza a una versión específica del harness. Como `develop` ya tiene 2 fixes
reales sin release (#215 bug de heredocs, #216 gap de `git fetch`) que **no** están en el tag
v2.6.0 publicado, la jugada correcta —tal como el usuario intuyó— es **cortar un release nuevo
desde el HEAD actual de `develop` (commit `c4b1675`) antes de crear el repo consumidor**, y
pinnear `aura-harness-diagrams` a ese tag nuevo. Esto además ejercita la propia tooling de
release del harness (`agents/github.md` → "Proceso de Release") como parte del experimento de
autonomía que el usuario quiere observar.

**Segunda pregunta del usuario — qué debe exigir SIEMPRE el agente para un producto de
calidad, dado que los LLM tienden a validar ideas sin cuestionar:** la respuesta no es un
mecanismo nuevo — el harness ya tiene las piezas (`design-flow.md` gate de brainstorm
obligatorio, `spec-validation` hard-gate, `challenger` agent contra los 7 pilares,
`harness-core.md` regla de no afirmar sin verificar). El riesgo real es que un subagente bajo
presión de "cerrar el issue" se salte esas piezas. Por eso cada issue de este repo lleva un
**checklist de calidad obligatorio explícito en el cuerpo del issue** (ver Fase 3 abajo) — no
delegado a que el subagente "se acuerde".

## Approach

### Fase 0 — Release del harness fuente (en `aura-agent-kit`, ESTE repo)
1. Revisar `CHANGELOG.md` sección `[Unreleased]` (vacía) y agregar entradas para PR #215
   (fix heredocs `process-session.sh`) y PR #216 (fix `git fetch` en `session_start.md`) —
   ambos ya mergeados a `develop` sin release.
2. Determinar bump de versión: ambos cambios son `fix` → **v2.6.1** (patch, semver).
3. Ejecutar el proceso de release documentado en `agents/github.md` (mencionado en
   `objectives.md` como `cut-release.sh`) para cortar `v2.6.1` desde `develop` (commit
   `c4b1675`), incluyendo el sync-back a `main` si el proceso lo requiere.
4. Verificar: `git tag --sort=-creatordate | head -3` muestra `v2.6.1` sobre el commit
   correcto; `.claude-plugin/plugin.json` bumpeado a `2.6.1`.

### Fase 1 — Scaffold del repo consumidor `aura-harness-diagrams`
1. Crear repo privado `diegosvart/aura-harness-diagrams` (`gh repo create ... --private`).
2. Clonar localmente, correr `bash install.sh` (agrega `.aura/` como submodule contra
   `develop` por defecto).
3. Pinnear el submodule al release nuevo: `cd .aura && git checkout v2.6.1 && cd ..` y
   commitear el puntero de submodule actualizado — **no dejarlo flotando en `develop`**.
4. Completar los "próximos pasos" que `install.sh` NO automatiza (confirmado por
   exploración — el script solo los imprime, no los ejecuta):
   - Agregar hooks a `.claude/settings.json` (ver `.aura/QUICKSTART.md` paso 3).
   - Crear `AGENTS.local.md` en la raíz (no dentro de `.aura/`) con identidad para este
     proyecto — evitar el bug ya documentado de `AGENTS.local.md` mal ubicado.
5. Instalar Node/npm como dependencia del repo (ya confirmado disponible: node v24.14.0,
   npm v11.9.0) y el paquete/skill de Archify (`npx skills add tt-a1i/archify -g`, o
   vendorizado según lo que decida la sesión que trabaje ahí — no lo fuerzo desde acá).
6. Primer commit + push del scaffold completo (submodule pinneado + hooks + AGENTS.local.md).

### Fase 2 — Issues (label `ready`), uno por diagrama
Tres issues independientes, cada uno con:
- **Tipo de diagrama Archify:** `workflow` (router de contexto), `lifecycle` (ciclo de sesión:
  session_start → task_start → delegar/inline → routing-menu → session_end), `workflow` o
  `lifecycle` según corresponda (ciclo de vida de un issue: idea → brainstorm →
  spec-validation → challenger → plan-work → ready → dev-loop → review → merge → cierre).
- **Fuente exacta a leer:** ruta dentro de `.aura/` (ej. `.aura/protocols/router.md`,
  `.aura/protocols/session_start.md`, `.aura/AGENTS.md` + `.aura/protocols/router.md` para
  el ciclo de issue).
- **DoD verificable (no "se ve bien"):**
  1. El JSON IR pasa `node archify/bin/archify.mjs validate <tipo> <archivo.json> --json`
     sin errores.
  2. El HTML generado (`archify.mjs deliver ...`) abre y cada nodo/edge del diagrama
     corresponde 1:1 a una fila/paso real de la fuente citada — sin inventar pasos que no
     estén en el `.md`.
  3. Un tercer criterio de fidelidad: si la fuente cambia, el diagrama debe declarar contra
     qué commit/tag de `.aura/` fue generado (metadata `meta.title` o `cards`), para que el
     drift futuro sea detectable a simple vista.

### Fase 3 — Checklist de calidad obligatorio (embebido en el cuerpo de cada issue)
No es mecanismo nuevo — son las piezas del harness que ya existen, hechas explícitas para
que un subagente no las salte por apuro:
- [ ] Leí el archivo fuente real en `.aura/` en este turno (no memoria/resumen previo).
- [ ] El IR generado fue validado con la CLI de Archify antes de darlo por bueno.
- [ ] Antes de cerrar el issue, pasé el diseño del diagrama por autoevaluación explícita
      contra los 7 pilares (o invoqué `challenger` si el cambio lo amerita) — no cerrar solo
      porque "compiló".
- [ ] Si tomé alguna decisión de diseño no obvia, la registré en Engram (P5).
- [ ] No afirmé que el diagrama "refleja el flujo real" sin haber comparado explícitamente
      contra la fuente en este mismo turno (regla de `harness-core.md`).

### Fase 4 — Handoff al usuario
Yo (esta sesión, corriendo sobre `aura-agent-kit`) no puedo "iniciar Claude" dentro del repo
nuevo. Preparo el scaffold + issues, y el usuario arranca una sesión de Claude Code nueva ahí
(`claude .` en `aura-harness-diagrams`) para observar cómo el harness resuelve los 3 issues de
forma autónoma — ese es el experimento real.

## Archivos/acciones críticas
- `aura-agent-kit`: `CHANGELOG.md` (nueva entrada `[2.6.1]`), `.claude-plugin/plugin.json`
  (bump versión), tag `v2.6.1`.
- `aura-harness-diagrams` (nuevo): `install.sh` (ya existe en `aura-agent-kit`, se corre
  dentro del repo nuevo), `.aura/` (submodule pinneado a `v2.6.1`), `.claude/settings.json`,
  `AGENTS.local.md`, 3 issues con label `ready`.

## Verificación
- `git tag --sort=-creatordate | head -3` en `aura-agent-kit` confirma `v2.6.1` sobre
  `c4b1675`.
- En `aura-harness-diagrams`: `cd .aura && git describe --tags` confirma `v2.6.1` (no
  `develop` flotante).
- `gh issue list --repo diegosvart/aura-harness-diagrams --label ready` devuelve los 3 issues.
- Cada issue cerrado debe tener adjunto (o linkeado en el comentario de cierre) el HTML
  generado y la confirmación explícita de los 3 puntos de DoD de la Fase 2.
