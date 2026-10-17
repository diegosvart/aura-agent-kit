---
status: approved
issue: 379
date: 2026-10-11
---

# Plan Issue #379 — Validación de repo_type compartida

## Qué
Agregar a `.claude/hooks/repo-classification.ps1` la lista única `$script:ValidRepoTypes = @('harness','personal','cliente')` y `Get-RepoClassificationStatus` (devuelve `{status, repo_type, classified_at, classified_by, error}` con status `ok|missing|corrupt|invalid`). La validación del tipo es inline con `-cnotin $script:ValidRepoTypes`; no hay función `Test-RepoType`. `session-start.ps1` y `sensitive-data-guard.ps1` consumen el helper.

## Beneficio
Agregar o cambiar un tipo de repo toca un solo lugar; desaparece el riesgo de drift entre el hook de inicio y el guard fail-closed.

## Por qué (verificado en el código actual)
- `session-start.ps1` líneas ~151-171: `$validRepoTypes = @("harness","personal","cliente")` + lógica propia de missing/corrupt/invalid.
- `sensitive-data-guard.ps1` `Test-MemorySaveGuard` (~154-170): compara literalmente `harness`, `personal`, `cliente` y trata `$null`/otro como bloqueo (fail-closed): segunda copia implícita de la lista.
- `Get-RepoClassification` (usado además por `gh-account-guard.ps1`) devuelve `$null` para ausente y corrupto; NO debe cambiar su contrato.
- Archivo vacío o solo espacios: `ConvertFrom-Json` devuelve `$null` sin excepción; session-start ya lo reporta como `invalid`. Se conserva ese comportamiento.
- BOM: `Get-Content -Raw` ya descarta el BOM, no hace falta código extra.

## Cómo
1. `Get-RepoClassificationStatus -RepoRoot`: ausente -> missing; excepción de parseo -> corrupt (error=mensaje); resultado `$null` (archivo vacío/solo espacios) -> invalid; repo_type ausente, no-string o fuera de la lista (`-cnotin`, case-sensitive para preservar el fail-closed de typos como "clientee" o "Cliente") -> invalid; si no -> ok. Sin recorte de BOM ni `TrimStart`.
2. session-start: mapeo directo del status a `$output.repo_classification` (conserva el esquema JSON actual). Si falta `repo-classification.ps1` (dot-source falla), degradar a status `corrupt` sin romper la salida JSON.
3. sensitive-data-guard: `Test-MemorySaveGuard` obtiene `$st = Get-RepoClassificationStatus`; si `status -ne 'ok'` -> mismo bloque `decision=block` y mensaje; si ok, bifurca sobre el `repo_type` ya validado (`harness|personal` -> `$null`; `cliente` -> evalúa contenido). La rama por tipo es política del guard, no validación. Sin relajar fail-closed.

## Pasos
### Paso 1: RED — tests del helper
- Qué: casos en `repo-classification.Tests.ps1`: ok (3 tipos), missing, corrupt (JSON roto), vacío -> invalid, solo espacios -> invalid, BOM+JSON válido -> ok (test que fija el comportamiento, sin cambio de código), tipo inválido, tipo faltante, no-string (número/objeto), "Cliente" -> invalid, `-RepoRoot` nulo. Confirmar que fallan por la razón correcta (excepto BOM, que ya pasa y solo fija comportamiento).
- Archivos: .claude/hooks/repo-classification.Tests.ps1
- Seguridad: temp dirs aislados.
- Despacho: INLINE (≤3 tool-calls; dependiente del diseño)

### Paso 2: GREEN — helper + refactor de session-start
- Archivos: repo-classification.ps1, session-start.ps1 (dot-source por $PSScriptRoot; si el archivo falta, degradar a `corrupt` sin romper el JSON)
- Seguridad: la salida de session-start no cambia de forma; session-start.Tests.ps1 queda verde; agregar test del caso archivo ausente.
- Despacho: INLINE

### Paso 3: Refactor de sensitive-data-guard sin relajar fail-closed
- Qué: usar el status; test de regresión explícito: cada estado != ok y el valor "clientee" siguen bloqueando; archivo vacío bloquea.
- Archivos: sensitive-data-guard.ps1, sensitive-data-guard.Tests.ps1
- Seguridad: comparar bloqueos antes/después con la suite existente completa; sin cambios al matcher de settings.json.
- Despacho: INLINE

### Paso 4: Revisión adversarial del fail-closed + suite completa
- Qué: revisor fresco busca algún estado donde el guard ahora deje pasar (p. ej. status ok con repo_type espurio); correr `run-all-tests.sh`.
- Despacho: DELEGAR (agente fresco, independencia del contexto vivo)

### Paso 5: PR vía open-pr.sh (Closes #379)
- Despacho: INLINE

## Boundaries
- Never: cambiar el contrato de `Get-RepoClassification` (lo usa gh-account-guard); relajar un bloqueo; comparar case-insensitive; agregar manejo de BOM.
- Ask First: (ninguno pendiente).

## Riesgos
- Dot-source fallido en un hook = fail-open si no se maneja; en session-start se degrada a `corrupt`; el guard ya depende del dot-source existente.

## Alternativas descartadas
- Solo `Test-RepoType` sin status: session-start seguiría duplicando la lógica missing/corrupt.
- Función `Test-RepoType` separada: una línea con `-cnotin` inline no justifica otra función ni otra superficie de API.
- Modificar `Get-RepoClassification` para devolver status: rompe a gh-account-guard.
- Leer la lista desde el JSON de configuración: sobreingeniería.
- Clasificar archivo vacío como `corrupt`: cambiaría el estado hoy reportado por session-start (`invalid`) sin beneficio.
- Recortar BOM con `TrimStart([char]0xFEFF)`: `Get-Content -Raw` ya lo descarta; código muerto.
