# Repo Integrity — Regla de Comportamiento

## Qué es Trabajo Stranded

Una rama está en estado **STRANDED** cuando se cumplen las cuatro condiciones simultáneamente:

1. Tiene commits ahead de `develop` (rama no mergeada)
2. Uno o más commits referencian issues con `Closes #N`, `Fixes #N`, o `Resolves #N`
3. El issue referenciado está **CERRADO** en GitHub
4. No existe PR mergeada hacia `develop` con esa rama como head

## Regla de Bloqueo

Cuando `skills/repo-integrity/SKILL.md` detecta trabajo stranded durante `session_start`:

- **NO mostrar** el Resumen Ejecutivo (Paso 6) antes de resolver
- **NO presentar** el Capability Menu (Paso 8) antes de resolver
- **MOSTRAR** el bloque de alerta definido en la skill
- **ESPERAR** decisión del usuario
- Si elige opción 4 (ignorar): registrar en sección "Advertencias" del Paso 6 y continuar

## Cuándo Ejecutar el Chequeo

- Siempre en Paso 3 de `session_start.md`, después de los checks de salud de ramas
- Solo si `gh` está autenticado (verificado en Paso 2)
- Solo ramas locales con commits exclusivos respecto a `develop`
- Máximo 10 ramas candidatas

## Por Qué Esta Regla Existe

Un issue cerrado + código sin llegar a `develop` es un **falso positivo de completitud**. El proyecto parece avanzado pero el trabajo está perdido. Esto es peor que un issue abierto: genera confianza falsa en el estado del repositorio y puede llevar a trabajo duplicado o a perder features completas.

## No Ejecutar Si

- `gh auth status` falla (no autenticado) — omitir silenciosamente, no fallar
- La rama actual del trabajo activo — no chequearla contra sí misma
- Ramas de `main` o `develop` — nunca son candidatas
