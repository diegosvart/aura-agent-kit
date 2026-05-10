# Skill — Spec Validation

> **Propósito:** Validar técnicamente que una spec es implementable antes de pasarla al challenger.
> **Cuándo usar:** Después de que el usuario aprueba el diseño en `/brainstorm`, antes de invocar el challenger agent.
> **HARD-GATE:** Score ≠ PASS → no se puede invocar `/write-plan`.

---

## Checklist de Validación

Evaluar cada ítem como ✓ (cumple) o ✗ (no cumple):

### Completitud
- [ ] **AC medibles**: Los criterios de aceptación son objetivos, no subjetivos ("el endpoint devuelve 200" ✓ vs "funciona bien" ✗)
- [ ] **Inputs/outputs definidos**: Se especifican los datos de entrada y salida esperados
- [ ] **Scope acotado**: No hay "y también..." o "además..." que indiquen features adicionales no planificadas

### Calidad
- [ ] **Edge cases**: Al menos un caso borde o de error está considerado
- [ ] **Ejemplos de uso**: Hay al menos un ejemplo concreto de cómo se usará
- [ ] **Sin duplicados**: No existe funcionalidad equivalente ya implementada en el proyecto

### Trazabilidad
- [ ] **Vinculada a un pilar o necesidad real**: La spec responde a un problema concreto, no a una suposición
- [ ] **Implementable en la rama actual**: No depende de features no mergeadas o recursos no disponibles

---

## Scoring

| Resultado | Condición | Acción |
|-----------|-----------|--------|
| **PASS** | Todos los ítems ✓ | Continuar con challenger agent |
| **NEEDS_REVISION** | 1-2 ítems ✗ en Calidad o Trazabilidad | Devolver spec con observaciones específicas. El usuario puede corregir sin volver a `/brainstorm`. |
| **BLOCKED** | Cualquier ítem ✗ en Completitud, o 3+ ítems ✗ en total | Volver a `/brainstorm`. La spec no tiene base suficiente para implementar. |

---

## Formato de Reporte

```markdown
## Spec Validation — <nombre-de-la-spec>

| Ítem | Estado | Observación |
|------|--------|-------------|
| AC medibles | ✓/✗ | <detalle si ✗> |
| Inputs/outputs | ✓/✗ | |
| Scope acotado | ✓/✗ | |
| Edge cases | ✓/✗ | |
| Ejemplos de uso | ✓/✗ | |
| Sin duplicados | ✓/✗ | |
| Vinculada a necesidad | ✓/✗ | |
| Implementable ahora | ✓/✗ | |

**Score: PASS / NEEDS_REVISION / BLOCKED**

> <Si no es PASS: qué debe corregirse y dónde en la spec>
```

---

## Reglas

1. **No reemplaza al challenger**: este skill valida completitud técnica; el challenger valida alineación con pilares y calidad estratégica
2. **Ser específico en observaciones**: indicar exactamente qué falta y en qué sección de la spec
3. **NEEDS_REVISION no es fracaso**: es feedback constructivo. El usuario corrige y resubmite sin reiniciar el proceso
4. **No evaluar si la idea es buena**: eso es rol del challenger. Este skill solo valida si la spec está bien escrita

---

## Integración en el Flujo

```
/brainstorm → usuario aprueba spec
    ↓
[spec-validation] ← estás aquí
    ↓ PASS
challenger agent
    ↓ GO
/write-plan
```
