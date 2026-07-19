# Spec — Optimización de Costo del Loop `agentic-dev-loop`

> **Propósito:** Hipótesis del harness (P4) que justifica reemplazar pasos de orquestación
> escritos en prosa por scripts determinísticos, y acotar el volumen de output crudo que reciben
> los agentes del loop.
> **Versión del harness:** 1.3.0 (propuesta)
> **Fecha:** 2026-07-19

---

## Problema

La primera corrida real del loop (Issue #27 en `memo-digital`) gastó **148.447 tokens y 111
tool-calls combinados** entre el dev-runner (Haiku) y el verifier. Auditando
`skills/agentic-dev-loop/SKILL.md` contra ese resultado aparecen dos causas distintas de
sobregasto:

1. **Orquestación redundante**: pasos como "elegir el issue `ready` de menor número sin
   dependencias abiertas" o "resolver el tier de modelo" están escritos como instrucciones en
   lenguaje natural para que un agente las razone — pero son 100% lógica determinística sobre
   output de `gh`. Cada vez que el loop tiquea (potencialmente cada corrida de cron), esto se
   paga de nuevo con tokens de razonamiento que no aportan nada que un script no pueda decidir
   igual de bien y más rápido.
2. **Output crudo en el contexto del agente**: cada corrida de lint/typecheck/test vuelca su
   salida completa al contexto del dev-runner/verifier, que después tiene que leerla para saber
   si siguió o no. Esto se repite varias veces por issue (una por cada iteración RED→GREEN), y
   es el patrón de sobregasto #1 documentado en herramientas de agentes de código (ver fuentes
   de la investigación de mercado en el plan aprobado de esta sesión).

## Objetivo

Reducir el costo por issue del loop sin cambiar su contrato (`ready`→`in-progress`→`review`,
dos fases, tiering de modelo, ningún merge sin confirmación humana), reemplazando prosa
determinística por scripts y acotando el output que llega al contexto de los agentes.

## Decisiones de Diseño

### D6 — Scripts de orquestación en vez de prosa (extensión de P1)
`skills/agentic-dev-loop/scripts/` contiene `pick-next-issue.sh`, `resolve-tier.sh`,
`close-cycle.sh`, `find-review-candidates.sh`, `find-pr-for-issue.sh`. Cada uno reemplaza un
paso del skill que antes describía la lógica para que un agente la ejecutara paso a paso. Solo
usan `bash`+`gh` (sin `jq` externo, para no asumir que está instalado — se usa el motor jq
embebido de `gh --jq`). El orquestador ejecuta el script y usa su salida directa.

### D7 — Wrapper de verificación con salida resumida
`scripts/verify.sh` resuelve lint/typecheck/test desde `.agent/memory/session-stack.json` y
devuelve un resumen corto (`OK <check> — <resumen>` o `FAIL <check>` + el fragmento de error
relevante). El dev-runner y el verifier lo usan en vez de correr los comandos sueltos e
interpretar su output completo.

### D8 — Bootstrap de stack una sola vez por repo (Paso 0)
Detectar y guardar `session-stack.json` es una detección manual de una sola vez; todas las
corridas siguientes del loop en ese repo lo reutilizan gratis.

### D9 — Registro de consumo en Engram (Paso 5.5)
Cada corrida guarda tokens/tool-calls del dev-runner y del verifier en Engram, para poder
trendear el costo por issue a medida que se corre sobre la cadena completa y decidir con datos
si el loop es económicamente viable — no con una sensación cualitativa.

## Hallazgo colateral (documentado en el skill, no requiere nueva decisión de diseño)

Validando `pick-next-issue.sh` contra `memo-digital` se descubrió que el repo tiene *default
branch* `main` pero el loop mergea PRs a `develop` — por lo que `Closes #N` nunca autocierra el
issue al mergear, y una dependencia "resuelta" puede aparecer como `OPEN` indefinidamente. El
script ya compensa esto buscando un PR *mergeado* además del estado del issue (ver tabla de
Errores Comunes del skill). Esto no es una decisión de diseño nueva, es una corrección de un bug
real encontrado al validar D6, documentado para que ningún script/skill futuro repita el
supuesto incorrecto de que "issue closed" es la única señal válida.

## Cómo se mide si funciona

- El próximo issue corrido con estos cambios (#28) muestra una reducción medible en tool-calls
  del dev-runner frente al baseline de #27 (86.559 tokens / 91 calls), sin que
  ruff/mypy/pytest dejen de estar en verde.
- La serie de consumo en Engram (D9) queda disponible para comparar issue a issue.

## Criterios de Aceptación

- [ ] `skills/agentic-dev-loop/scripts/` existe con los 6 scripts, ejecutables, probados contra
      un repo real (`memo-digital`).
- [ ] `skills/agentic-dev-loop/SKILL.md` referencia los scripts en vez de describir la lógica en
      prosa para los pasos que reemplazan.
- [ ] El skill documenta el hallazgo del default branch / `Closes #N` en su tabla de Errores
      Comunes.
- [ ] Ningún script depende de `jq` externo (solo `gh --jq` o `python3` para JSON local).

---

*Spec propuesta: 2026-07-19 | Validada contra: `memo-digital` (baseline Issue #27, próxima
corrida Issue #28)*
