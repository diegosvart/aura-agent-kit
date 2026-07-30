# Project Log — Aura Agent Kit

> Bitácora de qué se agregó al proyecto, en lenguaje de negocio. Un bloque nuevo por PR
> mergeada, siempre arriba de todo (orden cronológico inverso). Ver `agents/github.md` →
> "Al Mergear una PR a Develop".

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
