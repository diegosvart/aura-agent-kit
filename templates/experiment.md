# Template — Experimento de Auto-Research

> **Uso:** Registrar cada experimento de mejora al harness. Un archivo por experimento.
> **Ruta:** `docs/aura/experiments/YYYY-MM-DD-<topic>.md`

---

## Header

| Campo | Valor |
|-------|-------|
| **Fecha** | {{YYYY-MM-DD}} |
| **Estado** | `activo` / `exitoso` / `fallido` / `ambiguo` |
| **Archivo objetivo** | {{ruta/al/archivo.md}} |
| **Pilar relacionado** | P{{N}} — {{nombre del pilar}} |

---

## Fricción Observada

{{Descripción concreta de qué ocurre y en qué parte del flujo. Una o dos oraciones.}}

*Ejemplo: "En 3 sesiones consecutivas, spec-validation fue omitida porque task_start.md no tiene ningún trigger visual para recordarla."*

---

## Hipótesis

> "Si **{{cambio propuesto}}**, espero **{{resultado esperado}}** porque **{{razonamiento}}**."

*Ejemplo: "Si agrego un recordatorio de spec-validation al inicio de task_start.md en tareas de tipo feature, espero que el paso se ejecute automáticamente porque el agente lo verá en el protocolo antes de comenzar."*

---

## Cambio Mínimo

{{Describir exactamente qué líneas o secciones se modificarán. Ser específico.}}

---

## Criterio de Éxito

{{¿Cómo sabremos que el cambio funcionó? Debe ser observable en las próximas 1-3 sesiones.}}

*Ejemplo: "En la próxima sesión con feature nueva, spec-validation se ejecuta sin que el usuario lo recuerde."*

---

## Resultado

> Completar en la sesión donde se puede evaluar el resultado.

**¿Se cumplió el criterio de éxito?** Sí / No / Parcialmente

**Observaciones:**
{{Qué ocurrió exactamente. Ser honesto aunque el resultado sea negativo.}}

---

## Decisión

- [ ] **Mantener** — el cambio mejora el flujo, se integra permanentemente
- [ ] **Revertir** — el cambio no mejoró o empeoró algo; se deshace
- [ ] **Extender observación** — resultado ambiguo, evaluar en 1-2 sesiones más

---

## Aprendizaje

{{¿Qué aprendimos de este experimento que sea útil para futuros experimentos o para entender el harness mejor?}}

---

*Experimento registrado por el agente. Revisión manual del usuario recomendada antes de marcar como exitoso.*
