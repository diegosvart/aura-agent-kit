---
name: e2e-testing
description: Ejecuta un smoke test / flujo E2E headless contra una app web vía agent-browser, sin supervisión humana. Usar para validar un flujo crítico tras implementar un issue con impacto en UI, o capturar regresión visual.
---

# E2E Testing — Smoke Test Headless vía `agent-browser`

> Orquesta `agents/browser-testing.md`. Ver ese archivo para salvaguardas, tabla de
> decisión frente a `browser-control.md`, y qué NO es esta capability.

## Checklist

Completar en orden:

1. **Detectar disponibilidad** de `agent-browser`
   ```bash
   where agent-browser 2>nul || echo "agent-browser: no disponible"
   ```
   Si falta: informar explícitamente y ofrecer el comando de instalación exacto.
   **Nunca instalar sin aprobación explícita del usuario en este mismo turno.**

2. **Definir el flujo a validar** — antes de ejecutar nada:
   - URL(s) a probar
   - Pasos críticos (login, formulario clave, navegación principal)
   - Qué constituye éxito y qué constituye fallo, en términos verificables (texto
     esperado en pantalla, cambio de URL, elemento presente/ausente)

3. **Ejecutar vía CLI, por refs** (nunca el subcomando `mcp`, nunca selectores CSS):
   ```bash
   agent-browser open <url> --json
   agent-browser snapshot -i --json
   agent-browser click @eN
   agent-browser fill @eN "valor"
   agent-browser get text @eN
   agent-browser screenshot --json          # si aplica regresión visual
   agent-browser diff screenshot <baseline> # si aplica regresión visual
   agent-browser wait <condición>           # antes de interactuar tras una navegación/carga
   ```
   Re-tomar `snapshot -i` tras cada navegación o cambio de estado significativo — los
   refs (`@eN`) son válidos para el snapshot que los generó, no persisten entre estados.

4. **Reportar resultado por paso** — no un resultado global único:
   ```
   ## Resultado E2E: <flujo>
   | Paso | Resultado | Detalle |
   |------|-----------|---------|
   | Abrir <url> | ✅ | |
   | Login | ✅ | |
   | Enviar formulario | ❌ | Texto esperado "Guardado" no apareció — ver screenshot |
   ```
   Adjuntar/referenciar screenshots de los pasos que fallaron.

5. **Limpieza** — cerrar la sesión/tab de `agent-browser` al terminar, no dejar el
   daemon con sesiones abandonadas más allá de su timeout de inactividad configurado.

## Qué NO hace este skill

- No reemplaza una suite E2E propia del proyecto (Playwright/Cypress en CI) — es
  validación ad-hoc/smoke conversacional, ver `agents/browser-testing.md` → "Qué NO es
  esta capability".
- No opera sobre el navegador real del usuario ni usa sus sesiones/cookies — para eso,
  `agents/browser-control.md`.
