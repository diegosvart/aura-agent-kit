# Routing Menu — Opciones según Contexto

## Cuándo mostrar el menú

Mostrar el menú de routing después de **cualquier** de estos eventos:
- Completar implementación de código (linter + tests pasan)
- Cerrar un issue
- Crear o mergear una PR
- Terminar una sesión de análisis o planificación
- Responder una pregunta técnica compleja
- Completar un brainstorming o spec

---

## Tabla de Opciones por Contexto

### Si acaba de completar código / issue

```
## ¿Qué sigue?
1. **Crear PR** — `/finish-branch` para preparar y abrir PR a develop
2. **Continuar con issue #N** — [título del próximo issue ready]
3. **Cerrar sesión** — guardar estado y terminar
4. **Solicitar review** — `/request-review` si la PR ya está abierta
```

### Si acaba de crear issues / planificar

```
## ¿Qué sigue?
1. **Arrancar con Issue #N** — [título del primer issue creado]
2. **Refinar el diseño** — `/brainstorm` para profundizar antes de codear
3. **Cerrar sesión** — guardar estado y terminar
```

### Si acaba de terminar una corrida de `/run-dev-loop`

```
## ¿Qué sigue?
1. **Ver reporte de consumo de esta corrida** — tokens/tool_uses/duration por issue,
   agregado desde `.agent/memory/observability/sessions.jsonl`
2. **Revisar issues en `review`** — Fase 2 (verifier) del loop
3. **Cerrar sesión** — guardar estado y terminar
```

### Si acaba de mergear una PR

```
## ¿Qué sigue?
1. **Cerrar Issue #N** — `gh issue close N --comment "Implementado en PR #X"`
2. **Continuar con Issue #N+1** — [título del próximo issue]
3. **Cerrar sesión** — guardar estado y terminar
4. **Limpiar ramas mergeadas** — `git branch --merged develop`
```

### Si hay issues ready y no hay trabajo en curso

```
## ¿Qué sigue?
1. **Issue #N** — [título] (label: ready)
2. **Planificar nuevo trabajo** — `/plan-work`
3. **Cerrar sesión** — guardar estado y terminar
```

### Si no hay issues ready ni trabajo en curso

```
## ¿Qué sigue?
1. **Planificar trabajo nuevo** — `/plan-work` para definir próximas tareas
2. **Revisar estado del proyecto** — `gh issue list --state open`
3. **Cerrar sesión** — guardar estado y terminar
```

---

## Reglas del Menú

1. **Siempre mínimo 3 opciones** — nunca menos
2. **Opción 1 = más relevante** según el estado actual del repo y la sesión
3. **Siempre incluir "Cerrar sesión"** como última opción
4. **Ser específico** — no "continuar con trabajo pendiente" sino "Issue #42: Agregar login OAuth"
5. **Si hay rama con commits sin PR** → opción 1 o 2 siempre es `/finish-branch`
6. **Si hay PR abierta sin reviewer** → incluir `/request-review`
