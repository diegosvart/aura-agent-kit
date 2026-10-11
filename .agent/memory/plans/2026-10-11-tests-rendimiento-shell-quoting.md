---
status: done
pr: "#384"
commit: 0fe025e
completed_at: 2026-10-11
issue: 378
date: 2026-10-11
---

# Plan Issue #378 — Tests de rendimiento de shell-quoting-review estables bajo carga

## Qué
Reemplazar los límites absolutos (4 s / 6 s) de `.claude/hooks/shell-quoting-review.Tests.ps1` (Describe "Rendimiento de los guards...", líneas ~61-82) por: (a) para el account guard, una medición de escalado relativo `t(2N)/t(N) < 3.0`; (b) para el pr-base guard, solo un techo absoluto holgado.

## Beneficio
La suite deja de dar falsos rojos bajo carga; el gate sigue detectando la regresión cuadrática que motivó el test en el guard donde la medición es confiable.

## Por qué (evidencia medida)
3 corridas con la máquina cargada: caso 600 líneas = 7.24 / 7.79 / 7.32 s (límite 4 s: falla siempre en este entorno); caso 1500 segmentos = 5.84 / 6.35 / 5.67 s (límite 6 s: en el borde). Un límite absoluto no distingue "máquina lenta" de "algoritmo cuadrático"; el cociente sí, porque la carga multiplica ambos tiempos por igual. Mediciones: el ratio del account guard en código sano es ~2.0 (estable); el del pr-base guard es ruidoso (tiempos de ~0.3 s, llegó a 4.2 en código sano), por lo que NO sirve como aserción.

## Cómo
- Helper `Measure-Scaling { param($Build, $N) }`: construye el comando con N y 2N, mide cada uno (mejor de 2 corridas) y devuelve `t(2N)/t(N)`. Una llamada de warm-up previa.
- Account guard, caso líneas: un único tamaño base, 600 -> 1200 líneas; aserción ratio < 3.0 (lineal ~2.0; cuadrático ~4.0).
- Caso `&&`: un solo N fijo con techo absoluto (3000 segmentos cuesta ~6 s extra si se duplica; se evita el escalado aquí). Unificar o bajar el caso a ese único N.
- pr-base guard: solo techo absoluto de cordura (30 s), sin ratio.
- Techo absoluto de 30 s en todos los casos (atrapa cuelgues/ReDoS).
- Se conservan los Mock de Get-ExpectedGhAccount/Get-ActiveGhAccount/Get-OriginRepoSlug.

## Pasos
### Paso 1: RED — demostrar que el test nuevo detecta la regresión
- Qué: escribir el test relativo del account guard y los techos; en una COPIA temporal de `shell-quoting.ps1` reintroducir `StringBuilder.Append(string,int,int)` y confirmar que el test FALLA (ratio >= 3); con el código sano confirmar GREEN (3 corridas para verificar ratio ~2.0).
- Archivos: shell-quoting-review.Tests.ps1 (la copia temporal NO se commitea; verificar `git diff` limpio sobre shell-quoting.ps1)
- Seguridad: ningún cambio a shell-quoting.ps1 en el commit final.
- Despacho: INLINE (≤3 tool-calls de edición, depende de las mediciones recién tomadas)

### Paso 2: Verificación bajo carga (criterio del issue)
- Qué: 5 corridas seguidas de `bash skills/agentic-dev-loop/scripts/run-all-tests.sh` con carga concurrente artificial (2 instancias paralelas); 0 fallos de rendimiento.
- Archivos: ninguno
- Seguridad: solo ejecución de tests.
- Despacho: DELEGAR (salida voluminosa, tarea autocontenida; fork)

### Paso 3: PR vía open-pr.sh (rama `fix/issue-378-...`, Closes #378)
- Despacho: INLINE

## Boundaries
- Never: relajar los tests funcionales; tocar `shell-quoting.ps1` en el commit; subir límites absolutos sin base relativa donde el ratio es confiable; usar `Start-Sleep`/reintentos que oculten fallos.
- Ask First: si el ratio sano del account guard resulta inestable (>2.5) y hace falta cambiar la forma de medir (p. ej. conteo de operaciones).

## Riesgos
- Ratio ruidoso con tiempos pequeños (mitigado: mejor de 2, ratio solo donde es estable, tamaño base 600).
- GC/JIT inflan la primera corrida (mitigado: warm-up).
- El pr-base guard queda sin detector fino de regresión cuadrática; lo cubre el techo de 30 s y el ratio del account guard, que comparte el tokenizador.

## Alternativas descartadas
- Margen 3x absoluto: pasa hoy pero casi iguala el tiempo de la regresión cuadrática; sensibilidad perdida.
- Línea base con microbenchmark ajeno (bucle de CPU fijo): mide otra cosa y agrega su propio ruido.
- Quitar los tests / excluirlos por tag: el gate deja de cubrir la regresión.
- Autocalibración de N (duplicar N si t(N) < 0.2 s, antiguos pasos 4-6): agrega complejidad y tiempo de suite; un tamaño base fijo medido alcanza.
- Ratio también en el pr-base guard: su ratio es ruidoso con tiempos de ~0.3 s (llegó a 4.2 en código sano); daría falsos rojos.
- Ratio en el caso `&&` (N y 2N): duplicar a 3000 segmentos cuesta ~6 s extra por corrida; un N fijo con techo es suficiente.
