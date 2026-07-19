# Skill — Issue Planning

> **Propósito:** Refinar el requerimiento del usuario y convertirlo en uno o varios issues de GitHub listos para trabajar.
> **Cuándo usar:** Cuando el usuario describe trabajo nuevo al inicio de sesión o en cualquier momento que quiera planificar.
> **Comando asociado:** `/plan-work`

---

## Cuándo Activar

- El usuario dice "quiero hacer X", "necesito Y", "pensé en Z"
- session_start detecta que no hay issues con label `ready`
- El usuario responde "algo nuevo" al Paso 7 de session_start
- El usuario quiere planificar un sprint o conjunto de tareas

---

## Proceso

### Paso 1 — Escuchar
El usuario describe lo que quiere hacer. No interrumpir ni asumir.

### Paso 2 — Refinar (una pregunta a la vez)
Hacer preguntas de clarificación hasta tener:
- **Qué** se va a construir/cambiar (descripción concreta)
- **Por qué** es necesario (motivación)
- **Cómo sabremos que está listo** (criterios de aceptación medibles)
- **Dependencias** (¿hay algo que debe existir primero?)
- **Scope** (¿esto es una cosa o varias?)

**Regla:** Una pregunta por turno. No hacer interrogatorio.

### Paso 3 — Detectar atomicidad
¿El requerimiento es una sola tarea o se puede dividir en issues independientes?

**Señales de que hay múltiples issues:**
- "y también...", "además...", "y de paso..."
- El requerimiento tiene partes que pueden entregarse por separado
- Hay backend Y frontend Y tests como piezas distintas

**Regla de atomicidad:** Un issue = una unidad entregable que agrega valor por sí sola.

### Paso 4 — Proponer lista de issues
Presentar al usuario la lista propuesta antes de crear:

```markdown
## Issues propuestos para: <descripción general>

### Issue 1: <título>
- **Qué:** <descripción una oración>
- **AC:** <criterio 1>, <criterio 2>
- **Depende de:** nada / Issue N

### Issue 2: <título>
- **Qué:** <descripción una oración>
- **AC:** <criterio 1>, <criterio 2>
- **Depende de:** Issue 1

**Orden de trabajo sugerido:** Issue 1 → Issue 2 → ...

¿Aprobás esta lista o querés ajustar algo?
```

### Paso 5 — Crear issues en GitHub (tras aprobación)
Para cada issue aprobado, además de `ready` agregar `bug` si el issue describe un defecto o
corrección de algo que ya existe, o `enhancement` si es trabajo nuevo. Esta señal la usa
`pick-next-issue.sh` (skill `agentic-dev-loop`) para priorizar fixes sobre features al elegir
el próximo issue a tomar — sin ella, un fix queda en la cola por orden de número como cualquier
otro issue.

```bash
gh issue create \
  --repo <OWNER>/<REPO> \
  --title "<título>" \
  --body "<descripción>\n\n## Criterios de Aceptación\n- [ ] <AC1>\n- [ ] <AC2>" \
  --label "ready,bug"          # o "ready,enhancement" si es trabajo nuevo
```

### Paso 6 — Presentar resumen
```
## Issues creados

| # | Título | Label |
|---|--------|-------|
| #N | <título> | ready |
| #N+1 | <título> | ready |

**Orden sugerido:** #N → #N+1
**¿Arrancamos con el Issue #N?**
```

### Paso 7 — Derivar a Ejecución

Después de presentar el resumen y obtener confirmación del usuario:

- **"Sí, arrancamos"** → Invocar `protocols/task_start.md` con Issue #N (el primero de la lista)
- **"No, lo dejamos para después"** → Cerrar el skill. Los issues quedan con label `ready` para la próxima sesión.
- **"Quiero arrancar con otro"** → Invocar `protocols/task_start.md` con el issue que el usuario indique.

---

## Reglas

1. **No crear issues sin aprobación** — siempre mostrar la lista primero
2. **Máximo una pregunta por turno** — no bombardear al usuario
3. **Un issue = una unidad entregable** — no mezclar concerns
4. **Siempre label `ready`** — para que session_start los detecte. Sumar `bug` o `enhancement`
   según corresponda — es la señal que usa `agentic-dev-loop` para priorizar fixes sobre
   features
5. **Ordenar por dependencias** — no proponer orden arbitrario
6. **Si hay más de 5 issues** — preguntar si prefiere trabajarlos en batches

---

## Integración en el Flujo

```
session_start Paso 7: "¿algo nuevo?"
    ↓
/plan-work → issue-planning skill
    ↓
refinamiento iterativo
    ↓
lista aprobada
    ↓
gh issue create (×N)
    ↓
task_start con Issue #N (el primero)
```
