# Project Log — Aura Agent Kit

> Bitácora de qué se agregó al proyecto, en lenguaje de negocio. Un bloque nuevo por PR
> mergeada, siempre arriba de todo (orden cronológico inverso). Ver `agents/github.md` →
> "Al Mergear una PR a Develop".

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
