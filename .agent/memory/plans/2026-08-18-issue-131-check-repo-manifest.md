---
status: approved
---

# Limpieza de repo + Issue #131 (check de integridad) + Release

## Contexto

Al iniciar la sesión se detectaron dos ramas ya mergeadas a `develop` (local y remota)
pendientes de limpieza, y el Issue #131 (`ready`) quedó desbloqueado porque su diseño
(Issue #130, ADR-007 + spec `docs/aura/specs/2026-08-18-repo-integrity-manifest.md`) ya
se mergeó vía PR #146. El ADR deja la implementación totalmente especificada — "puede
implementarse directamente desde este ADR sin decisiones de diseño pendientes" — así que
no hace falta una fase de diseño adicional, solo ejecutar el contrato ya definido.

El usuario pidió, en este orden: (1) limpiar el repo, (2) implementar Issue #131, (3)
cortar un release que incluya ese cambio.

---

## Investigación de mercado — gestión eficiente de workflows/harness de agentes (2026)

Búsqueda web rápida para contrastar el enfoque de `aura-agent-kit` (harness propio,
router estático en markdown, protocolos leídos paso a paso por el agente) contra el
estado del arte de la industria a agosto de 2026. No cambia el alcance de Issue #131 —
es contexto para decisiones futuras de evolución del harness (P7).

**Hallazgos relevantes:**

- **Orquestación multi-agente** — la práctica dominante en 2026 es una capa de
  orquestación (tipo "project manager") que asigna tareas, gestiona contexto compartido y
  coordina agentes especializados; reportan ~30% más eficiencia que agentes aislados.
  Prácticas líderes: piloto por etapas ("stage-gated"), inventario/identidad de agentes,
  monitoreo centralizado persistente, dashboards de KPI operacionales/regulatorios,
  auditabilidad robusta y gobernanza cross-funcional bien definida.
  ([Zencoder — 6 AI Agent Orchestration Best Practices in 2026](https://zencoder.ai/blog/ai-agent-orchestration-best-practices),
  [Tyk — AI Agent Orchestration Enterprise Guide](https://tyk.io/learning-center/ai-agent-orchestration-a-complete-enterprise-guide/))

- **Estándares de protocolo** — MCP (Model Context Protocol) es de facto el estándar para
  integración de herramientas (`tools/list`/`tools/call`); A2A (Agent2Agent) v1.0 es el
  estándar emergente para comunicación agente-a-agente. `aura-agent-kit` ya usa MCP
  (Engram, GitHub vía `gh` CLI preferido sobre MCP por costo de tokens — P1) pero no tiene
  necesidad actual de A2A al ser un solo agente orquestador con subagentes delegados, no
  múltiples agentes independientes negociando entre sí.

- **Harness engineering (coding agents específicamente)** — un harness es "todo lo que
  está entre el modelo de lenguaje y el mundo real": el modelo genera texto, el harness
  decide qué puede tocar ese texto. Patrones de diseño clave documentados: (1) separar
  razonamiento de enforcement de permisos — el modelo decide qué quiere hacer, un sistema
  distinto decide si está permitido (equivalente a los hooks `PreToolUse` de este repo:
  `git-guard.ps1`, `sensitive-data-guard.ps1`); (2) gestión explícita de contexto
  (compactación, truncamiento, tool search, persistencia en disco); (3) continuidad de
  sesión vía snapshots y un archivo ancla persistente tipo `CLAUDE.md`/`AGENTS.md` — que
  es exactamente el rol que cumple `AGENTS.md` + `protocols/router.md` en este repo.
  ([arXiv 2602.14690 — Harness Engineering for Agentic AI Coding Tools](https://arxiv.org/pdf/2602.14690),
  [arXiv 2604.08224 — Externalization in LLM Agents: Memory, Skills, Protocols and Harness Engineering](https://arxiv.org/pdf/2604.08224))

- **AGENTS.md/CLAUDE.md como estándar abierto** — confirmado como formato de facto para
  guiar agentes de código, adoptado por múltiples herramientas (no solo Claude Code). El
  enfoque de este repo (spine liviano + router de contexto por tabla, cargar solo lo
  necesario) está alineado con la práctica recomendada de gestión explícita de contexto
  citada arriba, en vez de precargar todo el harness en cada sesión.
  ([AImultiple — Top Agent Harnesses: Claude Code vs Codex](https://aimultiple.com/agent-harness))

**Relevancia para este repo:** ninguna acción inmediata — el diseño actual (router
estático, hooks de enforcement separados del razonamiento del modelo, memoria distribuida
Engram + ledger de planes) ya sigue los patrones que la industria documenta como
recomendados en 2026. El único gap real potencial a futuro es la ausencia de un
"inventario de agentes" formal más allá de `agents/complexity-tiering.md` — no accionable
ahora, candidato a `/idea` si se vuelve fricción real.

---

## Paso 1 — Limpieza de ramas mergeadas

Ramas detectadas en `session_start` como ya mergeadas en `develop`, sin PR pendiente:

- `feature/issue-135-sensitive-data-guard-hook` (local + remota)
- `docs/issue-130-repo-integrity-manifest-spec` (solo remota)

Acciones:
```bash
git branch -d feature/issue-135-sensitive-data-guard-hook
git push origin --delete feature/issue-135-sensitive-data-guard-hook
git push origin --delete docs/issue-130-repo-integrity-manifest-spec
git remote prune origin
```

---

## Paso 2 — Implementar Issue #131 (check de integridad de repo)

Contrato ya cerrado por ADR-007 / spec (no hay decisiones de diseño pendientes):

**Archivos nuevos:**

1. `skills/repo-integrity/manifest.txt` — lista estática, un path relativo al repo por
   línea, comentarios con `#`, sufijo `#optional` para archivos gitignorados/opcionales
   (ej. `AGENTS.local.md`). Contenido inicial: los paths reales de archivo único listados
   en la columna "Archivos a cargar" de `protocols/router.md` (filtrando los que son
   estado runtime gitignorado, ej. `.agent/memory/current-session.json`, que no
   corresponde a un archivo versionado del harness).

2. `skills/repo-integrity/scripts/check-repo-manifest.sh` — mismo patrón que
   `skills/repo-integrity/scripts/check-release-drift.sh` (referencia directa a copiar y
   adaptar):
   - `#!/usr/bin/env bash`, header de 2-4 líneas en español explicando qué implementa y
     por qué es script y no prosa.
   - `set -uo pipefail` (sin `-e` — igual que `check-release-drift.sh`, chequeo
     informativo que nunca debe abortar la sesión).
   - Lee `skills/repo-integrity/manifest.txt` relativo a la raíz del repo.
   - Por cada línea no-comentario: si es `#optional` y no existe → omitir. Si no es
     optional y no existe → `echo "MISSING: <ruta>"`. (El caso `MISPLACED` requiere lógica
     adicional de búsqueda; si el alcance es solo `MISSING` para esta primera versión,
     confirmar contra el criterio de aceptación del issue antes de agregar complejidad no
     pedida — el ADR describe ambos casos pero el criterio de aceptación de #131 solo
     exige "detecta faltantes", verificar el texto exacto del issue antes de implementar
     `MISPLACED`.)
   - Sin salida si todo está bien (chequeo silencioso).
   - `exit 0` siempre (nunca bloquea `session_start`).
   - Runtime esperado <2s, sin `gh`, sin red.

**Archivos a editar:**

3. `protocols/session_start.md` Paso 3 — agregar una subsección nueva "### Integridad del
   Manifest" (mismo formato que la subsección existente "### Drift de Release", líneas
   145-162): invoca `bash skills/repo-integrity/scripts/check-repo-manifest.sh`, y si
   imprime líneas, copiarlas verbatim en "Advertencias" (Paso 6); si no imprime nada, no
   mostrar ninguna línea (advertencia condicional, mismo patrón que drift de release).

**Fuera de alcance para esta implementación** (mencionado en el ADR como fast-follow, no
bloqueante para #131): generalizar el chequeo de `AGENTS.local.md` mal ubicado (Paso 1 de
`session_start.md`) al patrón `MISPLACED` del nuevo script, y la actualización de
`agents/doc-guardian.md` (D4, regla de mantenimiento del manifest). No implementar salvo
que el usuario lo pida explícitamente.

**Validación** (sin test runner en este repo — patrón aceptado, ver `coding.md` y
convención de scripts bash existente):
- Correr el script contra el estado real del repo → debe salir limpio (sin output).
- Renombrar/borrar temporalmente un archivo listado en el manifest → debe imprimir
  `MISSING: <ruta>` — y revertir el cambio.
- Confirmar que `AGENTS.local.md` ausente (caso real y válido en este repo si no está
  personalizado) NO dispara falso positivo (entrada `#optional`).
- Medir tiempo de ejecución (`time bash skills/repo-integrity/scripts/check-repo-manifest.sh`) < 2s.

**Flujo de rama/PR** (según `agents/github.md` / `protocols/task_start.md`):
- Rama: `feature/issue-131-check-repo-manifest` desde `develop`.
- Commit: `feat(repo-integrity): implementar check-repo-manifest.sh (Issue #131)`.
- Actualizar `.agent/memory/project-log.md` en el mismo PR con: (a) la cola pendiente de
  PRs #143/#144/#145/#146 (registrada en Engram, aún no volcada al archivo), y (b) la
  nueva entrada de esta PR — mismo patrón usado en PRs anteriores de este repo.
- PR con `Closes #131`, hacia `develop`.

---

## Paso 3 — Release (después de mergear la PR de #131)

Versión actual: `2.2.1`. Este cambio es una feature nueva sin breaking changes →
`v2.3.0` (confirmar con el usuario si prefiere otro número antes de tagear).

Usar `skills/agentic-dev-loop/scripts/cut-release.sh` (no reconstruir el proceso a mano):

1. Escribir la entrada `## [2.3.0]` en `CHANGELOG.md` (resumen: check de integridad de
   manifest, Issue #131).
2. `cut-release.sh changelog-pr diegosvart/aura-agent-kit v2.3.0` → mergear la PR
   resultante.
3. `cut-release.sh promote diegosvart/aura-agent-kit v2.3.0 <changelog_pr_n>` → mergear
   la PR `develop → main`.
4. `cut-release.sh tag diegosvart/aura-agent-kit v2.3.0 <release_pr_n>`.
5. `cut-release.sh sync-back diegosvart/aura-agent-kit v2.3.0` (obligatorio, mismo turno)
   → mergear la PR de sync-back.
6. Verificar `git describe --tags` en `develop` resuelve contra `v2.3.0` sin drift.

---

## Verificación end-to-end

- `bash skills/repo-integrity/scripts/check-repo-manifest.sh` sale limpio en el repo real.
- `protocols/session_start.md` Paso 3 ejecuta el nuevo chequeo (probarlo corriendo el
  protocolo de session start de nuevo tras el merge).
- Tras el release: `git describe --tags` en `develop` y `main` alineados en `v2.3.0`, sin
  drift (`check-release-drift.sh` sale limpio).
