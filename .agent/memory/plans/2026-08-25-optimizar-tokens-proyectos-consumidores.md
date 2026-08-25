---
status: approved
approved_at: 2026-08-25
---

# Plan — Checklist reusable para optimizar consumo de tokens en proyectos consumidores del harness

## Contexto

Un proyecto consumidor del harness (Python + Microsoft Graph API, repo separado) gastó ~155k
tokens en una sesión de dos issues chicos (G8/G9 del backlog del proyecto), y una fracción
grande de eso no fue código: 3 PRs "chore" solo para mantener un puntero de estado de sesión al
día, una suite de tests corrida completa e inline 3 veces en la sesión principal en vez de
delegada, y ceremonia git/gh (crear rama, push, esperar CI, cerrar issue, limpiar rama) hecha a
mano en cada uno de 4 PRs.

Al investigar antes de proponer nada nuevo, se confirmó que el harness **ya había resuelto el
problema de fondo**: ADR-006 (`c1f4985`) elimina las PRs chore de bookkeeping haciendo de Engram
la memoria primaria real y reduciendo `current-session.json` a un puntero local no versionado.
`agents/complexity-tiering.md` ya documenta cuándo delegar a subagentes. El gap no era de
diseño del harness — era que **ese proyecto consumidor estaba en una versión de `.aura` 23
commits atrasada** (`v2.2.1`, sin ADR-006) y, aparte, tenía la corrección a medias: su propio
`.gitignore` ya excluía `current-session.json` (agregado en una sesión previa sobre Engram) pero
nunca se ejecutó el `git rm --cached` que hace la exclusión efectiva — el archivo se seguía
commiteando en cada cierre de sesión sin que nadie lo notara.

Este plan no es la corrección puntual de ese proyecto (eso va en su propio repo, como PR normal
del proyecto). Es el **checklist reusable** para que cualquier otro proyecto consumidor de este
harness se audite contra el mismo tipo de gap antes de asumir que "ya sigue las reglas del
harness" solo porque la documentación las menciona.

## Alcance

Agregar a `docs/aura/observability.md` (o crear `docs/aura/consumer-token-audit.md` si el
primero está enfocado solo a la instrumentación propia del harness — decidir al escribir según
qué tan bien encaje) una sección con este checklist, pensada para correrse manualmente al
auditar un proyecto consumidor:

1. **Versión del harness al día.** `git -C .aura fetch origin && git -C .aura log HEAD..origin/main --oneline`
   — si hay commits pendientes, ninguna corrección de harness aplicada a otro proyecto llega al
   consumidor hasta actualizar el submódulo. Chequeo trivial, primero siempre.

2. **`current-session.json` — patrón ADR-006 completo, no a medias.** No basta con que
   `.gitignore` lo mencione: correr `git ls-files .agent/memory/current-session.json` en el
   proyecto consumidor. Si devuelve la ruta, sigue trackeado — la exclusión es un no-op y el
   archivo se va a seguir commiteando. Requiere `git rm --cached` explícito, una vez.

3. **Agentes especializados definidos vs. usados de verdad.** Un proyecto puede tener
   `test-runner`/`graph-reviewer` (o equivalentes) en `.claude/agents/` y una matriz de
   delegación en `.claude/rules/agents.md` — y aun así la sesión activa correr todo inline. Este
   gap no se detecta leyendo documentación, solo mirando el historial real de tool-calls de la
   sesión (o el reporte de `process-session.sh` si está wired, ver punto 4). Señal concreta:
   ¿`pytest`/`npm test`/equivalente corrió vía `Bash` directo en la sesión principal, habiendo un
   agente dedicado a exactamente eso?

4. **Documentación de convenciones duplicada.** Si la misma regla (convención de commits, flujo
   de ramas) aparece completa en 3+ archivos que se cargan siempre en contexto (no on-demand),
   cada sesión paga ese costo fijo aunque la tarea no lo necesite. Buscar duplicación real
   (mismo contenido, no solo mismo tema) entre el CLAUDE.md del proyecto, sus reglas de
   `.claude/rules/`, y cualquier doc de arquitectura propia.

5. **Instrumentación de medición.** Sin `skills/observability/` wired (captura de
   `session_id`/`transcript_path` + `process-session.sh`), cualquier afirmación de "esto bajó el
   consumo" es percepción, no dato. No es bloqueante tenerlo desde el día uno, pero si el
   proyecto va a iterar varias veces sobre optimización de contexto, wire-earlo temprano paga
   solo — es la única forma de comparar sesiones de forma objetiva en vez de por sensación.

## Verificación

Este plan no introduce código nuevo en el harness — es documentación de un checklist. Se
considera "verificado" cuando:

- El checklist se aplicó al menos una vez a un proyecto consumidor real (el que motivó este
  plan) y produjo hallazgos accionables distintos de "todo en orden" — ya ocurrió: harness
  desactualizado + migración de `current-session.json` a medias, ambos hallazgos reales, no
  hipotéticos.
- Un segundo proyecto consumidor (cuando exista) puede correr el mismo checklist sin
  reinterpretarlo — si algún punto resulta ambiguo al aplicarlo, se corrige en este mismo
  documento en vez de dejarlo como conocimiento tácito de esta sesión.

## Flujo de trabajo

Rama `chore/plan-optimizar-tokens-proyectos-consumidores` desde `develop` → agregar la sección
al doc elegido (punto de Alcance) → commit → PR hacia `develop` (este repo no permite
bookkeeping sin PR real — `agents/github.md`) → al mergear, actualizar este archivo de plan a
`status: done`.

## Archivos críticos

- `docs/aura/observability.md` — evaluar si el checklist encaja ahí o amerita archivo propio
  (`docs/aura/consumer-token-audit.md`)
- Precedente y decisión de fondo ya resuelta: `docs/aura/adr/ADR-006-eliminar-pr-chore-bookkeeping.md`
- Guía de delegación ya existente, referenciada por el punto 3: `agents/complexity-tiering.md`
- Tooling de medición referenciado por el punto 5: `skills/observability/scripts/process-session.sh`
