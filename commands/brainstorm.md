# Comando — /brainstorm

> **Qué hace:** Inicia el proceso de diseño colaborativo antes de cualquier trabajo creativo.

## Uso

```
/brainstorm
```

## Cuándo Usar

- Cuando el usuario propone una nueva feature
- Antes de crear cualquier componente
- Antes de modificar comportamiento existente
- Siempre antes de escribir código (HARD-GATE)

## Proceso

1. **Explorar contexto** — revisar proyecto actual
2. **Hacer preguntas** — una a la vez, entender propósito
3. **Proponer enfoques** — 2-3 opciones con trade-offs
4. **Presentar diseño** — por partes, obtener aprobación
5. **Escribir spec** — guardar en `docs/aura/specs/YYYY-MM-DD-<topic>.md`
6. **Revisión usuario** — esperar aprobación de la spec
7. **Spec Validation** — ejecutar `skills/spec-validation/SKILL.md` (HARD-GATE: debe ser PASS)
8. **Challenger review** — invocar `agents/challenger.md` contra los pilares del harness
9. **GO del usuario** — confirmación explícita tras el reporte del challenger
10. **Invocar writing-plans** — crear plan de implementación

## Restricciones

- **NO escribir código** hasta que el usuario apruebe el diseño
- **NO invocar `/write-plan`** sin haber pasado spec-validation (PASS) y challenger (GO)
- El diseño puede ser breve (unas frases) para proyectos simples, pero spec-validation aplica siempre
- Si challenger emite `[CRÍTICO]` → volver al paso 2, no continuar

## Ejemplo

```
Usuario: "Quiero agregar autenticación JWT"

Agente: /brainstorm

Entiendo. Vamos a diseñar esto juntos.

[Explora proyecto]
[Hace preguntas una a la vez]
[Propone enfoques]
[Presenta diseño por partes]
[Usuario aprueba]
[Escribe spec]
[Invoca writing-plans]
```

## Nota

Este comando invoca el skill `aura:brainstorming`