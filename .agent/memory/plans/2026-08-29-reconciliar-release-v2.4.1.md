---
status: done
date: 2026-08-29
---

# Reconciliar main/develop, volcar project-log.md y cortar release v2.4.0/v2.4.1

> Registrado retroactivamente al cierre de sesión (2026-08-30) — el plan fue aprobado vía
> `ExitPlanMode` el 2026-08-29 pero no se copió al ledger en ese momento. Se agrega ahora
> directamente en `status: done`, ya que la implementación (PRs #160/#162-165, Issue #161,
> tag v2.4.1) se completó y verificó en la misma sesión.

## Contexto

La tarea original era simple: volcar a `.agent/memory/project-log.md` el release v2.3.0
(PRs #150/#151/#152) y el fix de PR #153 (CRLF en `manifest.txt`), y cortar un patch
release v2.3.1 para propagar ese fix a consumidores externos vía `/harness-update`.

Al verificar el estado real del repo antes de actuar, se detectó que `main` y `develop`
habían divergido: PR #159 (`feat(harness): agente browser-control`) se había ramificado y
mergeado directo contra `main`, saltándose `develop` — violación de la convención de
`agents/github.md`. Esa misma sesión externa también había taggeado y publicado su propio
GitHub Release `v2.4.0` sin pasar por `cut-release.sh`.

El usuario decidió (vía `AskUserQuestion`): reconciliar `main`→`develop` primero y cortar
el próximo release real como `v2.4.0`/`v2.4.1` (no un patch v2.3.1 aislado).

## Qué se hizo

1. PR #160 — reconcilió `main`→`develop` (trajo PR #159), agregó 4 entradas a
   `project-log.md`, completó la sección `[2.4.0]` del CHANGELOG.
2. Issue #161 — trazabilidad del incidente (PR #159 mergeado directo a `main`).
3. PR #162 — primer intento de `promote` develop→main.
4. Descubrimiento en el paso `tag`: el tag/release `v2.4.0` ya existía publicado (de la
   sesión de PR #159), desactualizado respecto al estado reconciliado. Decisión del
   usuario (`AskUserQuestion`): taguear `v2.4.1` en vez de sobreescribir el release ya
   público.
5. PR #163 (changelog v2.4.1), PR #164 (promote v2.4.1, merge commit `40bcfb7`), PR #165
   (sync-back). Tag `v2.4.1` → `40bcfb7`.

## Verificación

- `git log --oneline main..develop` / `develop..main`: vacíos tras el sync-back.
- `git describe --tags` en develop resuelve contra `v2.4.1`.
- `check-repo-manifest.sh` / `check-release-drift.sh`: sin salida.
- `gh pr list --state open`: sin PRs abiertas del flujo.

## Seguimiento

La causa raíz del incidente (PR #159 mergeado fuera de `develop`) se investigó en paralelo
(fork de esta misma sesión) y se corrigió en PR #166 — ver entrada de
`.agent/memory/project-log.md` del 2026-08-30 y
`docs/aura/specs/2026-08-29-claude-code-worktree-conflict-and-agent-browser.md`.
