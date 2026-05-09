# Comando — /auto-research

> **Invoca:** `skills/auto-research/SKILL.md`
> **Cuándo usar:** Cuando se detecta fricción, patrón repetitivo o ineficiencia en el flujo del harness.

---

## Qué Hace

Inicia el proceso de mejora continua del harness:
1. Documenta la fricción observada
2. Formula una hipótesis de mejora
3. Define criterio de éxito observable
4. Crea entrada en `docs/aura/experiments/`
5. Ejecuta el cambio mínimo necesario

---

## Cuándo Usar

- Al cierre de sesión si se detectó fricción (el agente lo sugiere automáticamente)
- Cuando el usuario nota que un paso se repite manualmente con frecuencia
- Cuando un protocolo se saltea sistemáticamente
- Cuando dos partes del harness se contradicen

---

## Proceso

```
Usuario o agente identifica fricción
    ↓
Agente formula hipótesis ("Si X, espero Y porque Z")
    ↓
Usuario aprueba la hipótesis
    ↓
Agente crea docs/aura/experiments/YYYY-MM-DD-<topic>.md
    ↓
Agente ejecuta cambio mínimo en el archivo objetivo
    ↓
Agente registra en Engram: qué cambió, hipótesis, criterio de éxito
    ↓
En próxima sesión relevante: evaluar resultado → mantener o revertir
```

---

## Restricciones

- Requiere aprobación explícita del usuario antes de modificar cualquier archivo
- Máximo 2 experimentos activos en simultáneo
- No modifica `docs/aura/specs/2026-05-09-harness-pillars.md` (requiere nueva spec)
- No modifica `docs/aura/specs/2026-05-09-harness-pillars.md` ni `agents/challenger.md` (son la vara de medición)

---

## Ejemplo

```
Usuario: "Noto que siempre me olvidás de ejecutar spec-validation"

Agente: "Detecté fricción en P2 (Diseño antes de código).
Hipótesis: Si agrego un recordatorio explícito en task_start.md al inicio
de tareas con feature, spec-validation se ejecutará sin que debas recordarlo.
Criterio de éxito: en la próxima sesión con feature nueva, el paso ocurre automáticamente.
¿Aprobás este experimento?"

Usuario: "Sí"

Agente: [crea experiment log] [modifica task_start.md] [guarda en Engram]
```
