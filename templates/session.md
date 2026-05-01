# Template — Sesión de Agente

> **Uso:** Este es el formato que el agente usa para resumir cada sesión.

---

## Header

| Campo | Valor |
|-------|-------|
| **Fecha** | {{FECHA_ISO}} |
| **Proyecto** | {{PROJECT_NAME}} |
| **Rama** | {{BRANCH}} |
| **Duración** | {{DURACIÓN}} (opcional) |

---

## Resumen Ejecutivo

### Estado Final
- **Linter:** ✓ / ✗
- **Tests:** ✓ / ✗
- **Cambios sin commit:** {{N}} archivos
- **Rama limpia:** Sí / No

### Trabajo Realizado

**Completado:**
- {{TAREA_1}}
- {{TAREA_2}}
- {{TAREA_3}}

**Pendiente (para próxima sesión):**
- {{PENDIENTE_1}}
- {{PENDIENTE_2}}

---

## Decisiones Tomadas

| # | Decisión | Contexto | Resultado |
|---|----------|----------|-----------|
| 1 | {{decisión}} | {{por qué}} | {{qué pasó}} |

---

## Archivos Clave

| Archivo | Cambio | Notas |
|---------|--------|-------|
| {{archivo}} | {{creado/modificado/borrado}} | {{notas}} |

---

## Issues Involucrados

| Issue | Estado | Acción |
|-------|--------|--------|
| #{{N}} | {{abierto/cerrado}} | {{qué se hizo}} |

---

## Siguiente Paso

**{{next_step}}**

Rama sugerida: `{{TIPO}}/{{CODIGO}}-{{descripcion}}`

---

## Notas Adicionales

- {{nota_1}}
- {{nota_2}}
- {{nota_3}}

---

*Generado automáticamente por el agente al cerrar sesión.*