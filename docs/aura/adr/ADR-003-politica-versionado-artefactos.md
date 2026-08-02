---
adr: 003
title: Política de versionado de artefactos generados por el agente
date: 2026-08-01
status: accepted
area: harness
---

# ADR-003: Política de versionado de artefactos generados por el agente

## Problema

El harness no definía, de forma explícita y aplicable en todo proyecto que lo
inicializa, qué categorías de archivo/documento generado por el agente corresponden al
harness (deben versionarse) vs. cuáles son artefactos de sesión/análisis (no deberían
versionarse por defecto). La única señal existente era una regla puntual sobre "planes
aprobados" en `AGENTS.md`, ausente en otro repo (`memo-digital`) con el mismo harness
inicializado en paralelo — señal de que la decisión se tomó ad-hoc, no como política
general documentada. En un caso concreto (`crawler-mcp-diagram`), un plan versionado
terminó conteniendo datos de negocio reales del cliente (folios/OC extraídos de XML de
muestra), demostrando que "plan" y "dato sensible" no son categorías disjuntas y que la
regla de entonces no daba ninguna guía sobre esa intersección.

## Contexto

- Issue #38, detectado 2026-07-15 trabajando en `crawler-mcp-diagram` + `memo-digital`.
- Este mismo repo ya tiene `.claude/rules/sensitive-data-safety.md`, que define un barrido
  pre-commit/pre-push read-only para detectar datos corporativos del cliente en contenido
  versionado — pero no menciona explícitamente el ledger de planes (`.agent/memory/plans/`)
  como categoría de riesgo elevado, pese a ser el caso real que motivó ese incidente.
- `AGENTS.md` (rol "Objetivos" del harness) ya versiona: identidad/pilares/router,
  reglas universales, memoria (Engram + `current-session.json` + `project-log.md` +
  `objectives.md` + ledger de planes).
- `docs/aura/adr/` (Issue #33) ya establece el precedente de "residuo permanente vs.
  artefacto efímero" para specs/planes de diseño — esta decisión extiende el mismo
  criterio a memoria de sesión/proyecto.

## Decisión

Formalizar la siguiente tabla de categorías en `AGENTS.md`, como fuente de verdad única
que todo proyecto hereda al inicializar el harness:

| Categoría | Ejemplo | ¿Versionar? | Razón |
|---|---|---|---|
| Estructura del harness | `.aura/`, `AGENTS.md`, `protocols/`, `skills/`, `agents/`, `.claude/rules/` | Sí | Es el harness en sí — sin esto no hay proyecto |
| Identidad de sesión activa | `.agent/memory/current-session.json` | Sí | P5 (memoria distribuida); metadata de progreso, no debe contener dato de negocio real |
| Bitácora de proyecto | `.agent/memory/project-log.md`, `objectives.md` | Sí | P5; narrativa de decisiones del proyecto, sujeta al barrido de `sensitive-data-safety.md` |
| Ledger de planes aprobados | `.agent/memory/plans/*.md` | Sí, con barrido obligatorio | Trazabilidad de decisiones — pero es la categoría de mayor riesgo real de fuga (ver incidente); el plan debe anonimizar dato de negocio real (placeholders) igual que cualquier otro archivo versionado |
| Backups automáticos | `.agent/memory/backups/*.json` | No | Estado transitorio regenerable, sin valor histórico |
| Análisis/informes ad-hoc | hallazgos de debugging, reportes exploratorios de una sesión | No | Efímero — vive en `docs/aura/specs/` (gitignored) o solo en Engram |

Regla derivada aplicada: **no se crea una categoría nueva de exclusión para planes** —
en cambio, se refuerza `sensitive-data-safety.md` para que el barrido pre-commit
mencione explícitamente `.agent/memory/plans/*.md` como categoría de riesgo elevado
(mismo checklist ya existente, aplicado con más precisión al punto donde ya ocurrió el
incidente).

## Alternativas descartadas

- **Sacar el ledger de planes del versionado y dejarlo solo en Engram/memoria local** —
  descartada: pierde el valor de trazabilidad textual ("qué se aprobó, cuándo, por qué")
  que motivó crear el ledger en primer lugar (`AGENTS.md` → "Al aprobar un plan"); el
  problema real no es *que* se versione sino *qué contenido* termina en el archivo.
- **Versionar un resumen sin datos sensibles en vez del plan completo** — descartada por
  complejidad: requeriría un paso de "sanitización" automática no confiable; más simple y
  robusto es aplicar el barrido ya existente (revisión antes de commit) al momento de
  escribir el plan, igual que a cualquier otro archivo.
- **Política distinta por repo/proyecto** — descartada: es exactamente el problema que
  generó el issue (`crawler-mcp-diagram` y `memo-digital` divergieron sin decisión
  explícita). La política vive en el harness fuente (`AGENTS.md`) para que todo proyecto
  la herede igual.

## Consecuencias

- `AGENTS.md` gana una sección "Qué se Versiona" con la tabla de categorías — cambio al
  rol "Objetivos" del harness, documentado vía este ADR (cumple P4: hipótesis antes de
  cambiar el harness).
- `sensitive-data-safety.md` se actualiza para nombrar explícitamente
  `.agent/memory/plans/*.md` en el checklist de detección, cerrando el gap que causó el
  incidente real.
- Pendiente fuera de este ADR (no automatizable desde este repo): revisar retroactivamente
  si `memo-digital` y otros proyectos ya inicializados necesitan sincronizar esta política
  vía `/harness-update`.

## Archivos afectados

- `AGENTS.md` — nueva sección "Qué se Versiona"
- `.claude/rules/sensitive-data-safety.md` — checklist actualizado con mención explícita al ledger de planes
