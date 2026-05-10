# Comando — /finish-branch

> **Invoca:** `skills/finishing-a-development-branch/SKILL.md`
> **Cuándo usar:** Cuando la rama tiene trabajo listo para crear una PR o cerrar.

---

## Qué Hace

1. Ejecuta pre-checks obligatorios (tests, linter, sin debug code, commits limpios)
2. Verifica que la rama está actualizada con develop
3. Presenta opciones al usuario
4. Ejecuta la acción elegida

---

## Cuándo Usar

- Cuando terminaste el trabajo de un issue y está listo para review
- Cuando session_end detecta commits sin PR
- Antes de solicitar code review

---

## Proceso

```
Pre-checks
    ├── Tests: todos verdes
    ├── Linter: 0 errores
    ├── Sin console.log / print debug
    ├── Commits convencionales
    └── Rama actualizada con develop
    ↓
Presentar opciones:
    A) Crear PR → base: develop
    B) Solo push (PR manual después)
    C) Squash commits y push
    D) Descartar rama (confirmar)
    ↓
Ejecutar opción elegida
```

---

## Integración en el Flujo

Invocado por `session_end.md` cuando detecta commits en rama sin PR abierta.
También puede invocarse manualmente en cualquier momento.
