---
status: done
pr: "#383"
commit: 2255084
completed_at: 2026-10-11
issue: 382
date: 2026-10-11
---


# Plan Issue #382 — Forzar validación del body de PR fuera de open-pr.sh

## Qué
Que ningún PR llegue a develop sin las 5 secciones (Qué, Beneficio, Por qué, Cómo, Testing), incluso si se crea o edita a mano. Un solo PR: arreglo del validador (headings en fences) + workflow de CI que lo ejecuta + documentación. Sin hook.

## Beneficio
El formato unificado deja de depender de que el agente recuerde usar `open-pr.sh`, y se cumple desde cualquier cliente (UI web, otra máquina, terminal propia).

## Por qué (hallazgos del código actual)
- `.github/` NO existe: no hay workflow hoy. GitHub Actions está habilitado (`allowed_actions: all`, verificado por el usuario).
- La protección de develop hoy no tiene status checks requeridos.
- Solo CI cubre todos los orígenes; un hook solo cubriría sesiones de Claude Code y sumaría superficie (tokenizador, registro, suite Pester).
- Validador `validate-pr-body.sh`: `grep -Eq "^## Sección\$"` cuenta headings dentro de bloques ``` / ~~~ como reales; con archivo inexistente reporta 5 faltantes sin mensaje claro.

## Cómo
1. **Validador** (`lib/validate-pr-body.sh`): preprocesar con awk que alterna estado en líneas que empiezan con 3+ backticks o 3+ tildes (hasta 3 espacios de indentación, cierre con el mismo carácter y longitud >=), emite solo líneas fuera de fence; luego el grep actual. Verificar que el archivo exista: si no, salida != 0 con mensaje propio. Sensible a mayúsculas como hoy.
2. **Workflow** `.github/workflows/pr-body.yml` en `pull_request` (opened, edited, synchronize, reopened): escribe `github.event.pull_request.body` a un archivo desde `env` (nunca interpolar `${{ }}` en el script) y llama al mismo `validate-pr-body.sh`. Exime explícitamente PRs de release con base `main` (`cut-release.sh promote`, head develop).
3. **Protección** (Ask First, lo ejecuta el USUARIO): tras mergear el workflow, marcar el check como required en `apply-branch-protection.sh` y aplicarlo. Es configuración compartida; el agente no la ejecuta.
4. **Docs**: actualizar "Límite conocido" en `agents/github.md` (enforcement real vía CI).

## Pasos
### Paso 1: RED — tests nuevos del validador
- Qué: en `validate-pr-body.Tests.sh`: heading solo dentro de fence ``` -> falta; solo dentro de fence ~~~ -> falta; fence sin cerrar (lo posterior se ignora, fail-closed); tildes (`## Por qué` correcto vs `## Por que` -> falta); mayúsculas (`## QUÉ`, `## qué` -> falta); body vacío -> faltan las 5; archivo inexistente -> salida != 0 con mensaje claro; CRLF; heading con espacios finales; `###` no cuenta; 5 válidos + uno extra dentro de fence -> OK. Confirmar que fallan por la razón correcta.
- Archivos: validate-pr-body.Tests.sh
- Despacho: INLINE

### Paso 2: GREEN — validador (awk de fences + chequeo de archivo)
- Archivos: lib/validate-pr-body.sh
- Despacho: INLINE

### Paso 3: Workflow `pr-body.yml`
- Qué: crear el workflow según Cómo-2, con exención de PRs de release con base main. Revisión del YAML por el reviewer.
- Archivos: .github/workflows/pr-body.yml
- Seguridad: body solo vía `env`; permisos mínimos (`contents: read`).
- Despacho: DELEGAR (revisión a reviewer; escritura INLINE)

### Paso 4: Docs
- Qué: actualizar "Límite conocido" en `agents/github.md`.
- Archivos: agents/github.md
- Despacho: INLINE

### Paso 5: Validación de no-regresión
- Qué: `gh pr list --state merged --base develop --limit 40 --json number,body`; pasar cada body por el validador. Los PRs posteriores a #381 deben pasar todos (si alguno falla = bug del validador); los anteriores se esperan rechazados (formato previo), por eso el check NO es retroactivo. Correr `run-all-tests.sh`.
- Archivos: ninguno
- Despacho: DELEGAR (salida voluminosa, autocontenido)

### Paso 6: PR vía open-pr.sh (Closes #382)
- Despacho: INLINE

### Paso 7 (Ask First, lo ejecuta el USUARIO tras mergear): marcar el check como required
- Qué: editar `apply-branch-protection.sh` para incluir el check `pr-body` como status check requerido y ejecutarlo. Verificar antes que el check ya corrió en al menos un PR.
- Despacho: INLINE (acción del usuario; el agente solo asiste, no ejecuta)

## Boundaries
- Never: interpolar el body en `run:` del workflow; hacer el check retroactivo; bloquear `cut-release.sh promote`; ejecutar el agente cambios de branch protection; validar el footer de atribución.
- Ask First: marcar el check como required (Paso 7, lo hace el usuario).

## Decisiones ya tomadas por el usuario
- El footer de atribución NO se valida (prevalece la regla del repo "Sin atribución de IA").
- NO se cubre `gh api .../pulls` (residual declarado en docs).

## Riesgos
- Falsos positivos que frenen PRs (mitigado por Paso 5 y mensaje accionable).
- Marcar required antes de que el workflow exista/corra deja PRs bloqueados (mitigado: Paso 7 posterior al merge).
- PRs de release (base main) sin exención explícita fallarían.

## Alternativas descartadas
- Hook `pr-body-guard.ps1` (con su registro en settings.json y suite Pester) más revisión adversarial: solo cubre sesiones de Claude Code, depende del tokenizador fail-closed, agrega superficie de mantenimiento y no cubre UI web; el CI cubre todo con menos código.
- Solo hook: no cubre UI web ni otros clientes.
- Validar el footer de atribución: contradice la regla del repo "Sin atribución de IA".
- Cubrir `gh api .../pulls`: requiere interceptar un vector que CI ya cubre sin interceptar nada.
- Check retroactivo sobre PRs previos: los anteriores a #381 usan el formato previo y fallarían.
- Validar en un wrapper/alias de `gh`: fuera del control del repo.
