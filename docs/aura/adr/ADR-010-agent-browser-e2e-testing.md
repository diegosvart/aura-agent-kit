---
adr: 010
title: Incorporar agent-browser como capability de testing E2E/headless
date: 2026-09-02
status: accepted
area: harness
---

# ADR-010: Incorporar agent-browser como capability de testing E2E/headless

## Problema

El harness no tiene ninguna capability de testing automatizado de UI/E2E. `agents/browser-control.md`
(vía `claude-in-chrome`) cubre "ver/controlar el navegador real del usuario" pero excluye
explícitamente testing E2E determinístico sin supervisión humana. El Pilar P3 (TDD) se
detiene en lint/unit tests por stack — no hay story para validar una app web construida
por el harness sin depender de que el usuario tenga un navegador interactivo abierto.

## Contexto

- Hipótesis P4 confirmada por el usuario (2026-09-01): "todo proyecto que permita
  validación web" necesita esta capability — es de aplicabilidad general, no un caso
  puntual de este repo. Ver `docs/aura/specs/2026-09-01-agent-browser-integration-design.md`
  (spec-validation PASS, challenger GO) para el rationale, arquitectura y tabla de riesgos
  completa.
- `vercel-labs/agent-browser`: CLI nativo Rust + daemon persistente sobre Chrome DevTools
  Protocol. Headless por defecto, refs deterministas (`@e1`, `@e2`) desde snapshots de
  accessibility tree, salida `--json`, modo `agent-browser mcp` opcional (descartado, ver
  Decisión). Licencia Apache-2.0.
- Precedente estructural: `agents/browser-control.md` (PR #159) se documentó sin ADR
  dedicado — patrón liviano aceptado para capabilities que reusan una dependencia ya
  presente (`claude-in-chrome`). Esta integración sí amerita ADR porque es la primera
  dependencia CLI externa del harness que no viene con el stack del proyecto consumidor:
  requiere instalación aparte (descarga de Chrome for Testing) y tiene su propio ciclo de
  vida (daemon con timeout de inactividad).
- Issue #168 (capability core: agent + skill + permisos/router + dogfooding) ya mergeado
  (PR #177) — validado con dogfooding real antes de este ADR, condición que la spec exigía
  explícitamente antes de documentar la decisión final.
- Depende de: #169.

## Decisión

Se incorpora `agent-browser` como capability `agents/browser-testing.md` +
`skills/e2e-testing/SKILL.md`, bajo dos condiciones que son parte de la decisión, no notas
aparte:

1. **Instalación-con-aprobación**: el agente puede detectar que `agent-browser` no está
   disponible y proponer instalarlo, pero **nunca** ejecuta el comando de instalación
   (`agent-browser install` o similar) sin una confirmación explícita del usuario en ese
   mismo turno — misma regla general del harness de no ejecutar acciones sin aprobación,
   aplicada aquí porque la instalación descarga un binario y Chrome for Testing.
2. **CLI-puro, nunca MCP**: toda invocación usa el CLI (`agent-browser open/snapshot/click/
   fill/get/screenshot/diff/wait`, con `--json` para parseo estructurado). El modo
   `agent-browser mcp` existe en la herramienta pero no se usa — Pilar P1 (CLI > MCP: si el
   CLI alcanza, no sumar una superficie MCP adicional).

**Daemon en `session_end.md`**: el harness **no** agrega ningún paso a `session_end.md` para
detener el daemon de `agent-browser` proactivamente. Se confía en su timeout de inactividad
propio (configurable, default 1h). Razón: `session_end.md` ya tiene un checklist obligatorio
(linter, tests, Engram, current-session.json) — agregar un paso más que dependa de una
dependencia externa opcional (no todos los proyectos consumidores la tienen instalada)
introduciría una rama condicional más en un protocolo que ya es largo, para un daemon que se
autolimpia solo. Si en la práctica se observa que el daemon queda huérfano con frecuencia
(caso análogo al de `check-orphaned-worktrees.sh`), se revisita con evidencia real — no se
resuelve preventivamente acá. Documentado como paso manual en "Errores comunes" de
`agents/browser-testing.md` (verificar/matar el daemon si hace falta).

Alcance v1 (ya acotado en la spec, no se reabre acá): E2E/smoke tests básicos (open/snapshot/
click/fill/get text/wait) + screenshots/regresión visual. Accessibility audits (axe-core) y
React introspection/Web Vitals quedan para v2.

Integración con `/run-dev-loop`: punto de extensión **opcional**, no obligatorio — después de
implementar un issue con impacto en UI, el dev-runner puede invocar
`skills/e2e-testing/SKILL.md` como smoke test antes de pasar el issue a `review`. No se
acopla `run-dev-loop` a esta dependencia externa en v1.

## Alternativas descartadas

- **Usar `agent-browser mcp`** — descartada por Pilar P1: el CLI puro ya cubre el alcance v1
  sin sumar una superficie MCP adicional que mantener.
- **Detener el daemon proactivamente en `session_end.md`** — descartada por ahora: sin
  evidencia real de que el timeout propio de la herramienta sea insuficiente, agregar el
  paso es complejidad anticipada (contradice la regla general del harness de no diseñar
  para requisitos hipotéticos).
- **Acoplar el smoke test como paso obligatorio de `/run-dev-loop`** — descartada: rompería
  el loop en cualquier proyecto consumidor sin `agent-browser` instalado.
- **Instalación automática sin confirmación** — descartada: regla general del harness
  ("nunca ejecutar sin aprobación"), agravada acá porque implica descargar un binario y
  Chrome for Testing desde la red.

## Consecuencias

- El harness gana su primera dependencia CLI externa no ligada al stack del proyecto
  consumidor — con ciclo de vida propio (instalación, daemon, timeout) distinto al de
  linters/test runners detectados por stack.
- `protocols/router.md` y `AGENTS.md` ganan una fila de routing distinguible de
  `browser-control.md` (ver tabla de decisión en la spec): "ver/guiar con sesión real del
  usuario" vs. "validar programáticamente sin supervisión, headless/aislado".
- `/run-dev-loop` puede tardar más en proyectos que sí tienen `agent-browser` instalado y
  activan el smoke test opcional — trade-off aceptado porque es opt-in, no default.
- Si `agent-browser` no está disponible en un proyecto consumidor, el harness lo informa
  explícitamente y sigue funcionando sin la capability — nunca falla en silencio ni asume
  que está disponible.

## Archivos afectados

- `docs/aura/adr/ADR-010-agent-browser-e2e-testing.md` — este archivo
- `agents/browser-testing.md` — ya existente (Issue #168 / PR #177)
- `skills/e2e-testing/SKILL.md` — ya existente (Issue #168 / PR #177)
- `skills/agentic-dev-loop/SKILL.md` — documenta el punto de extensión opcional (este PR)
- `docs/aura/adr/ADR-000-registro.md` — registro de este ADR
