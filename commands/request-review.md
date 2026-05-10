# Comando — /request-review

> **Invoca:** `skills/requesting-code-review/SKILL.md`
> **Cuándo usar:** Antes de crear una PR o cuando una PR ya está abierta y lista para revisión.

---

## Qué Hace

1. Ejecuta pre-review checklist (alineación con plan, calidad, docs, seguridad)
2. Genera formato de solicitud de review estructurado
3. Abre o actualiza la PR con el mensaje generado

---

## Cuándo Usar

- Después de `/finish-branch` cuando se elige crear PR
- Cuando una PR ya existe y querés solicitar review formalmente
- Antes de hacer merge a develop

---

## Proceso

```
Pre-review checklist:
    ├── ¿Código alineado con el plan/spec?
    ├── ¿Linter y tests pasan?
    ├── ¿Documentación actualizada?
    ├── ¿Sin secretos ni debug code?
    └── ¿Self-review hecho?
    ↓
Generar mensaje de review:
    - Resumen del cambio
    - Decisiones no obvias
    - Preguntas específicas para el reviewer
    ↓
gh pr create / gh pr edit con el mensaje
```

---

## Integración en el Flujo

Invocado por `session_end.md` cuando hay PR abierta sin reviewer asignado.
Puede invocarse manualmente tras `/finish-branch`.
