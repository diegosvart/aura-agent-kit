---
name: session-trace
description: Genera una traza cualitativa del comportamiento real de una sesión (no del flujo diseñado en router.md, sino de lo que efectivamente pasó) como diagrama Archify autoreado por el agente. Usar al cerrar sesión, cuando hubo fricción, decisiones no obvias, o desvíos del protocolo que valga la pena poder revisar visualmente después.
---

# Skill — Session Trace (Auto-Aprendizaje de Aura, Fase 0)

> **Propósito:** Formalizar, como capability documentada, el ejercicio manual hecho por primera
> vez el 2026-09-05: trazar el comportamiento real de una sesión en formato Archify para poder
> revisarlo visualmente y detectar fricciones del harness que no son obvias solo leyendo Engram.
> **Spec de origen:** `docs/aura/specs/2026-09-05-proceso-auto-aprendizaje-aura.md`
> **Fase del plan:** Fase 0 de 4 (`.agent/memory/plans/2026-09-05-aura-auto-aprendizaje-trace-evaluator.md`)

---

## Qué es y qué NO es

- **Es** un JSON IR de Archify (`diagram_type: sequence` para el flujo turno a turno de una
  sesión, o `lifecycle` si el foco es el estado de una tarea/issue a través del tiempo)
  **autoreado por el propio agente** al cierre de sesión, con IDs estables y wording de dominio
  propio de esa sesión.
- **NO es** un parser automático ni determinístico del transcript. Archify exige "fresh
  authorship, new stable IDs, domain wording" por diseño (ver `SKILL.md` de Archify, sección
  "Fast authoring path") — un generador que mapeara mecánicamente cada mensaje del transcript a
  un nodo produciría un diagrama sobrecargado e ilegible. Evidencia directa: el primer intento
  real (2026-09-05, 47 mensajes) con `viewBox` por defecto falló validación `showcase` dos
  veces antes de resumir el flujo a los puntos de decisión reales y ajustar `viewBox`/labels a
  mano.
- **NO reemplaza** `mem_session_summary` (Engram) ni `current-session.json` — esos documentan
  *qué* se decidió y *qué* falta. La traza documenta *cómo* pasó, con la secuencia real de
  pasos, desvíos y decisiones — útil para que un evaluador retrospectivo (Fase 1, futura) o el
  propio usuario detecten un patrón que el resumen textual no muestra.

## Cuándo generarla

Paso **opcional, fail-open** ofrecido en `protocols/session_end.md` (ver Paso 10.5) — nunca
obligatorio ni bloqueante. Vale la pena proponerla cuando la sesión tuvo:

- Una fricción real del harness (protocolo saltado, guardrail no documentado, bug encontrado).
- Una decisión de diseño no obvia que se resolvió después de varios intentos.
- Un desvío notable entre el flujo esperado (`protocols/router.md`) y lo que efectivamente pasó.

Si la sesión fue lineal y sin sorpresas, no vale la pena el costo de atención de autorear la
traza — mismo criterio que `auto-research`: "no es obligatorio en cada sesión, solo cuando hay
señales concretas".

## Dependencia de Archify (opcional, bajo demanda)

Archify se instala globalmente, **nunca vendorizado** dentro de `aura-agent-kit` (P6 — el
harness fuente sigue siendo bash-scripts + markdown):

```bash
npx skills add tt-a1i/archify -g
```

Queda disponible en `~/.claude/skills/archify` y `~/.agents/skills/archify`. Si el comando
`node ~/.claude/skills/archify/bin/archify.mjs --help` falla, informar explícitamente al
usuario y ofrecer el comando de instalación — nunca instalar sin aprobación explícita en el
mismo turno (mismo criterio que `skills/e2e-testing/SKILL.md` con `agent-browser`).

## Proceso

### Paso 1 — Decidir si vale la pena

Aplicar el criterio de "Cuándo generarla" arriba. Si el usuario rechaza o no hay señal clara,
saltear sin bloquear el cierre de sesión.

### Paso 2 — Autorear el JSON IR

- Elegir `sequence` (turnos de la sesión, actores: usuario/agente/herramientas) o `lifecycle`
  (estado de una tarea/issue específico a través de la sesión), según qué eje cuenta mejor la
  fricción detectada.
- Resumir a los **puntos de decisión reales**, no cada mensaje — el eje es la fricción y sus
  causas, no una transcripción completa. Referencia de escala: la traza de 2026-09-05 resumió
  ~47 mensajes reales a un flujo de secuencia legible tras el primer ajuste.
- Guardar el candidato en:
  ```
  .agent/memory/observability/traces/<fecha>-<slug>.sequence.json
  ```
  (o `.lifecycle.json` según el tipo elegido). Este directorio ya está cubierto por
  `.gitignore` (`.agent/memory/observability/`) — no requiere entrada nueva.

### Paso 3 — Validar

```bash
node ~/.claude/skills/archify/bin/archify.mjs validate sequence <candidate.json> --quality showcase --json
```

Gotchas reales encontrados el 2026-09-05, verificar antes de asumir que un fallo es un bug de
Archify:

- El rango vertical `y` de cada mensaje está limitado por la altura del `viewBox` (el margen de
  encabezado/pie varía según el diagrama — el propio error de `validate` indica el rango exacto
  permitido, ej. "keep y between 160 and 477"; ajustar el `viewBox` o los valores de `y` en
  consecuencia, no asumir un margen fijo).
- El ancho de labels/sublabels está limitado por el ancho de la caja del participante, salvo
  que se use `column_fit: "spread"` — un sublabel largo con `column_fit` por defecto puede
  proyectarse ilegible a resoluciones de escritorio (falla "desktop-readability").

Una validación `showcase` pasa solo con los 9 checks en verde, 0 errores, 0 warnings — un
receipt con solo 4 checks es validación básica, no aceptación showcase (ver `SKILL.md` de
Archify).

### Paso 4 — Entregar el HTML

Solo después de que Paso 3 pase limpio:

```bash
node ~/.claude/skills/archify/bin/archify.mjs deliver sequence <candidate.json> <output.html> --quality showcase --json
```

Guardar `<output.html>` junto al JSON, mismo directorio y convención de nombre
(`.agent/memory/observability/traces/<fecha>-<slug>.sequence.html`). Un `deliver` con exit code
distinto de cero nunca se describe como éxito — corregir y reintentar antes de ofrecer el
archivo al usuario.

### Paso 5 — Ofrecer al usuario

Informar la ruta local del HTML generado (no se versiona, no se publica como Artifact salvo
pedido explícito — es telemetría de comportamiento de sesión, ver
`AGENTS.md` → "Qué se Versiona").

---

## Qué NO hacer

- No generar la traza como parser automático del transcript completo — viola el contrato de
  autoría fresca de Archify y produce diagramas ilegibles.
- No vendorizar Archify dentro de `aura-agent-kit` — instalación global bajo demanda únicamente.
- No versionar el JSON/HTML de la traza — vive en `.agent/memory/observability/`, ya gitignored.
- No bloquear el cierre de sesión si el usuario rechaza generar la traza (fail-open).
- No confundir esta skill con el rol evaluador retrospectivo (Fase 1, `agents/evaluator.md`,
  futuro) — esta skill solo produce el insumo cualitativo; evaluarlo es una capability distinta.

---

## Integración con `protocols/session_end.md`

Ver Paso 10.5 de `session_end.md`: se ofrece **después** del Paso 10 (Auto-Research) y antes de
cerrar — mismo patrón fail-open, una sola pregunta, nunca bloqueante.
