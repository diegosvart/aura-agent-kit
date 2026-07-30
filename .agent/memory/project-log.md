# Project Log — Aura Agent Kit

> Bitácora de qué se agregó al proyecto, en lenguaje de negocio. Un bloque nuevo por PR
> mergeada, siempre arriba de todo (orden cronológico inverso). Ver `agents/github.md` →
> "Al Mergear una PR a Develop".

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
