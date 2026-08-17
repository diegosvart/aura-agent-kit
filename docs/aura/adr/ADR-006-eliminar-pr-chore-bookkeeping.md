---
adr: 006
title: Eliminar PRs chore de bookkeeping — Engram como memoria primaria real
date: 2026-08-17
status: accepted
area: harness
---

# ADR-006: Eliminar PRs chore de bookkeeping — Engram como memoria primaria real

## Problema

Cada cierre de sesión generaba una rama+PR dedicada (`chore/session-close-*`) solo para
commitear `.agent/memory/current-session.json` — 21 commits históricos sobre ese único
archivo, al menos 5 PRs `chore/session-close-*` documentados en el log (`PR #70, #82, #138,
#139, #141`). Al mismo tiempo, el contenido narrativo de ese archivo (`focus`/`next_step`/
`pending` en prosa libre) expone la forma de trabajar del usuario en un repo **público** de
un modo que no desea (Issue #121) — un tipo de exposición distinto al que ya cubre
`.claude/rules/sensitive-data-safety.md` (datos de negocio del cliente, no patrones de
trabajo del usuario).

## Contexto

- Issue #121 (privacidad de `current-session.json`) e Issue #129 (reconsiderar ADR-003 —
  política de PRs de bookkeeping incremental) se investigaron juntos por estar fuertemente
  acoplados: ambos apuntan al mismo archivo y al mismo mecanismo.
- `AGENTS.md` → "Memoria" ya declaraba Engram como "Primaria" y `current-session.json` como
  "Backup" — pero en la práctica el backup seguía siendo la única fuente versionada y la que
  generaba el ciclo de PRs; Engram funcionaba como memoria secundaria de facto.
- Precedente real: al cerrar el Issue #127 (PR #140, 2026-08-06), el usuario — consultado
  explícitamente sobre si abrir una PR chore para actualizar `project-log.md` — eligió
  guardar ese bookkeeping solo en Engram, con `topic_key: project-log/pr-bookkeeping`
  (observación #337). Esta decisión quedó como precedente informal, sin codificarse todavía
  en ningún protocolo.
- Investigación de `.claude/hooks/git-guard.ps1`: solo intercepta los comandos literales
  `git commit`/`git push` cuando la rama activa es `develop`/`main`; no inspecciona archivos
  ni bloquea `Write` sobre archivos no trackeados. Un archivo gitignored nunca pasa por este
  hook porque nunca se commitea.
- Investigación de `protocols/session_start.md`: el único consumo real de
  `current-session.json` en el Resumen Ejecutivo (Paso 6) son los campos `pending` y
  `next_step` — `focus` y `required_reads` nunca se leían en la práctica pese a estar en el
  esquema desde el origen. Tampoco existía ningún fallback de lectura hacia este archivo si
  `mem_context` fallaba — el protocolo simplemente continuaba sin ese contexto.

## Decisión

1. `.agent/memory/current-session.json` deja de versionarse — se agrega a `.gitignore` y se
   ejecuta `git rm --cached` una única vez. Pasa a ser un **puntero local no versionado**,
   nunca la fuente primaria.
2. Su esquema se reduce a 3 campos telegráficos: `last_updated`, `branch`, `next_step` (una
   línea, sin narrativa de proceso). Se eliminan `focus`, `pending` (array) y
   `required_reads` — sin uso real documentado en `session_start.md`.
3. `protocols/session_end.md` (Paso 5) deja de crear rama/PR para este archivo: es un `Write`
   directo, fuera del alcance de `git-guard.ps1` por definición (nunca hay `git commit`/
   `git push` de por medio).
4. `protocols/session_start.md` (Paso 5) gana un fallback nuevo: si `mem_context` falla o
   devuelve vacío, leer `current-session.json` local y usarlo para poblar "Última Sesión" en
   el Resumen Ejecutivo, con advertencia explícita de que puede estar desactualizado. Esta es
   la única razón de ser del archivo a partir de ahora.
5. El mismo patrón se formaliza como política por defecto para `project-log.md`: sus
   entradas de bookkeeping puro (sin PR de código en curso para montarlas) se guardan en
   Engram con `topic_key: project-log/pr-bookkeeping` (upsert) en vez de abrir una PR chore
   dedicada, y se vuelcan al archivo real en la próxima PR de código que se abra
   (`agents/github.md` → "Bookkeeping sin PR real abierta"). `project-log.md` en sí **sigue
   versionado** — es el registro histórico real del proyecto, no metadata de sesión; lo que
   cambia es que deja de generar una PR solo por eso.
6. `AGENTS.md` → "Qué se Versiona": la fila "Identidad de sesión activa" pasa de **Sí** a
   **No**, referenciando este ADR.

Esto amends la fila correspondiente de `ADR-003` (que clasificaba este archivo como
versionado) sin reabrirlo — `ADR-003` queda intacto como registro histórico de esa decisión
en su momento; este ADR documenta el cambio posterior.

## Alternativas descartadas

- **Mantener versionado con contenido mínimo (solo recortar `focus`/`pending`)** — resuelve
  Issue #121 (exposición narrativa) pero no Issue #129 (volumen de PRs): seguiría generando
  una PR chore por cada cierre de sesión, aunque más pequeña.
- **Piggyback en la próxima PR de código en vez de eliminar el versionado** — descartada para
  `current-session.json` específicamente: dejaría el puntero desactualizado por sesiones
  enteras cuando no hay código en curso (sesiones de solo investigación/decisión, como la que
  motivó este mismo ADR), que es justo cuando más falta hace como fallback de continuidad. Sí
  se adopta esta alternativa para `project-log.md` (punto 5), donde el desfase temporal es
  aceptable porque Engram ya lo cubre como fuente autoritativa mientras tanto.
- **Sacar `current-session.json` del harness por completo** — descartada: sigue teniendo
  valor real como red de seguridad ante una caída de Engram (dependencia MCP externa); el
  costo de mantenerlo local y mínimo es bajo.

## Consecuencias

- Cero PRs `chore/session-close-*` nuevos a partir de ahora — el mecanismo que los generaba
  (commitear `current-session.json`) deja de existir estructuralmente, no solo se desalienta.
- `current-session.json` dejará de aparecer en `git log`/`git diff` de PRs futuras; el
  historial de las 21 actualizaciones pasadas permanece en el log del repo (no se reescribe
  historia).
- Si Engram tiene una caída prolongada, la continuidad entre sesiones depende de que el
  puntero local se haya actualizado recientemente — trade-off aceptado explícitamente (ver
  alternativas descartadas).
- `project-log.md` puede acumular una entrada pendiente en Engram por más de una sesión si no
  se abre ninguna PR de código — session_start no la superficializa automáticamente todavía;
  posible mejora futura, no bloqueante para este ADR.

## Archivos afectados

- `.gitignore` — nueva entrada para `.agent/memory/current-session.json`
- `.agent/memory/current-session.json` — untracked (`git rm --cached`), esquema reducido a 3 campos
- `protocols/session_end.md` — Paso 5 reescrito (sin rama/PR)
- `protocols/session_start.md` — Paso 5, fallback de lectura nuevo
- `AGENTS.md` — tabla "Qué se Versiona", sección "Memoria"
- `agents/github.md` — nueva sub-sección "Bookkeeping sin PR real abierta"
- `docs/aura/adr/ADR-000-registro.md` — registro de este ADR
