# Comando — /execute-plan

> **Qué hace:** Ejecuta un plan de implementación tarea por tarea.

## Uso

```
/execute-plan [plan-file]
/execute-plan --current
```

## Cuándo Usar

- Después de crear un plan con /write-plan
- Cuando el usuario quiere implementar el plan

## Opciones de Ejecución

### 1. Paso a Paso (recomendado)
El agente ejecuta una tarea, presenta resultados, espera confirmación antes de continuar.

### 2. Por Lotes
Ejecuta múltiples tareas, presenta resultados en grupo, permite checkpoints.

## Proceso

Para cada tarea:
1. **Ejecutar pasos** — según el plan (test → fail → code → pass → commit)
2. **Verificar** — linter + tests pasan
3. **Presentar** — qué se hizo, qué sigue
4. **Esperar** — confirmación para continuar

## Tareas TDD

Cada tarea sigue el ciclo:
- [ ] Write failing test
- [ ] Run test → FAIL
- [ ] Write minimal code
- [ ] Run test → PASS
- [ ] Commit

## Si Algo Falla

1. **Test no falla como esperado** → Corregir test
2. **Test falla por código** → Corregir código
3. **3+ intentos fallidos** → Questionar arquitectura, discutir con usuario

## Comandos de Verificación

```bash
# Python
ruff check . && pytest tests/ -v

# Node.js
npm run lint && npm test
```

## Fin del Plan

Cuando todas las tareas completan:
- Presentar resumen
- Ofrecer opciones: PR, push, crear nuevo plan, etc.

## Nota

Este comando invoca el skill `aura:writing-plans` para ejecución