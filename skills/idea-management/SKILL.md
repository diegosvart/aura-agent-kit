---
name: idea-management
description: Captura, madura y promueve objetivos de alto nivel a través de un ciclo de vida estructurado. Usar cuando el usuario quiere registrar una idea, explorarla, o promoverla a planificación.
---

# Skill — Idea Management

> **Propósito:** Capturar, madurar y promover objetivos de alto nivel a través de un ciclo de vida estructurado.
> **Cuándo usar:** Cuando el usuario quiere registrar una idea, explorar un objetivo, o promoverlo a planificación.
> **Comando asociado:** `/idea`

---

## Ciclo de Vida de un Objetivo

```
raw ──(primera iteración)──▶ exploring ──(ángulos claros)──▶ refined ──(/idea promote)──▶ planned ──▶ done
```

---

## Modos de Operación

### Modo Capture — `/idea <texto>`

Trigger: el usuario escribe `/idea` seguido de texto.

1. Leer `.agent/memory/ideas.md`
2. Determinar el próximo ID (N+1 respecto al último `## [NNN]`)
3. Construir la entrada con el formato enriquecido:
   ```
   ## [NNN] <texto como título>
   **Estado:** raw
   **Capturado:** YYYY-MM-DD
   **Contexto:** (pendiente de exploración)

   ### Iteraciones
   _(sin iterar)_
   ```
4. Appendear al archivo
5. Responder en **una sola línea**: `Objetivo #NNN registrado: "[título]"`
6. No hacer preguntas. No interrumpir el flujo actual.

---

### Modo List — `/idea` (sin argumentos)

Trigger: el usuario escribe `/idea` solo.

1. Leer `.agent/memory/ideas.md`
2. Extraer todos los objetivos con sus IDs, títulos y estados
3. Presentar tabla compacta:
   ```
   | # | Objetivo | Estado |
   |---|----------|--------|
   | 001 | Verificar hooks PS1 en desktop | raw |
   | 002 | /auto-research desde session_end | raw |
   | ...
   ```
4. Preguntar: "¿Querés explorar alguno? Escribí `/idea <N>`"

---

### Modo Explore — `/idea <N>`

Trigger: el usuario especifica un número de objetivo.

**Declarar al inicio:** `Activando: idea-management [PM → Planner → Engineer]`

1. Cargar el objetivo N desde `.agent/memory/ideas.md`
2. Leer las iteraciones previas (historial)
3. Ejecutar las **3 perspectivas secuenciales**, una pregunta cada una:

**Perspectiva PM** (Product Manager):
- Enfocar en: ¿qué problema resuelve? ¿a quién beneficia? ¿cuál es el valor?
- Hacer UNA pregunta de clarificación de valor/usuario
- Esperar respuesta antes de continuar

**Perspectiva Planner**:
- Enfocar en: ¿qué componentes necesita? ¿qué dependencias existen? ¿cuánto esfuerzo?
- Presentar los componentes identificados como lista
- Hacer UNA pregunta de alcance o priorización
- Esperar respuesta

**Perspectiva Engineer**:
- Enfocar en: ¿qué existe hoy en el harness? ¿qué hay que construir? ¿qué herramientas?
- Identificar gaps entre lo existente y lo necesario
- Hacer UNA pregunta sobre restricciones técnicas o preferencias de implementación
- Esperar respuesta

4. Sintetizar las 3 perspectivas en **opciones claras para el usuario** (2-3 opciones con esfuerzo estimado)
5. Esperar decisión del usuario
6. Guardar el resumen de la iteración en `.agent/memory/ideas.md`:
   ```
   - [YYYY-MM-DD] <resumen de 1-2 líneas de lo descubierto/decidido>
   ```
7. Actualizar el estado: `raw → exploring` (primera iteración) o `exploring → refined` (ángulos claros)
8. Preguntar: "¿Lo promovemos a `/plan-work` o seguimos madurando en otra sesión?"

---

### Modo Promote — `/idea promote <N>`

Trigger: el usuario escribe `/idea promote N` o elige promover tras exploración.

**Precondición:** El objetivo debe tener al menos 1 iteración (estado ≠ raw). Si está en raw → informar y sugerir `/idea N` primero.

1. Cargar objetivo N completo (título, contexto, todas las iteraciones)
2. Construir brief para planificación:
   ```
   Objetivo: <título>
   Decisión: <lo que se concluyó en la última iteración>
   Componentes identificados: <lista del Planner>
   Restricciones: <lo del Engineer>
   ```
3. Actualizar estado a `planned` en ideas.md
4. Preguntar: "¿Tiene spec de diseño previa o vamos directo a `/plan-work`?"
   - Con spec → `/plan-work` directamente con el brief
   - Sin spec → recomendar `/brainstorm` primero, luego `/plan-work`

---

## Reglas

1. **Capture nunca toma más de 1 turno** — registrar y confirmar, nada más
2. **Explore: una perspectiva a la vez** — no presentar las 3 juntas
3. **Una pregunta por perspectiva** — no bombardear con preguntas
4. **No promover objetivos en estado `raw`** sin al menos 1 iteración
5. **Múltiples objetivos pueden estar activos** en distintos estados simultáneamente
6. **ideas.md siempre legible** por humanos sin herramientas ni parsers

---

## Integración en el Flujo

```
/idea <texto>     → ideas.md (capture)
/idea <N>         → exploración multi-perspectiva → ideas.md (iteración guardada)
/idea promote <N> → /brainstorm (si objetivo abierto) | /plan-work (si objetivo refinado)
/plan-work        → GitHub Issues con label ready
task_start        → ejecución
```
