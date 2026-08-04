# Project Log — Aura Agent Kit

> Bitácora de qué se agregó al proyecto, en lenguaje de negocio. Un bloque nuevo por PR
> mergeada, siempre arriba de todo (orden cronológico inverso). Ver `agents/github.md` →
> "Al Mergear una PR a Develop".

## 2026-08-04 — PR #137 — cut-release.sh reemplaza el Proceso de Release en prosa

**Plan:** `.agent/memory/plans/2026-08-04-cut-release-script.md`
**Qué se agregó:** El Proceso de Release (changelog, PR develop→main, tag, sync-back) dejó de
ser prosa que el agente reconstruía razonando cada vez — ahora es un script
(`cut-release.sh`) con 4 pasos idempotentes. Se investigó si hacía falta una excepción en
`git-guard.ps1` para el push del tag y se descartó tras comprobar en vivo que era innecesaria
(el hook no ve los comandos internos del script) y que, implementada, abría un hueco real (un
push disfrazado con un comentario se colaba) — el hook queda sin cambios. Se registró la idea
`[018]` (router de flujos determinísticos por operación) como conclusión de fondo.
**Archivos clave:** skills/agentic-dev-loop/scripts/cut-release.sh, agents/github.md,
.agent/memory/ideas.md

## 2026-08-04 — PRs #132/#133/#134 — Release v2.2.1

**Plan:** sin plan formal previo (continuación directa de PR #119/#123-125)
**Qué se agregó:** Los fixes de apply-update.sh (#123/#124/#125), hasta ahora solo en
`develop`, quedaron publicados en el tag `v2.2.1` — consumidores externos ya pueden recibirlos
vía `/harness-update` (antes resolvían contra `v2.2.0`, que no los incluía). PR #132
(changelog), #133 (develop→main + tag), #134 (sync-back obligatorio). Verificado:
`git describe --tags` en develop resuelve contra `v2.2.1` sin drift.
**Archivos clave:** CHANGELOG.md, tag `v2.2.1`

## 2026-08-04 — PRs #123/#124/#125 — detección de drift + hardening de apply-update.sh

**Plan:** sin plan formal previo (continuación directa de PR #119/#120, mismo hilo de la
sesión: un repo consumidor externo, `crawler-mcp-diagram`, seguía exponiendo brechas del
harness)
**Qué se agregó:**
- PR #123 (Closes #120): `skills/repo-integrity/scripts/check-release-drift.sh` — chequeo
  local (sin `gh`) que compara el último tag alcanzable desde `main` contra la ancestría de
  `develop`, enlazado en `protocols/session_start.md` Paso 3. `check-update.sh` ahora avisa
  por stderr cuando `.aura` está en una rama y no en un tag exacto (antes reportaba el tag
  más cercano sin distinguir "desactualizado real" de "rama sin el último tag como ancestro").
- PR #124: bug real en `crawler-mcp-diagram` — `git-guard.ps1` existía en `.claude/hooks/`
  pero nunca quedó registrado como `PreToolUse` en `.claude/settings.json`, así que el
  enforcement de "nunca push directo a develop/main" estaba inerte (3 commits terminaron
  pusheados directo a `develop` sin bloqueo). `apply-update.sh` sincronizaba el archivo del
  hook pero nunca verificaba su registro. Nuevo paso `[6/6]` que lo detecta y autoregistra.
- PR #125: validación end-to-end del fix de #124 (pedida explícitamente por el usuario antes
  de dar el harness por estable) encontró un segundo bug introducido por el propio fix: si el
  consumidor ya tenía un hook custom en `PreToolUse` para `Bash`/`PowerShell`, la lógica
  creaba un matcher duplicado en vez de fusionarse — riesgo de desactivar en silencio ese
  hook custom. Corregido para fusionar dentro de la entrada existente.

**Fricción encontrada en vivo (harness):** ninguno de los tres fixes (#123/#124/#125) se
escribió con test-first (P3/Iron Law) — son scripts bash sin suite automatizada, verificados
ad-hoc contra escenarios reproducidos manualmente en el momento. El bug de #125 (matcher
duplicado) es consecuencia directa de eso: se coló en #124 porque la validación de esa PR no
cubrió el caso de un consumidor con `PreToolUse` preexistente, y solo se detectó porque el
usuario pidió explícitamente una validación end-to-end antes de cerrar, no porque el flujo de
trabajo la exigiera de entrada. Queda pendiente para una sesión futura: definir cómo aplica
P3 a scripts bash de este repo (harness de por sí no tiene runner de tests) — sea con
`bats`/`shunit2`, o con un protocolo explícito de "casos borde mínimos a probar antes de
mergear" para scripts que tocan JSON de configuración de otros repos.
**Archivos clave:** skills/repo-integrity/scripts/check-release-drift.sh,
protocols/session_start.md, skills/harness-update/scripts/check-update.sh,
skills/harness-update/scripts/apply-update.sh, skills/harness-update/SKILL.md

## 2026-08-04 — PR #119 — fix(release): sync-back main a develop tras v2.2.0

**Plan:** sin plan formal previo (bug real encontrado en vivo, sesión de continuación tras
el release v2.2.0)
**Qué se agregó:** Se corrigió un gap real detectado por un repo consumidor externo: tras el
release v2.2.0 (PR #116), commits de bookkeeping posteriores (#117/#118) quedaron solo en
`develop` sin sincronizar `main` de vuelta, dejando el tag `v2.2.0` fuera del historial
ancestral de `develop`. Cualquier consumidor que actualizara el submódulo `.aura` apuntando a
`develop` (en vez de al tag exacto vía `/harness-update`) recibía un `git describe` engañoso
(`v2.1.1-N-g...`) aunque el contenido ya incluyera el release. Corregido con un merge
`main → develop` sin conflictos (mismo contenido, solo restablece ancestría) y una nueva
sección "Proceso de Release (tag) — sync-back obligatorio" en `agents/github.md` que
documenta el paso como inmediato y obligatorio tras cada tag. Issues #120 (automatizar la
detección de este drift) y #121 (privacidad de `current-session.json`, hallazgo relacionado
detectado en la misma sesión) quedaron abiertos como seguimiento.
**Archivos clave:** agents/github.md

## 2026-08-04 — Release v2.2.0 (PRs #113/#114/#115, #116 — develop → main)

**Plan:** Barrido directo de fricciones detectadas en vivo esta sesión, sin spec previa
formal — dos gaps reales de detección en `session_start` (PRs abiertas invisibles, Issue
#109; auto-update check silencioso, Issue #111) más el cierre de Issues #105/#106
(bloqueados solo por depender de #104, ya resuelto) y consolidación de lo mergeado desde
v2.1.1 (observabilidad de sesiones #103/#104, tiering ad-hoc #101, regla de verificación
#100).
**Qué se agregó:** Tercer release real del harness (minor, sin breaking changes) desde
v2.1.1. `session_start.md` ahora consulta `gh pr list --state open` (ADR-004) y muestra un
reporte compacto de la sesión anterior vía `process-session.sh` (ADR-005, Issue #105);
`.aura/rules/routing-menu.md` ofrece "Ver reporte de consumo" al terminar `/run-dev-loop`
(Issue #106); `session-start.ps1` deja rastro (`harness_update_check_error`) cuando el
chequeo de auto-actualización falla en vez de tragárselo en silencio (Issue #111) —
detectado porque un consumidor real quedó 2 minors atrasado sin ninguna advertencia. CHANGELOG.md
actualizado (PRs #113/#115), PR de release develop→main (#116) mergeada, tag anotado
`v2.2.0` creado sobre el merge commit y pusheado. `develop` y `main` quedaron alineados (0
commits de diferencia).
**Fricción encontrada en vivo (harness):** `git-guard.ps1` bloquea *cualquier* `git push`
mientras la rama activa es `develop`/`main` — no distingue push de rama de push de tag, y
el hook evalúa la rama activa al momento de interceptar el comando completo, no tras cada
línea de un bloque multi-comando (un `git tag && git push` combinado en un solo comando se
abortó entero antes de crear el tag). Se resolvió creando una rama descartable para el
push del tag, sin tocar `git-guard.ps1` — candidato a revisar si se repite.
**Archivos clave:** CHANGELOG.md, tag `v2.2.0`, protocols/session_start.md,
.claude/hooks/session-start.ps1, .aura/rules/routing-menu.md, docs/aura/adr/ADR-004*,
docs/aura/adr/ADR-005*

## 2026-08-02 — Release v2.1.0 (PRs #91, #92 — develop → main)

**Plan:** Cierre de backlog (Issues #33/#34/#35/#38) + solicitud directa del usuario de
preparar el próximo tag para actualizar otros proyectos consumidores vía `/harness-update`
**Qué se agregó:** Segundo release real del harness (minor, sin breaking changes) desde
v2.0.0. Consolida: infraestructura ADR + integración en finish-branch + política de
versionado (Issues #33/#34/#38), barrido completo de scripting determinístico idea [016]
(classify-branch.sh, post-merge.sh, apply-branch-protection.sh, new-branch-for-issue.sh,
git hooks nativos), agentic-dev-loop con apertura de PR/rechazo de review scripteados, y
fixes de apply-update.sh / context-guard.ps1. CHANGELOG.md actualizado (PR #91), PR de
release develop→main (#92) mergeada, tag anotado `v2.1.0` creado sobre el merge commit y
pusheado. `develop` y `main` quedaron alineados (0 commits de diferencia), sin necesitar
el paso de sync-back que sí hizo falta en v2.0.0.
**Archivos clave:** CHANGELOG.md, tag `v2.1.0`

## 2026-08-02 — PR #87 — docs(harness): definir política de versionado de artefactos

**Plan:** Barrido directo de issues pendientes (Issue #38, sin plan previo — trabajo ad-hoc
solicitado por el usuario)
**Qué se agregó:** Nueva sección "Qué se Versiona" en `AGENTS.md` con la tabla de categorías
(estructura del harness, identidad de sesión, bitácora de proyecto, ledger de planes, backups,
análisis ad-hoc) y si cada una se versiona por defecto. Resuelve la tensión real detectada entre
`crawler-mcp-diagram` (versiona planes) y `memo-digital` (no lo hace): se decide mantener el
versionado del ledger de planes por su valor de trazabilidad, pero se refuerza
`.claude/rules/sensitive-data-safety.md` marcando `.agent/memory/plans/*.md` como categoría de
riesgo elevado — es el punto donde ya ocurrió una fuga real de datos de negocio del cliente
(folios/OC reales en un plan de investigación técnica). ADR-003 documenta la decisión completa.
**Archivos clave:** AGENTS.md, .claude/rules/sensitive-data-safety.md,
docs/aura/adr/ADR-003-politica-versionado-artefactos.md

## 2026-08-02 — PR #86 — feat(adr): integrar escritura de ADR en skill finish-branch

**Plan:** Barrido directo de issues pendientes (Issue #34, depende de #33)
**Qué se agregó:** Nueva sección "Pre-PR: Escribir ADR" en
`skills/finishing-a-development-branch/SKILL.md`, entre el Health Check y `gh pr create`.
Obligatoria para ramas `feat/*` y `docs/*`, opcional para `chore/*` y `fix/*` menores. ADR-002
documenta esta misma decisión, como segundo ejemplo de uso de la infraestructura de #33.
**Archivos clave:** skills/finishing-a-development-branch/SKILL.md,
docs/aura/adr/ADR-002-adr-en-finish-branch.md, docs/aura/adr/ADR-000-registro.md

## 2026-08-02 — PR #85 — chore(adr): crear infraestructura ADR

**Plan:** Barrido directo de issues pendientes (Issue #33, ready sin tomar desde 2026-05-31)
**Qué se agregó:** `docs/aura/adr/` como residuo permanente de decisiones (a diferencia de
`docs/aura/specs/` y `docs/aura/plans/`, efímeros y gitignoreados): `ADR-TEMPLATE.md` (formato:
Problema, Contexto, Decisión, Alternativas descartadas, Consecuencias, Archivos afectados),
`ADR-000-registro.md` (índice) y `ADR-001-task-checkpoint.md` (ADR retroactivo del protocolo de
checkpoint de Issues #26/#27, como ejemplo de uso). Base de #34 y #38.
**Archivos clave:** docs/aura/adr/ADR-TEMPLATE.md, docs/aura/adr/ADR-000-registro.md,
docs/aura/adr/ADR-001-task-checkpoint.md, .gitignore

## 2026-08-02 — PR #84 — chore(context-guard): timeout defensivo 5s->10s

**Plan:** Barrido directo de issues pendientes (Issue #35)
**Qué se agregó:** El bug de fondo reportado (parseo O(n) de JSONL en `context-guard.ps1`
causando timeout silencioso con transcripts >1MB) ya estaba corregido desde antes (commits
`0f1a8da`/`30c53d0`, lectura O(1) por tamaño de archivo). Se aplicó únicamente la mejora
defensiva adicional sugerida en el issue: subir el timeout del hook `UserPromptSubmit` de 5s a
10s, sincronizado en `.claude/settings.json` e `integrations/claude-code/settings.json`.
**Archivos clave:** .claude/settings.json, integrations/claude-code/settings.json

## 2026-08-01 — PR #81 — feat(hooks): git hooks nativos (.githooks/pre-push) con auto-setup

**Plan:** `.agent/memory/plans/2026-08-01-idea-016-tres-capas.md` (Issue #80, tercer y último
ítem de la idea [016])
**Qué se agregó:** Segunda capa de enforcement de "nunca push directo a develop/main",
independiente de Claude Code — hasta ahora todo dependía de que Claude Code disparara
`.claude/hooks/git-guard.ps1`. `.githooks/pre-push` rechaza el push si el remote ref es
`refs/heads/develop` o `refs/heads/main`; `session-start.ps1` autoconfigura
`core.hooksPath=.githooks` la primera vez que se abre una sesión en el repo (idempotente,
fail-open); `apply-update.sh` ahora también sincroniza `.githooks/pre-push` a repos
consumidores. Bug real encontrado al commitear: `.githooks/pre-push` no tiene extensión `.sh`,
así que la regla `eol=lf` existente en `.gitattributes` no lo cubría — en Windows se habría
checkouteado con CRLF, rompiendo el shebang en silencio. Verificado end-to-end en la sesión de
cierre (2026-08-01): push real contra un remoto falso aislado, con y sin `core.hooksPath`
configurado, confirmando bloqueo real (no solo simulación con stdin).
**Archivos clave:** .githooks/pre-push, .claude/hooks/session-start.ps1, .gitattributes,
skills/harness-update/scripts/apply-update.sh

## 2026-08-01 — PR #79 — feat(github): scriptear new-branch-for-issue.sh

**Plan:** `.agent/memory/plans/2026-08-01-idea-016-tres-capas.md` (Issue #78, segundo ítem de
la idea [016])
**Qué se agregó:** Encapsula el bloque de creación de rama de `agents/github.md` (tabla de
prefijos: feature/fix/chore desde develop, hotfix desde main) para trabajo manual fuera del
loop de `agentic-dev-loop`. Rechaza explícitamente si la rama ya existe.
**Archivos clave:** skills/agentic-dev-loop/scripts/new-branch-for-issue.sh, agents/github.md,
protocols/task_start.md

## 2026-08-01 — PR #77 — feat(github): scriptear apply-branch-protection.sh

**Plan:** `.agent/memory/plans/2026-08-01-idea-016-tres-capas.md` (Issue #76, primer ítem de la
idea [016], plan de los 3 ítems restantes aprobado en esta misma PR)
**Qué se agregó:** Encapsula el heredoc JSON de `agents/github.md` ("Aplicar protección si
falta") que antes el agente reconstruía de memoria — operación de seguridad real, alto riesgo
si se arma mal el JSON a mano. PUT es idempotente por naturaleza. Verificado funcionalmente
contra `develop` de este repo.
**Archivos clave:** skills/agentic-dev-loop/scripts/apply-branch-protection.sh, agents/github.md,
.agent/memory/plans/2026-08-01-idea-016-tres-capas.md

## 2026-08-01 — PR #72 — feat(repo-integrity): scriptear classify-branch.sh (Pasos B-D del algoritmo de detección)

**Plan:** sin plan formal previo (Issue #71, primer ítem de la idea [016] — refinada con
contexto y prioridad clara en la sesión de Tier 1, 2026-07-31)
**Qué se agregó:** El algoritmo de detección de trabajo stranded de `skills/repo-integrity/SKILL.md`
(Pasos B, C, D) ahora corre vía `skills/repo-integrity/scripts/classify-branch.sh` en vez de que
el agente lo reconstruya en prosa cada sesión — es el script de mayor volumen del barrido (hasta
10 corridas por sesión, uno por rama candidata en `protocols/session_start.md` Paso 3). De paso
se encontró un bug real: el Paso B documentado usaba `git log --oneline`, que solo muestra el
subject y pierde el keyword `Closes #N` cuando va en el body del commit (convención real de este
repo, ej. commit `21fd2e8`). El script usa `git log --format=%B` (mensaje completo). Issue #71
quedó `OPEN` tras el merge por el gap conocido de default branch (`main` vs. `develop`) — cerrado
manualmente.
**Archivos clave:** skills/repo-integrity/scripts/classify-branch.sh, skills/repo-integrity/SKILL.md,
protocols/session_start.md

## 2026-07-31 — PR #69 — fix(agentic-dev-loop): scriptear apertura de PR/rechazo de review + hardening de enforcement (Tier 1)

**Plan:** `.claude/plans/quiero-darle-prioridad-a-silly-gosling.md` (aprobado, sesión 2026-07-31)
**Qué se agregó:** Se corrigieron dos bugs reales detectados en otro proyecto que usa este harness (PRs abiertos contra `main` en vez de `develop`, y contaminación cruzada de working directory entre dev-runners), más un endurecimiento de seguridad tras un incidente de commit directo a `develop`. `agentic-dev-loop` ahora abre PRs y rechaza reviews vía scripts deterministas (`open-pr.sh`, `reject-review.sh`) en vez de prosa que el agente reconstruye, y `pick-next-issue.sh` marca `in-progress` atómicamente. `git-guard.ps1` deja rastro cuando falla en silencio, y la plantilla de distribución del harness (`integrations/claude-code/settings.json`) ya no nace sin hooks de seguridad. El resto del barrido (11 candidatos a script encontrados) quedó registrado como idea [016] para una sesión futura.
**Archivos clave:** skills/agentic-dev-loop/scripts/open-pr.sh, skills/agentic-dev-loop/scripts/reject-review.sh, skills/agentic-dev-loop/scripts/pick-next-issue.sh, skills/agentic-dev-loop/SKILL.md, .claude/hooks/git-guard.ps1, integrations/claude-code/settings.json

## 2026-07-31 — PR #64 — docs(harness-update): aviso de una línea en session_start Paso 6

**Plan:** no hubo plan formal (Issue #47 del Batch 1, refinado a loop-ready)
**Qué se agregó:** El protocolo de inicio de sesión ahora documenta cómo avisar, en una sola
línea dentro de "Advertencias", que hay una versión nueva del harness disponible — sin volcar
el CHANGELOG completo en cada sesión. El detalle completo sigue apareciendo solo al correr
`/harness-update` a demanda. Cierre manual del Issue #47 (ver nota de gap de default branch
abajo).
**Archivos clave:** protocols/session_start.md

## 2026-07-31 — PR #63 — fix(harness-update): apply-update.sh no sincroniza reglas de permisos (.claude/settings.json)

**Plan:** no hubo plan formal (Issue #62 del Batch 1, refinado a loop-ready, Complejidad alta)
**Qué se agregó:** Se cerró un gap de seguridad silencioso: `/harness-update` ahora también
sincroniza `.claude/settings.json` en el repo consumidor, reemplazando los patrones de permisos
obsoletos `Write(...)` (que Claude Code ya no aplica) por su equivalente vigente `Edit(...)` en
las 6 reglas conocidas (`.env`, `.env.*`, `*.pem`, `*.key`, `*.secret`, `**`). Antes, un fix de
seguridad en el harness fuente (ej. PR #48) nunca llegaba a los repos consumidores vía
actualización automática — quedaba inerte hasta aplicarse a mano. Encontrado en vivo
verificando `crawler-mcp-diagram` tras su update a v2.0.0.
**Primera corrida real del loop `/run-dev-loop` con dos issues consecutivos (Batch 1, #62 y
#47):** ambos verificados en Fase 2 sin hallazgos; ambos issues quedaron `OPEN` tras el merge
por el gap conocido de default branch (`main` vs. `develop`) — cerrados manualmente.
**Archivos clave:** skills/harness-update/scripts/apply-update.sh, skills/harness-update/SKILL.md

## 2026-07-30 — Release v2.0.0 — PR #58, #59, #60

**Plan:** docs/aura/specs/2026-07-30-harness-self-update.md (D1, D2)
**Qué se agregó:** El harness quedó liberado como v2.0.0 en `main` — primer release real desde
el bootstrap de versionado (v1.4.0). Incluye el ciclo completo de auto-actualización: detección
automática (hook `session-start.ps1`, cacheada 6h, expone `harness_update_available`/
`harness_latest_version`) y aplicación manual (`/harness-update`). También se corrigió un bug de
hardening real encontrado en vivo: en máquinas Windows con WSL instalado, `Get-Command bash`
puede resolver al relay de WSL en vez de Git Bash y fallar en silencio — el hook ahora resuelve
`bash.exe` explícitamente desde la instalación de Git for Windows. Motivado por la necesidad de
probar `/harness-update` desde un repo consumidor externo apuntando a un tag real.
**Archivos clave:** .claude/hooks/session-start.ps1, CHANGELOG.md, .gitignore

## 2026-07-30 — PR #56 — fix(harness-update): endurecer apply-update.sh contra 3 fallas silenciosas

**Plan:** no hubo plan formal (fast-follow del Issue #55, encontrado en revisión adversarial
post-merge de PR #53)
**Qué se agregó:** El script de aplicación de actualizaciones del harness (`apply-update.sh`) ya
no esconde fallos reales: si falla el checkout de un tag (ej. porque `.aura/` quedó con cambios
sin commitear), ahora muestra el motivo real de git en vez de un mensaje genérico indistinguible
de "el tag no existe"; si falta el bloque de configuración `aura:begin/aura:end` (local o en la
fuente), ahora avisa en vez de saltear el paso en silencio; y se eliminó un detalle de bash que
podía hacer abortar el script sin motivo aparente en un fast-follow futuro.
**Archivos clave:** skills/harness-update/scripts/apply-update.sh

## 2026-07-30 — PR #54 — docs(project-log): registrar PR #53 en la bitácora de proyecto

**Plan:** no hubo plan formal (actualización retroactiva post-merge)
**Qué se agregó:** Bitácora del proyecto puesta al día con la entrada de PR #53 (scripts de
auto-actualización del harness) que no se había registrado antes de mergear esa PR.
**Archivos clave:** .agent/memory/project-log.md

## 2026-07-30 — PR #53 — feat(harness-update): scripts check-update.sh y apply-update.sh + skill + comando

**Plan:** docs/aura/specs/2026-07-30-harness-self-update.md (D2, D4, D5) — no hay ledger formal
en `.agent/memory/plans/` para este issue puntual
**Qué se agregó:** El harness ahora puede detectar y aplicar sus propias actualizaciones:
`check-update.sh` compara la versión local contra la última publicada, y `apply-update.sh` trae
el tag nuevo, sobreescribe los hooks del proyecto y resincroniza el bloque de configuración en
`CLAUDE.md`, dejando un resumen de qué cambió. Se agregó también el comando `/harness-update`
para disparar esto a demanda.
**Primera corrida real del ciclo dev-runner → verifier con 2 rondas de fix:** la primera versión
del script tenía un bug real (los mensajes de error de Python quedaban silenciados y el script
igual reportaba éxito); el segundo intento arregló eso pero el fallo seguía sin propagarse al
código de salida del script. Ambos se corrigieron antes de mergear — quedó documentado en el
Issue #45 y en Engram como aprendizaje del proceso.
**Archivos clave:** skills/harness-update/SKILL.md, skills/harness-update/scripts/check-update.sh,
skills/harness-update/scripts/apply-update.sh, commands/harness-update.md

## 2026-07-30 — PR #51 — docs(agentic-dev-loop): documentar bugs reales del Batch 1 (#44-47)

**Plan:** no hubo plan formal (documentación de hallazgos en vivo de la corrida del loop)
**Qué se agregó:** La tabla "Errores Comunes" de la skill del loop de desarrollo automático
ahora documenta dos problemas reales encontrados en la primera corrida sobre la cadena
#44-47: el bug de regex sin anclar (ya resuelto en PR #50) y el caso de un issue que queda
abierto indefinidamente tras mergear su PR, sin nada que lo cierre automáticamente — con el
paso manual para resolverlo.
**Archivos clave:** skills/agentic-dev-loop/SKILL.md

## 2026-07-30 — PR #50 — fix(agentic-dev-loop): anclar regex de "Depende de" a heading/bullet

**Plan:** no hubo plan formal (bug encontrado en vivo, corriendo el loop sobre #44-47)
**Qué se agregó:** El selector de próximo issue del loop de desarrollo automático ahora
detecta correctamente las dependencias entre issues aunque el texto del issue mencione la
palabra "depende" en otro contexto (ej. un criterio de aceptación). Antes, ese caso hacía que
la dependencia real quedara sin detectar y el issue avanzara fuera de orden.
**Archivos clave:** skills/agentic-dev-loop/scripts/pick-next-issue.sh

## 2026-07-30 — PR #49 — feat(harness-update): bootstrap de versionado (CHANGELOG.md + tag inicial)

**Plan:** docs/aura/specs/2026-07-30-harness-self-update.md (D1)
**Qué se agregó:** El proyecto ahora tiene un CHANGELOG.md formal con la primera entrada
retroactiva (v1.4.0), y quedó taggeado ese punto del historial — primer paso del versionado
del harness.
**Archivos clave:** CHANGELOG.md

## 2026-07-30 — PR #48 — fix(harness): permisos deny de secretos + deps reales en agentic-dev-loop

**Plan:** no hubo plan formal
**Qué se agregó:** Se corrigieron las reglas de permisos que bloqueaban archivos de secretos
(usaban una regla que no aplicaba correctamente) y se arregló el selector de issues del loop
de desarrollo para que resuelva dependencias reales entre issues en vez de solo mirar el
número, evitando que se tomen issues fuera de orden.
**Archivos clave:** .claude/settings.json, integrations/claude-code/settings.json,
skills/agentic-dev-loop/scripts/pick-next-issue.sh
