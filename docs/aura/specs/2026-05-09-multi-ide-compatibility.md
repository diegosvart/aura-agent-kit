# Spec — Capa de Compatibilidad Multi-IDE

> **Propósito:** Definir cómo el harness Aura es consumible por múltiples IDEs de AI sin duplicar contenido.
> **Versión del harness:** 1.1.0
> **Fecha:** 2026-05-09

---

## Problema

El harness Aura está documentado en `AGENTS.md` y archivos especializados. Sin adaptadores formales, cada IDE requiere configuración manual y no existe una forma estándar de instalar el harness en un nuevo proyecto.

## Objetivo

Crear una capa de compatibilidad que permita a cualquier IDE de AI soportado consumir el harness con el mínimo setup posible, sin duplicar contenido.

## Decisiones de Diseño

### D1 — Wrapper liviano, no copia
Los adaptadores NO duplican contenido de `AGENTS.md`. Son archivos que referencian o destacan el harness existente. Razón: actualizar `AGENTS.md` propaga automáticamente a todos los IDEs.

**Anti-patrón:** Copiar los 7 pilares a cada adaptador. Si cambia un pilar, habría que actualizar N archivos.

### D2 — AGENTS.md como anchor universal
`AGENTS.md` es el estándar emergente adoptado por 10+ herramientas. Es el punto de entrada para IDEs que lo leen nativamente (Codex, Aider, Antigravity, Zed).

### D3 — Contenido inline solo cuando es obligatorio
Copilot y Windsurf no soportan referencias externas en sus archivos de configuración. Para estos IDEs se crea una versión destilada (~60-80 líneas) con identidad + pilares + flujo esencial.

### D4 — Cursor: dos capas de reglas
`alwaysApply: true` → identidad + pilares (~20 líneas, siempre en contexto).
`alwaysApply: false` → workflow detallado (on-demand, cero costo cuando no se usa).

### D5 — IDEs que no necesitan adaptador
Codex (OpenAI) y Zed leen `AGENTS.md` directamente. Cero overhead, cero mantenimiento.

---

## Matriz de Compatibilidad

| IDE | Archivo adaptador | Refs externas | Necesita inline | Setup requerido |
|-----|------------------|---------------|-----------------|-----------------|
| Claude Code | `CLAUDE.md` + `settings.json` | Sí | No | Copiar 2 archivos |
| GitHub Copilot | `copilot-instructions.md` | No | Sí (~80 líneas) | Copiar 1 archivo |
| OpenAI Codex | — | N/A | N/A | Ninguno (nativo) |
| Cursor | `rules/aura-identity.mdc` + `aura-workflow.mdc` | Sí | Parcial | Copiar 2 archivos |
| Windsurf | `rules/aura-harness.md` | No | Sí (~60 líneas) | Copiar 1 archivo |
| Aider | `.aider.conf.yml` + `CONVENTIONS.md` | Sí (read:) | No | Copiar 2 archivos |
| Antigravity | `GEMINI.md` (override) | Sí | No | Copiar 1 archivo |
| OpenCode | `opencode.json` | Sí | No | Copiar 1 archivo |
| Zed | — | N/A | N/A | Ninguno (nativo) |

---

## Cómo Mantener los Adaptadores Sincronizados

1. Si cambia `AGENTS.md` → verificar si algún adaptador inline (Copilot, Windsurf) necesita update
2. Si se agrega un pilar → actualizar `cursor/rules/aura-identity.mdc` (alwaysApply) y los inline
3. Si se agrega un comando → no requiere cambio en adaptadores (los comandos están en `commands/`)
4. Usar `/doc-check` después de cualquier cambio en adaptadores

---

## Criterios de Aceptación

- [ ] `integrations/` contiene adaptadores para 7 IDEs
- [ ] Ningún adaptador duplica contenido completo de `AGENTS.md`
- [ ] `integrations/README.md` documenta instalación por IDE
- [ ] IDEs nativos (Codex, Zed) documentados como "sin setup requerido"
- [ ] `/doc-check` pasa después de crear todos los adaptadores

---

*Spec aprobada: 2026-05-09 | Implementada en PR #5*
