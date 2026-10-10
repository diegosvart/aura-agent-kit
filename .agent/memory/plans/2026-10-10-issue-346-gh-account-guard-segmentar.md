---
status: approved
issue: 346
date: 2026-10-10
---

# Plan Issue #346: no bloquear texto entre comillas en gh-account-guard.ps1

## Beneficio
Un `--body`, `--title`, `-m` o `echo` que contiene "git push" / "gh pr create" deja de disparar un bloqueo falso en el hook de cuenta gh, sin dejar pasar escrituras remotas reales.

## Hallazgo
Segmentar con `Split-ShellSegments` no alcanza: el texto entre comillas queda dentro de un solo segmento. Vaciar todo texto entre comillas tampoco: deja pasar `bash -c "git push"` (hallazgo de `/code-review`). El review tambien mostro que la segmentacion no aporta deteccion (los regex necesitan espacios, los separadores no lo son). Decision final: `Remove-QuotedContent` vacia solo valores de flags de texto libre y el argumento de `echo`/`printf`; se elimina `Split-ShellSegments` para no duplicar codigo de `pr-base-guard.ps1`.

## Pasos
1. RED: tests de falso positivo y de bypass (`bash -c`, `pwsh -Command`, `sh -c`) en `gh-account-guard.Tests.ps1`. Despacho: INLINE.
2. GREEN: `Remove-QuotedContent` en `gh-account-guard.ps1`. Despacho: INLINE.
3. `/code-review` (2 pasadas). Despacho: DELEGAR (review aislable).

## Alternativas descartadas
- Dot-sourcear `pr-base-guard.ps1`: su punto de entrada lee stdin.
- Copiar `Split-ShellSegments`: duplicacion sin valor de deteccion.
- Vaciar todo texto entre comillas: bypass de `bash -c "..."`.
- Modulo compartido: obliga a modificar `pr-base-guard.ps1`, fuera de scope.

## Never / Ask First
- Never: tocar `pr-base-guard.ps1`; cubrir heredocs o `$(...)` (punto 9 de #340, requiere `/brainstorm`).
- Limite conocido: `echo "git push" | sh` y `-m "x $(git push)"` evaden el guard; el guard detecta cambio accidental de cuenta, no frena a un atacante.
