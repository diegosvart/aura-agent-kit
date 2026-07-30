---
name: harness-update
description: Detect and apply updates to the harness submodule
---

# Skill — Actualización del Harness (detección y aplicación)

> **Propósito:** Detectar actualizaciones disponibles del harness (`aura-agent-kit`) y
> aplicarlas de forma controlada (nunca automático, solo a pedido explícito del usuario).
> **Comando asociado:** `/harness-update`
> **Spec / hipótesis:** `docs/aura/specs/2026-07-30-harness-self-update.md` (P4)
> **Precondición:** `.aura/` debe existir como un checkout git (git submodule) del harness.
> Si no existe, el skill avisa pero no falla.

---

## Vocabu lario de Versiones

El harness se versiona con **semantic versioning** (vX.Y.Z) y **tags de git**. Cada merge a `main`
en `aura-agent-kit` genera un tag + entrada en `CHANGELOG.md`. Estos tags son la fuente de verdad
para detectar actualizaciones.

---

## Qué Hace

1. **Detección** (hook `SessionStart`, automático, cero costo)
   - El hook `session-start.ps1` ejecuta `check-update.sh` en background (con TTL de cache)
   - Injeta `harness_update_available` y `harness_latest_version` en el JSON de contexto
   - Si no hay actualizaciones o no hay `.aura/`, estos campos simplemente no aparecen

2. **Aviso** (en el Resumen Ejecutivo de `session_start.md`, Paso 6)
   - Una sola línea: `⚠ Harness vX.Y.Z disponible (actual: vA.B.C) — /harness-update para detalle`
   - No se repite sesión tras sesión mientras no se actualice

3. **Aplicación** (manual, a pedido del usuario vía `/harness-update`)
   - Ejecuta `skills/harness-update/scripts/apply-update.sh <version>`
   - Checkout del tag en `.aura/`
   - Copia de `.claude/hooks/*.ps1` (sobreescritura directa, sin confirmación — D5)
   - Resincronización del bloque `aura:begin/aura:end` en `CLAUDE.md` (si existe)
   - Imprime resumen de lo que cambió + entradas relevantes del CHANGELOG

---

## Scripts de Orquestación

| Script | Hace | Contrato |
|---|---|---|
| `check-update.sh [aura_path]` | Compara tag local vs. remoto en `.aura/` | stdout = versión nueva, o vacío si al día |
| `apply-update.sh <tag> [aura_path]` | Checkout + copia de hooks + resync de CLAUDE.md | exit 0 si éxito, exit 1 si error; imprime resumen |

---

## Cuándo Usar `/harness-update`

- El usuario ve la línea de aviso en el Resumen Ejecutivo y quiere actualizar ahora
- El usuario sospecha que el harness está desactualizado
- Después de que se mergeó una PR al harness que corrige un bug o agrega una feature que el repo
  consumidor necesita (ej. nueva skill, fix de permisos, cambio de comportamiento)

## Precondición de Contenido

`.aura/` debe ser un checkout git del harness (`aura-agent-kit`). Si es una instalación antigua
con `.aura/` copiado (no submodule), el skill avisa pero no falla — sin actualización
disponible en ese caso.

---

## Defin ición de Done (DoD) para `/harness-update`

- [ ] Hook `SessionStart` injeta `harness_update_available` y `harness_latest_version` en contexto
- [ ] Línea de aviso aparece en Resumen Ejecutivo si hay actualización
- [ ] `/harness-update` ejecuta `check-update.sh` y `apply-update.sh` sin error
- [ ] Hooks en `.claude/hooks/` se actualizan si hay cambios
- [ ] Bloque `aura:begin/aura:end` en `CLAUDE.md` se resincroniza si existe
- [ ] Resumen de cambios + CHANGELOG se imprime correctamente

---

## Notas de Diseño

- **No hay automático mid-sesión:** la actualización es determinística (script bash) pero se
  dispara solo a pedido explícito, nunca como hot-patch durante una sesión activa.
- **Hooks son 100% del harness:** no existe customización legítima por repo en
  `.claude/hooks/*.ps1`. Cualquier necesidad local usa `.claude/settings.local.json` o
  `AGENTS.local.md` en su lugar (ver D8 de la spec).
- **Sin dependencias externas:** los scripts solo usan `bash`, `git`, `gh`, `python3` (disponibles
  siempre en entornos soportados).

---

## Remember

- La detección de actualizaciones es automática (via hook) pero invisible (cero tokens del agente)
- La aplicación es manual, nunca forceda
- Al aplicar: los hooks siempre se sobreescriben (sin confirmación diff-and-ask)
- Si algo falla durante `apply-update.sh`, no hay estado parcial — cada paso es idempotente o
  reversible
