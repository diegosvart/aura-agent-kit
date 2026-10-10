---
status: approved
issue: 346
date: 2026-10-10
---

# Plan Issue #346: segmentar comandos en gh-account-guard.ps1

## Beneficio
Un `--body` o texto entre comillas que contiene "git push" / "gh pr create" deja de disparar un bloqueo falso en el hook de cuenta gh.

## Hallazgo
Segmentar con `Split-ShellSegments` no alcanza: el texto entre comillas queda dentro de un solo segmento. Se agrega `Remove-QuotedContent` para vaciarlo antes de matchear.

## Pasos
1. RED: 4 tests en `gh-account-guard.Tests.ps1` (2 falsos positivos, 2 bloqueos reales). Despacho: INLINE.
2. GREEN: copiar `Split-ShellSegments` y agregar `Remove-QuotedContent` en `gh-account-guard.ps1`. Despacho: INLINE.
3. Verificar suite y lanzar `/code-review`. Despacho: DELEGAR (review aislable).

## Alternativas descartadas
- Dot-sourcear `pr-base-guard.ps1`: su punto de entrada lee stdin.
- Extraer módulo compartido: obliga a modificar `pr-base-guard.ps1`, fuera de scope.

## Never / Ask First
- Never: tocar `pr-base-guard.ps1`; cubrir heredocs o `$(...)` (punto 9 de #340, requiere `/brainstorm`).
