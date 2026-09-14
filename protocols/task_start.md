# Protocolo — Task Start

> **Cuándo:** Al comenzar a trabajar en una tarea/issue específica.
> **Obligatorio:** Sí (para tareas nuevas o continuidad).

---

## Caso 1: Nueva Tarea (sin Issue existente)

Si el usuario pide hacer algo nuevo sin Issue:

1. **Crear Issue primero** — el Issue es la vida del proyecto
2. **Definir título claro** — qué se va a hacer
3. **Agregar labels** — `ready`, `agent:*` si aplica
4. **Crear rama** — `skills/agentic-dev-loop/scripts/new-branch-for-issue.sh <owner>/<repo> N feature descripcion` (desde `develop`; ver `agents/github.md` para los otros tipos: `fix`, `chore`, `hotfix`)

```
Usuario: "Quiero agregar autenticación"
Agente: "Creo el Issue #N: Agregar autenticación
         Rama: feature/issue-N-agregar-autenticacion
         ¿Confirmas?"
```

---

## Caso 2: Reanudar Tarea (rama existente con trabajo)

Si hay trabajo sin commit o rama abierta:

1. **Levantamiento inicial:**
   ```
   Rama: {{rama_actual}}
   Cambios sin commit: N archivos
   ¿Esto tiene sentido con el Issue #N y la rama?
   ```

2. **Verificar:**
   - ¿El trabajo corresponde al Issue?
   - ¿La rama está actualizada con develop?
   - ¿Tiene sentido continuar o es mejor reiniciar?

3. **Decidir:**
   - Continuar la rama (reanudar)
   - Crear nueva rama (si el trabajo no corresponde)

---

## Caso 3: Continuar desde checkpoint

Si hay `current-session.json` con `next_step`:

```
Último paso: {{next_step}}
Pendiente: {{pending}}

¿Continuamos con esto?
```

---

## Flujo General: Plan → Aprobación → Ejecución

### Paso 1: Plan

El agente presenta el plan con análisis de seguridad, puntos de vista y despacho:

```
## Plan para Issue #N: {{título}}

### Paso 1: {{acción 1}}
- Qué: {{descripción}}
- Archivos: {{archivos afectados}}
- Seguridad: {{punto de vista}}
- Despacho: DELEGAR (fork|subagente — motivo) | INLINE (motivo)

### Paso 2: {{acción 2}}
- Qué: {{descripción}}
- Archivos: {{archivos afectados}}
- Seguridad: {{punto de vista}}
- Despacho: DELEGAR (fork|subagente — motivo) | INLINE (motivo)

...
```

**Campo Despacho (Issue #268 — mecanismo operativo de `.aura/rules/subagent-dispatch.md`):**
obligatorio en cada `### Paso N`, nunca se omite aunque la decisión sea obvia — un paso
trivial se declara igual `INLINE (trivial, ver criterio de subagent-dispatch.md)`. Aplica el
mismo criterio de dos condiciones que ya define `subagent-dispatch.md` (trigger aplicable +
independencia del contexto vivo de la conversación), pero como declaración escrita y auditable
en el momento de armar el plan — antes de gastar contexto, no después vía `delegation_rate`.
Preferir `fork` sobre agente fresco cuando el paso es investigación/exploración que no necesita
analizarse una segunda vez.

**Manejo de falla/reintento de un paso `DELEGAR`:** si la delegación falla (el subagente se
equivoca de scope, entrega algo que no responde lo pedido, o falla la invocación), reintentar
ese paso **una sola vez** con un prompt más específico (mismo criterio de "prompts contienen
file paths y líneas concretas" que ya exige toda delegación bien hecha). Si el reintento
también falla, ejecutar el paso inline y dejarlo registrado como tal:
`INLINE (fallback tras 1 reintento fallido de DELEGAR)`. Nunca reintentar más de una vez en
silencio — ni indefinidamente (ciclo costoso) ni abandonar la subtarea sin completarla.

### Paso 2: Aprobación

El usuario aprueba:
- Todo junto (más rápido)
- Paso a paso (más control)

### Paso 3: Ejecución

El agente ejecuta según aprobación.

---

## Definición de Done (DoD)

Cada Issue debe tener criterios medibles:

### DoD Genérico
- [ ] Linter pasa (0 errores)
- [ ] Tests pasan (todos verdes)
- [ ] Branch no es develop/main
- [ ] Commit con mensaje convencional

### DoD por Tipo de Cambio

| Tipo | Criterios adicionales |
|------|----------------------|
| Feature | Tests de la feature, docs actualizados |
| Fix | Tests que demuestren el fix |
| Refactor | Tests pasan, sin regresión |
| Infra | CI/CD actualizado, secrets seguros |

---

## Contexto para el Agente

Al iniciar una tarea, el agente debe recibir:

1. **El Issue** — qué hacer, por qué
2. **La rama** — desde dónde trabajar
3. **Contexto del proyecto** — archivos clave a leer
4. **Stack** — tecnología, linter, test runner
5. **DoD** — qué significa "terminado"

---

## Detección de Technology Stack

El agente detecta automáticamente:

```bash
# Python
if [ -f "pyproject.toml" ]; then
    STACK="python"
    LINTER="ruff"
    TEST="pytest"

# Node.js
elif [ -f "package.json" ]; then
    STACK="node"
    LINTER="eslint"
    TEST="npm test"

# Rust
elif [ -f "Cargo.toml" ]; then
    STACK="rust"
    LINTER="clippy"
    TEST="cargo test"
fi
```

---

## Reglas

1. **Issue primero** — siempre crear el Issue antes de codear
2. **Rama desde develop** — nunca desde main
3. **Plan antes de ejecutar** — siempre presentar plan
4. **DoD claro** — saber qué es "terminado"

---

## Errores Comunes

| Error | Solución |
|-------|----------|
| Usuario pide "hacer algo" sin Issue | Crear Issue primero |
| Rama no existe | Crear desde develop |
| Rama desactualizada | Rebase o merge de develop |
| Sin DoD claro | Definir con el usuario |

---

## Output

Al iniciar tarea, presentar:
- Issue y rama
- Plan propuesto
- DoD
- "¿Confirmas el plan?"