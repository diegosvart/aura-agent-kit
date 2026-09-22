# Design Flow — Brainstorm antes de Planificar

## Regla principal (Fix C1)

Cuando el usuario describe **trabajo nuevo** (feature, componente, integración, cambio de comportamiento):

**Preguntar siempre:**
> "¿Tenés un diseño o spec previa para esto?"

- **Sí** → Continuar directamente con `/plan-work` (issue-planning)
- **No** → Recomendar:
  > "Recomiendo empezar con `/brainstorm` para definir el diseño antes de crear issues. Así evitamos rework.
  > ¿Querés hacer el brainstorm ahora o preferís ir directo al planning?"

Si el usuario elige ir directo → respetar su decisión y continuar con `/plan-work`.

---

## Regla — Desplegar toda spec nueva para revisión (Issue #336, sesión 2026-09-21)

> **Hipótesis P4:** el usuario revisa specs más rápido y con menos fricción si el archivo se
> abre automáticamente en su editor en vez de tener que ir a buscarlo manualmente después de
> que el agente avisa que lo creó. Criterio observable: en las próximas specs generadas, el
> usuario no tiene que pedir "abrime el archivo" — ya lo tiene abierto cuando termina de leer
> la respuesta del agente.

Cada vez que el agente **crea o termina de editar** un archivo en `docs/aura/specs/` (spec
nueva o revisión sustancial de una existente), antes de darla por lista para aprobación:

1. Verificar si el comando `code` (VS Code CLI) está disponible: `where code` (Windows) /
   `command -v code` (POSIX).
2. **Si está disponible:** `code "<path-de-la-spec>"` — la abre en una pestaña del editor del
   usuario, sin bloquear la sesión de Claude Code.
3. **Si no está disponible:** mostrar el contenido completo del archivo en la respuesta del
   chat (no solo un resumen) — el usuario necesita poder revisarlo igual, sin depender de
   abrir el archivo manualmente en otra herramienta.
4. Nunca asumir en silencio cuál de las dos rutas aplica — el chequeo del paso 1 es obligatorio,
   no una suposición basada en el sistema operativo.

Aplica solo a `docs/aura/specs/*.md` — no a plans (`.agent/memory/plans/`), issues, ni PRs, que
ya tienen su propio canal de revisión (GitHub UI).

---

## Flujo completo de diseño (cuando se sigue el proceso)

```
Usuario describe trabajo nuevo
        │
        ▼
¿Existe spec en docs/aura/specs/?
   Sí → /plan-work (issue-planning)
   No  ↓
        ▼
/brainstorm
  → Preguntas de clarificación (una por turno)
  → 2-3 enfoques con trade-offs
  → Design doc en docs/aura/specs/YYYY-MM-DD-<topic>-design.md
  → Usuario aprueba spec
        │
        ▼
/spec-validation (si la spec es compleja)
  → Score: PASS / NEEDS_REVISION / BLOCKED
  → PASS: continuar
  → NEEDS_REVISION: iterar sin reiniciar brainstorm
  → BLOCKED: volver a /brainstorm
        │
        ▼
challenger agent (si involucra cambios de arquitectura)
  → Review contra los 7 pilares
  → Veredicto: GO / NO-GO
        │
        ▼
/plan-work (issue-planning)
  → Crear issues con label ready
  → Proponer orden de trabajo
        │
        ▼
task_start con Issue #N
```

---

## Cuándo NO es necesario el flujo completo

- Bugfixes menores (un archivo, comportamiento claro): ir directo a `task_start`
- Chores (actualizar dependencias, renombrar, formatear): ir directo a `task_start`
- Hotfixes urgentes: ir directo a `task_start` con DoD reducido (linter ✓, tests ✓)

---

## Señales de que se necesita diseño previo

- La descripción incluye "y también...", "además...", "y de paso..."
- Involucra más de 2 archivos nuevos
- Afecta la arquitectura o el modelo de datos
- El usuario no sabe exactamente qué campos/endpoints/componentes necesita
- Es una integración con sistema externo
