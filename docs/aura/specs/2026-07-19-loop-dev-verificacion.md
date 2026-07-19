# Spec — Loop de Desarrollo + Verificación de Issues

> **Propósito:** Hipótesis del harness (P4) que justifica agregar el skill `agentic-dev-loop`.
> **Versión del harness:** 1.2.0 (propuesta)
> **Fecha:** 2026-07-19

---

## Problema

Operar issues `ready` uno por uno a mano (elegir, implementar, verificar, mergear) no escala
cuando hay una cadena larga de issues bien atomizados (ej. 10 issues secuenciales en
`memo-digital`). El cuello de botella no es la dificultad de cada issue individual — varios ya
quedan lo bastante detallados (objetivo, archivos, tareas RED→GREEN, DoD) como para que un
agente los ejecute sin exploración adicional — sino la **atención humana** requerida para
lanzar cada paso.

## Objetivo

Agregar un skill que separe el trabajo en dos roles independientes y los deje disparables tanto
a demanda como en un loop recurrente:

1. **Desarrollo** — un agente toma un issue `ready` sin dependencias abiertas, lo implementa
   completo, y deja un PR abierto.
2. **Verificación** — un agente distinto audita ese PR contra el DoD del issue (código real, no
   el resumen del PR) y **recomienda** mergear o señala qué falta. Nunca mergea solo.

## Decisiones de Diseño

### D1 — Dos roles, dos niveles de autonomía
El rol de desarrollo puede pushear y abrir PR sin supervisión (issue bien especificado = bajo
riesgo de trabajo perdido, se puede descartar la rama). El rol de verificación **nunca mergea
por su cuenta** — mergear a `develop` es una acción de alto impacto que requiere confirmación
humana explícita, incluso si el veredicto es positivo.

### D2 — Vocabulario de labels transversal
Reutiliza `ready` (ya usado por `issue-planning`/`session_start`) y agrega `in-progress`,
`review`, `changes-requested`. Un issue nunca tiene más de uno de estos labels de flujo a la
vez — ver tabla de clasificación en el skill.

### D3 — Tiering de modelo, no un solo modelo fijo
No todos los issues pesan igual. Default a un modelo económico (Haiku) para issues atómicos
(RED→GREEN explícito, archivos listados); escalar automáticamente a un modelo más capaz
(Sonnet) si el primer intento falla o reporta bloqueo, y permitir que `issue-planning` marque
de entrada un issue como complejo para saltar directo al modelo más capaz. Evita gastar
reintentos baratos en algo genuinamente ambiguo, y evita pagar de más en algo trivial.

### D4 — Genérico, no atado a un repo/stack
El skill usa `<OWNER>/<REPO>` como placeholder y resuelve comandos de lint/typecheck/test vía
`.agent/memory/session-stack.json` (P6), igual que el resto de los skills del harness. La
primera instancia real es `memo-digital`, pero el skill no debe asumir Python/pytest.

### D5 — Un solo issue "in-progress" a la vez
Evita que dos corridas concurrentes (manual + cron, o dos ciclos de cron superpuestos) tomen
issues de una misma cadena de dependencias en paralelo y pisen el orden.

## Cómo se mide si funciona

- Issues avanzan de `ready` → `review` sin que el usuario tenga que lanzar cada paso a mano.
- El agente de verificación encuentra discrepancias reales cuando existen (mismo estándar que
  el review manual del PR #37 en `memo-digital`: leer el diff real, no el resumen).
- Ningún merge a `develop` ocurre sin confirmación explícita del usuario.

## Criterios de Aceptación

- [ ] `skills/agentic-dev-loop/SKILL.md` documenta labels, Fase 1 (dev-runner), Fase 2
      (verifier), política de tiering, y regla de concurrencia.
- [ ] `commands/run-dev-loop.md` permite disparar una pasada manual.
- [ ] `protocols/router.md` y `AGENTS.md` referencian el skill nuevo.
- [ ] El skill no asume un stack ni un repo específico.

---

*Spec propuesta: 2026-07-19 | Primera instancia de uso: `memo-digital` (issues #27–36)*
