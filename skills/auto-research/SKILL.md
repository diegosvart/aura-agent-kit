# Skill — Auto-Research (Evolución del Harness)

> **Propósito:** Formalizar la disciplina de mejora continua del harness con hipótesis documentadas antes de cualquier cambio.
> **Cuándo usar:** Cuando se detecta fricción, patrón repetitivo, o ineficiencia en el flujo de trabajo.
> **Principio:** Sin hipótesis escrita → no se modifica ningún protocolo, skill o agente.

---

## Cuándo Activar

El agente debe considerar `/auto-research` cuando observa:

| Señal | Ejemplo |
|-------|---------|
| **Fricción repetida** | El mismo paso manual ocurre en 3+ sesiones |
| **Workaround recurrente** | Se evita un protocolo porque "no aplica bien aquí" |
| **Pregunta repetida** | El usuario hace la misma aclaración en sesiones distintas |
| **Paso olvidado** | Se detecta que un paso del protocolo se saltea sistemáticamente |
| **Inconsistencia** | Dos skills o protocolos se contradicen |

**Regla:** El agente propone activar auto-research, no lo ejecuta solo. El usuario aprueba.

---

## Proceso

### Paso 1 — Observar y documentar la fricción
Describir en una oración qué ocurre y en qué parte del flujo.

### Paso 2 — Formular hipótesis
Completar: *"Si modifico [archivo/sección], espero [resultado] porque [razonamiento]."*

Ejemplo: *"Si agrego un recordatorio de `spec-validation` al inicio de `task_start.md`, espero que se salte menos el paso de validación porque hoy no hay ningún trigger visual."*

### Paso 3 — Definir criterio de éxito
¿Cómo sabremos que el cambio mejoró la situación? El criterio debe ser observable en las próximas 1-3 sesiones.

Ejemplo: *"En la próxima sesión con feature nueva, spec-validation se ejecuta sin que el usuario lo recuerde."*

### Paso 4 — Identificar el cambio mínimo
¿Cuál es la modificación más pequeña que puede probar la hipótesis? Evitar cambios amplios que mezclen múltiples hipótesis.

### Paso 5 — Ejecutar y registrar
1. Crear entrada en `docs/aura/experiments/YYYY-MM-DD-<topic>.md` (usar template)
2. Ejecutar el cambio mínimo
3. Registrar resultado en la próxima sesión relevante

### Paso 6 — Concluir
- **Mejoró** → mantener cambio, marcar experimento como exitoso
- **No mejoró** → revertir cambio, registrar aprendizaje, marcar como fallido
- **Resultado ambiguo** → extender observación 1-2 sesiones más

---

## Límites

- **Máximo 2 experimentos activos en simultáneo** — más de eso diluye la atribución de resultados
- **Un experimento = una hipótesis** — no mezclar cambios en el mismo experimento
- **No modificar pilares** (`docs/aura/specs/2026-05-09-harness-pillars.md`) como parte de un experimento — los pilares requieren nueva spec aprobada
- **No modificar este skill** durante un experimento activo

---

## Qué NO es Auto-Research

- No es refactorizar el harness por estética
- No es agregar features nuevas al harness (eso va por `/brainstorm` + spec + challenger)
- No es el ciclo commit/reset de AutoResearch clásico (ese requiere función objetivo ejecutable)
- No es obligatorio en cada sesión — solo cuando hay señales concretas

---

## Integración en el Flujo

```
Session End
    ↓
¿Fricción detectada esta sesión?
    ├── No → cerrar normalmente
    └── Sí → proponer /auto-research al usuario
                ↓ (si aprueba)
            formular hipótesis
                ↓
            crear experimento en docs/aura/experiments/
                ↓
            ejecutar cambio mínimo
                ↓
            observar en próximas sesiones
```
