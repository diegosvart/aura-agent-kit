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
5. **Escribir spec** — guardar en `docs/aura/specs/`
6. **Revisión usuario** — esperar aprobación
7. **Invocar writing-plans** — crear plan de implementación

## Restricciones

- **NO escribir código** hasta que el usuario apruebe el diseño
- **NO invocar skills de implementación** hasta tener spec aprobada
- El diseño puede ser breve (unas frases) para proyectos simples

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