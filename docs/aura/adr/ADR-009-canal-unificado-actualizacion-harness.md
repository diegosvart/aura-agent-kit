---
adr: 009
title: Unificar aplicación de actualización del harness entre canal submodule y plugin
date: 2026-09-02
status: accepted
area: harness
---

# ADR-009: Unificar aplicación de actualización del harness entre canal submodule y plugin

## Problema

PR #186 (Issue #181) agregó detección de actualización para consumidores instalados vía
plugin/marketplace de Claude Code (sin `.aura/` submódulo), pero `apply-update.sh` (invocado
por `/harness-update`) solo sabe **aplicar** el canal submodule — falla explícito si `.aura/`
no es un checkout git. Un agente que ve `harness_update_channel: "plugin"` en el resumen de
sesión no tiene ningún comando único para actualizar; tendría que improvisar la secuencia de
`claude plugin` cada vez, de forma distinta en cada repo consumidor.

Más de fondo: el canal "plugin" tal como está documentado hoy (`QUICKSTART.md`) no es
alcanzable por un consumidor real — los hooks (incluido `session-start.ps1`, que dispara toda
la detección) solo se distribuyen copiándolos desde `.aura/`. Sin `.aura/`, nunca habría
`session-start.ps1` corriendo, y la detección de PR #186 nunca se dispararía. Esto ya estaba
anticipado como limitación conocida y fuera de alcance en ADR-008.

## Contexto

Ver `docs/aura/specs/2026-09-02-harness-update-plugin-apply-design.md` (P4, gitignored) para
el detalle completo de la hipótesis y las alternativas descartadas. Issue #187. Depende de
Issue #181 / PR #186 (agrega `harness_update_channel` y `harness_update_plugin_id` al cache
`.agent/memory/harness-update-check.json`, reusado acá).

Verificado en esta sesión con el `claude` CLI real de la máquina: `claude plugin list --json`
da la versión instalada + `installPath` (que contiene el árbol completo del repo, igual que
un checkout de `.aura/`); `claude plugin marketplace list --json` da el `installLocation` del
marketplace configurado; `claude plugin update <plugin>` soporta `--scope` y `-y` (no
interactivo).

## Decisión

1. `apply-update.sh` detecta el canal automáticamente (misma lógica que `session-start.ps1`:
   `.aura/.git` existe → submodule; si no → plugin, leyendo `harness_update_plugin_id` del
   cache del hook en vez de re-derivarlo).
2. Los pasos de sincronización que ya existían (copia de hooks, resync de `CLAUDE.md`, resync
   de permisos `Write→Edit` en `settings.json`, registro de `git-guard.ps1` y
   `sensitive-data-guard.ps1` en `PreToolUse`) se generalizan detrás de una variable
   `SOURCE_PATH` en vez de asumir `.aura/` — en modo submodule sigue siendo `.aura/`; en modo
   plugin es el `installPath` reportado por `claude plugin list --json` **después** de
   actualizar el plugin.
3. Solo el paso de "traer la versión nueva" difiere de verdad por canal: submodule hace
   `git fetch --tags` + `git checkout <tag>` (sin cambios); plugin hace
   `claude plugin marketplace update <marketplace>` + `claude plugin update <id> -y --scope
   <scope>`, e imprime un aviso explícito de que Claude Code requiere **reiniciar la sesión**
   para que el contenido nuevo tome efecto.
4. `QUICKSTART.md` gana una Opción C de instalación real "solo plugin, sin submodule"
   (marketplace registrado vía GitHub, no ruta local — corrige de paso el mismo bug de
   "Unknown skill" ya resuelto ad-hoc en una sesión anterior pero nunca documentado).
   `README.md`/`QUICKSTART.md` mencionan `/harness-update` explícitamente (antes ninguno de
   los dos lo nombraba; solo documentaban `git pull` manual, una versión estrictamente
   incompleta de lo que ya automatiza el script).

## Alternativas descartadas

- **Dos scripts separados por canal**: duplicaría los 4 pasos de sincronización que son
  idénticos entre canales — la única diferencia real es cómo se obtiene la versión nueva.
- **Agregar solo el paso de `claude plugin update`, sin generalizar hooks**: no resuelve el
  gap de fondo — un consumidor solo-plugin seguiría sin `session-start.ps1`, por lo que nada
  de esto llegaría a ejecutarse para él en primer lugar.

## Consecuencias

- `/harness-update` queda utilizable de punta a punta para cualquier agente, sin importar
  cómo se instaló el harness en ese repo consumidor.
- El canal "plugin" pasa de ser una detección sin aplicación posible, a un flujo completo
  instalable y actualizable de forma real.
- Verificación end-to-end con un consumidor externo genuino (no este mismo repo
  dogfogueándose) queda pendiente — ver "Riesgo / Salvaguarda" en la spec.

## Archivos afectados

- `skills/harness-update/scripts/apply-update.sh` — detección de canal + generalización de
  `SOURCE_PATH` + rama de aplicación plugin
- `skills/harness-update/SKILL.md` — documenta ambos canales de aplicación
- `commands/harness-update.md` — quita la precondición "solo submodule"
- `QUICKSTART.md` — Opción C de instalación solo-plugin, mención de `/harness-update`
- `README.md` — mención de `/harness-update`, corrección del ejemplo de marketplace local
