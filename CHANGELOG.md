# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.6.0] - 2026-09-02

### Added
- `skills/harness-update/scripts/check-update.sh` (`session-start.ps1`): chequeo de versión
  para consumidores instalados vía `claude plugin install` (sin `.aura/` submódulo) —
  compara la versión instalada (`claude plugin list --json`) contra la versión cacheada por
  el marketplace configurado. Mutuamente excluyente con el canal legacy submodule por
  construcción; `session_start.md` Paso 6 bifurca el aviso por `harness_update_channel`
  (Issue #181, PR #186)
- `skills/harness-update/scripts/apply-update.sh`: unifica la aplicación de la actualización
  entre ambos canales de instalación — submodule (`git checkout` de tag) y plugin
  (`claude plugin marketplace update` + `claude plugin update <id>`). `README.md`/
  `QUICKSTART.md` ganan una Opción C real de instalación "solo plugin, sin submodule", antes
  inalcanzable por un consumidor real (Issue #187, PR #188, ADR-009)
- `docs/aura/adr/ADR-010-agent-browser-e2e-testing.md`: formaliza la decisión de incorporar
  `agent-browser` como capability de testing E2E/headless — instalación-con-aprobación y
  modo CLI-puro como condiciones de la decisión, y confía en el timeout de inactividad propio
  del daemon en vez de agregar un paso a `session_end.md`. `skills/agentic-dev-loop/SKILL.md`
  documenta el smoke test post-implementación como punto de extensión opcional (Issue #169,
  PR #191)

### Fixed
- `protocols/session_start.md` Paso 5: el preview truncado (~300 caracteres) de `mem_context`
  no alcanza a mostrar la sección `Accomplished`/`🔲 Pendiente` de un `session_summary` largo.
  Ahora exige llamar `mem_get_observation` sobre la observación más reciente antes de declarar
  "Pendiente/Próximo paso" vacío — caso real donde el agente declaró incorrectamente que no
  había `next_step` en memoria pese a que sí estaba, completo, tanto en Engram como en
  `current-session.json` (PR #190)

### Changed
- Marketplace del plugin nativo renombrado de `aura-local` a `aura-agent-kit` — el nombre
  anterior sugería "solo desarrollo local" a un consumidor real instalando vía marketplace de
  GitHub. Sin migración automática: instalaciones existentes deben desinstalar/reinstalar bajo
  el nuevo nombre (PR #192)

## [2.5.0] - 2026-09-02

### Added
- `agents/browser-testing.md` + `skills/e2e-testing/SKILL.md`: capability nueva de testing
  E2E/headless vía CLI de `vercel-labs/agent-browser` (nunca su modo `mcp`, Pilar P1),
  complementaria a `agents/browser-control.md` (navegador real del usuario). Dogfooding real
  ejecutado en la misma sesión (Issue #168, PR #177)
- `skills/repo-integrity/scripts/check-orphaned-worktrees.sh`: detecta worktrees de sesiones
  cerradas sin limpiar (lock con PID muerto, o rama ya mergeada/gone), wireado en
  `session_start.md` Paso 3 (PR #176)
- `.aura/rules/subagent-dispatch.md`: regla evaluable de dos condiciones para decidir cuándo
  el agente principal debe delegar a un subagente (`Agent` tool) vs. ejecutar inline, más
  métrica de auditoría `delegation_rate` instrumentada en
  `skills/observability/scripts/process-session.sh` y expuesta en `session_start.md` Paso 5.5.
  Deriva de reconciliar un plan externo de estabilización del harness contra evidencia
  empírica real (Issue #179, PR #180)
- `.claude-plugin/plugin.json` + `marketplace.json`: registra `aura-agent-kit` como plugin
  nativo de Claude Code (marketplace local `aura-local`) — habilita el Skill tool / slash
  commands nativos para las 15 skills y 13 comandos del harness, que antes no eran
  invocables por esa vía. Se agrega frontmatter YAML faltante a 8 skills (ADR-008, Issue #170,
  PR #171)

### Fixed
- `worktree.baseRef:"fresh"` de Claude Code creaba worktrees/ramas nuevas desde el default
  branch de GitHub, no desde `develop` — causa raíz confirmada del incidente de PR #159
  (mergeado directo contra `main`). Corregido: default branch cambiado a `develop`,
  `.worktreeinclude` nuevo (copia `AGENTS.local.md`/`.env*`/credenciales a cada worktree),
  y `check-base-branch.sh` no corría en el Hook Fast-Path — ahora tiene excepción explícita
  (PR #166)
- `enabledPlugins` vacío en `.claude/settings.json` impedía que el plugin `aura`, ya
  registrado, cargara realmente — causa contribuyente (no raíz) de que las skills siguieran
  sin invocarse tras PR #171 (PR #173)
- Auto-aviso de actualización (`session_start.md` Paso 6) quedaba completamente mudo cuando
  `.aura/` no es un submódulo git (modelo de distribución vía plugin) — indistinguible de "el
  chequeo nunca corrió". Se distingue ahora explícitamente "no aplica" de un error real; el
  mecanismo de chequeo de versión para consumidores vía plugin queda pendiente en Issue #181
  (PR #182)

### Docs
- Causa raíz real confirmada de `Skill(aura:auto-research)` fallando con "Unknown skill": un
  marketplace con `source: Directory` no registra las skills del plugin para el Skill tool
  nativo — `source: GitHub` sí. Bitácora retroactiva de la investigación completa y cierre del
  plan asociado (PRs #167, #174, #175, #178)

## [2.4.1] - 2026-08-29

### Fixed
- `skills/repo-integrity/scripts/check-repo-manifest.sh`: `manifest.txt` sin
  `eol=lf` en `.gitattributes` quedaba con CRLF en checkouts Windows con
  `core.autocrlf=true`, y el script leía cada ruta con un `\r` final —
  `test -f` fallaba en silencio y el chequeo reportaba 20 falsos `MISSING:`.
  Corregido agregando la regla `eol=lf` y recortando `\r` por línea en el
  script (mismo patrón ya usado para `.githooks/pre-push`) (PR #153)
- Reconciliación `main`→`develop`: PR #159 (browser-control) se había ramificado
  y mergeado directo contra `main`, saltándose `develop` (Issue #161). Este
  release consolida `develop` con el contenido de `main` (que ya incluía PR #159
  desde el release `v2.4.0`, publicado por separado el 2026-08-28) más el fix
  CRLF de arriba, que no estaba en ese release

## [2.4.0] - 2026-08-28

### Added
- `agents/browser-control.md`: agente de visión/control de navegador vía
  `claude-in-chrome` — dos casos de uso (exploratorio cuando no hay CLI/MCP que
  alcance, o a pedido explícito del usuario), salvaguardas nativas +
  salvaguarda de harness (nunca acción irreversible sin confirmación explícita),
  tabla de decisión "ver" vs "controlar". Nueva fila de routing en
  `protocols/router.md` y `AGENTS.md` (Issue #157, PR #159)

## [2.3.0] - 2026-08-18

### Added
- `skills/repo-integrity/manifest.txt` + `skills/repo-integrity/scripts/check-repo-manifest.sh`:
  chequeo de integridad de archivos versionados del harness (`MISSING:`/`MISPLACED:`),
  integrado en `protocols/session_start.md` Paso 3 (ADR-007, Issues #130/#131, PRs #146/#149)
- `.claude/hooks/sensitive-data-guard.ps1`: hook `PreToolUse` que bloquea `git commit` ante
  denylist local, RUT chileno, IP privada o credenciales inline (Issue #135, PR #145)

### Changed
- `current-session.json` deja de versionarse; Engram queda como memoria primaria real
  (ADR-006, PR #144)
- `.agent/memory/project-log.md` ya no depende de PRs chore dedicadas para bookkeeping — se
  vuelca en la siguiente PR de código real que se abra (ADR-006, PR #144)

## [2.2.1] - 2026-08-04

### Added
- `skills/repo-integrity/scripts/check-release-drift.sh`: chequeo local (sin `gh`) que
  compara el último tag alcanzable desde `main` contra la ancestría de `develop`, enlazado
  en `protocols/session_start.md` Paso 3 (Issue #120, PR #123)

### Fixed
- `check-update.sh` ahora avisa por stderr cuando `.aura` está en una rama y no en un tag
  exacto, distinguiendo "desactualizado real" de "rama sin el último tag como ancestro"
  (PR #123)
- `apply-update.sh`: nuevo paso `[6/6]` que detecta si `git-guard.ps1` existe en
  `.claude/hooks/` pero no está registrado como `PreToolUse` en `.claude/settings.json`, y
  lo autoregistra — antes el enforcement de "nunca push directo a develop/main" podía quedar
  inerte tras aplicar el update (gap real detectado en un consumidor externo, PR #124)
- `apply-update.sh`: al registrar `git-guard.ps1` en `PreToolUse`, ahora fusiona dentro de un
  matcher existente para `Bash`/`PowerShell` en vez de crear uno duplicado, evitando
  desactivar en silencio un hook custom preexistente del consumidor (PR #125)

## [2.2.0] - 2026-08-04

### Added
- Observabilidad de sesiones: `session-end.ps1` captura `session_id` y `transcript_path` en
  `.agent/memory/observability/sessions-index.jsonl` (fail-open, no versionado — Issue #103,
  PR #107); `skills/observability/scripts/process-session.sh` agrega métricas por sesión
  (`output_tokens`, `tool_uses` clasificados, `duration_ms`) en `sessions.jsonl`, idempotente
  (Issue #104, PR #108)
- `agents/complexity-tiering.md`: guía reusable de tiering Haiku/Sonnet/Opus para
  orquestación ad-hoc de agentes fuera de `agentic-dev-loop` (PR #101)
- `docs/aura/observability.md`: referencia estable de las 3 capas de acceso a datos de
  consumo (OTEL, JSONL crudo, `<usage>` de task-notification) y métrica compuesta
  recomendada (PR #101)
- `skills/agentic-dev-loop/scripts/cleanup-merged-branch.sh`: borra la rama local tras un
  merge confirmado, dry-run por default, `--delete` solo con confirmación explícita
  (`git branch -d`, nunca `-D`) (PR #101)
- `protocols/session_start.md`, Paso 4: nueva subsección obligatoria "PRs Abiertas"
  (`gh pr list --state open`) — antes el protocolo solo miraba estado local y ramas ya
  mergeadas/huérfanas, dejando invisibles PRs abiertas esperando merge/review
  (Issue #109, PR #110, ADR-004)
- `protocols/session_start.md`, nuevo Paso 5.5: reporte compacto (tokens, tool_uses por
  tipo, duration) de la sesión anterior vía `process-session.sh`, fail-open (Issue #105,
  PR #114, ADR-005)
- `.aura/rules/routing-menu.md`: nueva opción de menú "Ver reporte de consumo de esta
  corrida" al terminar `/run-dev-loop` (Issue #106, PR #114, ADR-005)

### Fixed
- `session-start.ps1`: el bloque de auto-detección de actualización del harness tragaba
  cualquier fallo en silencio (`catch` vacío), sin distinguir "se chequeó, no hay update" de
  "el chequeo nunca corrió" — causó que un consumidor real quedara 2 minors atrasado sin
  ninguna advertencia. Ahora setea `harness_update_check_error` en el JSON del hook, mismo
  patrón que el campo `git_error` ya existente en el archivo (Issue #111, PR #112)

### Changed
- `.aura/rules/harness-core.md`: nueva regla — el agente nunca afirma el estado de algo
  verificable (PR/issue, archivo, comando, versión desplegada) sin correr la verificación en
  el mismo turno; memoria (Engram, resúmenes, historial) es hipótesis de partida, nunca
  fuente de verdad (PR #100)

## [2.1.1] - 2026-08-02

### Fixed
- `session-start.ps1` detectaba `.aura/` como git submodule (Issue #94) pero seguía resolviendo
  `check-update.sh` con `$projectRoot` en vez de `$auraPath` — el script solo existe dentro de
  `.aura/skills/...` en cualquier consumidor, por lo que la detección de actualizaciones nunca
  se ejecutaba en la práctica (Issue #96, PR #97)
- `SKILL.md` de `harness-update`: corregida la ruta documentada de invocación de
  `apply-update.sh` (vive en `.aura/`, no en la raíz del consumidor) (PR #97)

### Changed
- TTL de cache de detección de actualizaciones bajado de 6h a 30min — el chequeo corre fuera
  del contexto de Claude (subproceso del hook `SessionStart`) y no consume tokens del agente;
  el único costo real es la latencia de red del `git fetch --tags`, que no justifica esperar
  6h para detectar una actualización disponible (PR #97)

## [2.1.0] - 2026-08-02

### Added
- Infraestructura ADR (`docs/aura/adr/`): template, registro e integración obligatoria
  (feat/docs) u opcional (chore/fix) en el flujo de `finish-branch` (Issues #33/#34, PRs #85/#86)
- Política de versionado de artefactos del harness formalizada en `AGENTS.md` ("Qué se
  Versiona"), reforzando `sensitive-data-safety.md` para el ledger de planes (Issue #38, PR #87)
- Barrido de scripting determinístico (idea [016]): `classify-branch.sh` (Issue #71, PR #72),
  `post-merge.sh` (Issue #74, PR #75), `apply-branch-protection.sh` (Issue #76, PR #77),
  `new-branch-for-issue.sh` (Issue #78, PR #79)
- Git hooks nativos: `.githooks/pre-push` bloquea push directo a `develop`/`main` como segunda
  capa de enforcement independiente de Claude Code, con auto-setup de `core.hooksPath` en
  `session-start.ps1` (Issue #80, PR #81)
- `agentic-dev-loop`: apertura de PR y rechazo de review scripteados, con hardening de
  enforcement (PR #69)

### Fixed
- `apply-update.sh` ahora sincroniza correctamente las reglas `Write`→`Edit` de
  `settings.json` a repos consumidores (PR #63)
- `context-guard.ps1`: timeout defensivo del hook `UserPromptSubmit` subido de 5s a 10s
  (Issue #35, PR #84)

## [2.0.0] - 2026-07-30

### Added
- Skill `harness-update` completo: detección y aplicación de actualizaciones del harness vía
  `/harness-update` (scripts `check-update.sh` / `apply-update.sh`) (Issue #45, PR #53)
- `session-start.ps1` expone `harness_update_available`/`harness_latest_version`, cacheado con
  TTL de 6h, sin fallar sin red o sin `.aura/` (Issue #46, PR #58)

### Fixed
- Hardening de `apply-update.sh` contra 3 fallas silenciosas: propagación de errores de Python al
  exit code del script, paso correcto de argumentos posicionales a los bloques heredoc (Issue #55, PR #56)
- Regex de "Depende de" en `pick-next-issue.sh` sin anclar a heading/bullet, causaba falsos
  positivos con el texto libre del issue (PR #50)
- Resolución explícita de `bash.exe` de Git for Windows en `session-start.ps1` — en máquinas con
  WSL instalado, `Get-Command bash` puede resolver al relay de System32 y fallar en silencio sin
  distro configurada (PR #58)

## [1.4.0] - 2026-07-30

### Fixed
- Fix de permisos: usar `Edit(...)` en vez de `Write(...)` para reglas deny de secretos en `.claude/settings.json` e `integrations/claude-code/settings.json` (commit 1bca309)
- Fix de dependency-parsing en `pick-next-issue.sh`: resolvía dependencias reales correctamente (commit 25c73b9)

### Added
- Bootstrap de versionado del harness con CHANGELOG.md y git tags (v1.4.0)
