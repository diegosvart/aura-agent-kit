# Comando /idea — Gestión de Objetivos

## Sintaxis

| Forma | Acción |
|-------|--------|
| `/idea <texto>` | Captura rápida de nuevo objetivo (1 turno, no interrumpe) |
| `/idea` | Lista todos los objetivos con ID y estado |
| `/idea <N>` | Carga y explora el objetivo N (PM → Planner → Engineer) |
| `/idea promote <N>` | Promueve objetivo N a `/brainstorm` o `/plan-work` |

## Acción

Invocar `skills/idea-management/SKILL.md` con el modo correspondiente según la sintaxis usada.

## Ejemplos

```
/idea "poder definir un release para el harness"
→ Objetivo #004 registrado: "poder definir un release para el harness"

/idea
→ Lista de 4 objetivos con estado

/idea 4
→ Activando: idea-management [PM → Planner → Engineer]
→ Exploración iterativa con opciones para decidir

/idea promote 4
→ Brief construido → invoca /plan-work con contexto del objetivo
```
