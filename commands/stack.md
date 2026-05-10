# Comando — /stack

> **Propósito:** Seleccionar o cambiar el stack tecnológico de la sesión actual.
> **Cuándo usar:** Al inicio de sesión sin stack detectado, o mid-session para cambiar de stack.

---

## Uso

```
/stack
```

Sin argumentos. Activa el flujo de selección interactivo.

---

## Acción

Invocar `skills/stack-selection/SKILL.md` completo:

1. Detectar stack desde archivos del proyecto (si no se hizo antes)
2. Confirmar stack detectado o mostrar lista de 24 perfiles
3. Escribir `.agent/memory/session-stack.json`
4. Confirmar: "Stack de sesión actualizado: [nombre-perfil]"

---

## Resultado

El stack queda disponible en `.agent/memory/session-stack.json` para todos los agentes de la sesión.
