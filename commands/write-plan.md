# Comando — /write-plan

> **Qué hace:** Crea un plan de implementación detallado a partir de una spec aprobada.

## Uso

```
/write-plan
```

## Cuándo Usar

- Después de que el usuario apruebe un diseño/spec
- Antes de cualquier implementación
- Cuando hay múltiples tareas a realizar

## Proceso

1. **Leer spec** — del archivo en `docs/aura/specs/`
2. **Mapear archivos** — qué se crea/modifica
3. **Descomponer tareas** — cada task = 2-5 min de trabajo
4. **Escribir plan** — con pasos exactos y código
5. **Self-review** — verificar cobertura y consistencia
6. **Presentar al usuario** — ofrecer opciones de ejecución

## Estructura del Plan

```markdown
# [Feature] Implementation Plan

**Goal:** [One sentence]

**Architecture:** [2-3 sentences]

---

### Task 1: [Component]

- [ ] Step 1: Write failing test
- [ ] Step 2: Verify it fails
- [ ] Step 3: Write minimal code
- [ ] Step 4: Verify passes
- [ ] Step 5: Commit
```

## Reglas

- **Sin placeholders** — cada paso debe tener código real
- **Rutas exactas** — siempre mostrar archivos completos
- **DRY, YAGNI, TDD** — seguir principios
- **Commits frecuentes** — cada tarea pequeña = commit

## Output

Guardar plan en `docs/aura/plans/YYYY-MM-DD-<feature>.md`

## Ejemplo

```
Agente: Plan completo y guardado en docs/aura/plans/2026-05-01-jwt-auth.md

Dos opciones:
1. Ejecutar ahora — implemento las tareas en esta sesión
2. Guardar para después — ejecutar más tarde

¿Cuál preferís?
```

## Nota

Este comando invoca el skill `aura:writing-plans`