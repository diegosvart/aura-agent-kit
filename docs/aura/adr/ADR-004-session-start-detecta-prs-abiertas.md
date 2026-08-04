---
adr: 004
title: session_start.md consulta PRs abiertas contra GitHub, no solo estado local
date: 2026-08-04
status: accepted
area: harness
---

# ADR-004: session_start.md consulta PRs abiertas contra GitHub, no solo estado local

## Problema

`protocols/session_start.md` construía el resumen ejecutivo a partir de estado local
(`git status`, `git log`, `git branch --merged develop`) y de issues con label `ready`,
pero nunca consultaba `gh pr list --state open`. Una PR abierta esperando review/merge
quedaba invisible en el resumen, y el agente podía reportar "sin pendientes" cuando en
realidad había trabajo a un paso de cerrarse.

## Contexto

Detectado en vivo en la sesión del 2026-08-04 (Issue #109): al ejecutar el protocolo
completo se reportó "issues ready vacío / sin pendientes" mientras existían 2 PRs abiertas
(#108, #102) creadas horas antes. Solo se detectaron al pedir explícitamente `gh pr list
--state open` fuera del protocolo.

El mismo patrón de fondo —sugerir el próximo paso desde una foto local en vez de validar
contra el estado real en origin— se había observado también en un repo consumidor del
harness, donde `session_start` recomendó revisar/mergear una PR ya mergeada, y además dejó
sin detectar que el submódulo `.aura` estaba desactualizado frente a `origin/develop` del
harness. Ese segundo síntoma (staleness del submódulo `.aura`) queda fuera de alcance de
este ADR — es un gap relacionado pero distinto, candidato a issue separado.

## Decisión

- `protocols/session_start.md`, Paso 4, agrega una subsección obligatoria "PRs Abiertas"
  que ejecuta `gh pr list --repo {{OWNER}}/{{REPO}} --state open --json
  number,title,headRefName,baseRefName,mergeable` cuando `gh` está autenticado.
- El Resumen Ejecutivo (Paso 6) agrega la sección "PRs Abiertas" (tabla, o "✓ Sin PRs
  abiertas" explícito si la lista viene vacía — nunca se omite la sección).
- El fast-path del hook (Paso "Hook Fast-Path") ya no salta esta llamada junto con los
  Pasos 2-4: se agrega como excepción explícita, igual que el chequeo de visibilidad del
  repo. El hook `session-start.ps1` no trae este dato hoy.

## Alternativas descartadas

- **Agregar el chequeo al hook `session-start.ps1` en vez de al protocolo** — más rápido en
  ejecución (cacheable), pero requiere tocar PowerShell + re-firmar el hook y no resuelve el
  caso sin hook (ej. `/clear` manual). Se prefiere el paso explícito en el protocolo, que
  aplica en todos los caminos de entrada; migrarlo al hook queda abierto como optimización
  futura si el costo de la llamada extra se vuelve relevante.
- **Extender `repo-integrity` (Paso 3) para cubrir PRs abiertas** — `repo-integrity` está
  enfocado en detectar *stranded work* (issue cerrado sin PR mergeada), un caso distinto de
  "PR abierta con issue todavía abierto" (el caso normal). Mezclar ambos algoritmos en el
  mismo script hubiera complicado la clasificación sin necesidad; se mantiene como paso
  independiente.

## Consecuencias

- El resumen ejecutivo de `session_start` ahora refleja PRs abiertas de forma consistente,
  cerrando el falso negativo de "sin pendientes" detectado en la sesión que originó este ADR.
- Costo: 1 llamada `gh` adicional por sesión (o por invocación del fast-path), aceptable
  bajo el mismo criterio que ya justificaba la llamada de visibilidad del repo.
- No resuelve el gap de staleness del submódulo `.aura` frente a origin — queda pendiente
  como trabajo futuro si se confirma que aplica de forma general a proyectos consumidores.

## Archivos afectados

- `protocols/session_start.md` — nueva subsección "PRs Abiertas" en Paso 4, excepción en el
  fast-path, nueva sección en la plantilla del Resumen Ejecutivo (Paso 6).
