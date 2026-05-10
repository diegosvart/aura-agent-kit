# Comando — /plan-work

> **Invoca:** `skills/issue-planning/SKILL.md`
> **Cuándo usar:** Cuando el usuario describe trabajo nuevo y quiere convertirlo en issues de GitHub listos para trabajar.

---

## Qué Hace

1. Inicia un proceso de refinamiento del requerimiento (una pregunta por vez)
2. Detecta si el trabajo es uno o varios issues
3. Propone lista de issues con criterios de aceptación
4. Tras aprobación del usuario → crea los issues en GitHub con label `ready`
5. Presenta resumen y sugiere orden de trabajo

---

## Cuándo Usar

- Al inicio de sesión cuando el usuario dice "quiero hacer algo nuevo"
- Cuando session_start no encuentra issues con label `ready`
- Cuando el usuario describe múltiples tareas de una vez
- Antes de comenzar cualquier trabajo no planificado

---

## Proceso

```
Usuario describe trabajo
    ↓
Agente refina (preguntas una a la vez)
    ↓
Agente propone lista de issues
    ↓
Usuario aprueba / ajusta
    ↓
gh issue create (×N con label ready)
    ↓
Resumen + sugerencia de orden
    ↓
task_start con el primer issue
```

---

## Ejemplo

```
Usuario: "Quiero agregar un módulo de reportes y también mejorar el login"

Agente: /plan-work

"Dos áreas distintas. Empecemos por reportes.
¿Qué tipo de reportes necesitás — PDF, Excel, ambos?"

[...refinamiento...]

## Issues propuestos

### Issue 1: Implementar exportación de reportes a PDF
- AC: El usuario puede descargar reporte en PDF desde la UI
- AC: El PDF incluye header con logo y fecha

### Issue 2: Mejorar flujo de login con 2FA opcional
- AC: El usuario puede activar 2FA desde su perfil
- Depende de: ninguno

¿Aprobás esta lista?"
```
