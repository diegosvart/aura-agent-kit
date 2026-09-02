# Agente Browser Testing — E2E/Headless de Apps Web

> **Propósito:** Validar programáticamente que una app web funciona — sin supervisión
> humana, en background o dentro de un loop de desarrollo — vía `agent-browser`
> (`vercel-labs/agent-browser`), un CLI nativo headless sobre Chrome DevTools Protocol.

---

## Cuándo usar

- Smoke test tras implementar un issue con impacto en UI, antes de darlo por terminado.
- Verificar que un flujo crítico (login, formulario clave, navegación principal) no se
  rompió tras un cambio.
- Capturar screenshot de regresión visual antes/después de un cambio de UI.
- Cualquier validación web que no necesite que el usuario vea/participe en tiempo real —
  si el objetivo es mostrarle algo al usuario o usar su sesión real logueada, esa es
  `agents/browser-control.md`, no esta capability.

## Carga

Detección de disponibilidad, análogo a `where engram` en `session_start.md`:

```bash
where agent-browser 2>nul || echo "agent-browser: no disponible"
```

Si no está disponible:
- **Informar explícitamente** ("agent-browser: no disponible") — nunca fallar en
  silencio ni asumir la capability disponible.
- **Ofrecer el comando de instalación exacto** (ver documentación de
  `vercel-labs/agent-browser` para el binario de la plataforma actual).
- **Nunca ejecutar la instalación sin una confirmación explícita del usuario en ese
  mismo turno** — regla "nunca ejecutar sin aprobación" del harness, sin excepción acá.

## Invocación — exclusivamente CLI puro

Todas las interacciones son comandos CLI directos (`agent-browser open/snapshot/click/
fill/get/screenshot/diff/wait`), con salida `--json` para parseo estructurado.

**Nunca usar el subcomando `mcp` de la herramienta** — Pilar P1 (CLI > MCP si el CLI
alcanza). Verificable por grep: ningún archivo de esta capability debe invocar ese modo.

## Salvaguardas — capa harness

- Nunca ejecutar una acción irreversible (pago, envío, borrado, alta/baja de datos
  reales, ingreso de credenciales) sin confirmación explícita del usuario en ese mismo
  turno — mismo principio que "Executing actions with care" del harness base.
- Si la app bajo test maneja datos de un cliente real, no transcribir esos datos a un
  archivo trackeado, commit, issue o PR (ver `.claude/rules/sensitive-data-safety.md`).
- El daemon de `agent-browser` es persistente entre invocaciones — cerrar la
  sesión/tab al terminar (ver "Errores comunes"), no depender solo del timeout de
  inactividad.
- Usar `snapshot -i` + refs deterministas (`@e1`, `@e2`, ...) para interactuar, nunca
  selectores CSS frágiles — es el patrón recomendado por la propia herramienta y evita
  flakiness en apps con mucho JS.

## Tabla de decisión — `browser-control` vs. `browser-testing`

| Situación | Usar |
|---|---|
| El usuario quiere ver/guiar la interacción, o hace falta su sesión real logueada | `agents/browser-control.md` (`claude-in-chrome`) |
| Validar programáticamente que una app funciona, sin supervisión humana, en background o CI-like | `agents/browser-testing.md` (`agent-browser`) |
| Smoke test post-implementación de un issue, dentro de `/run-dev-loop` | `agents/browser-testing.md` |
| Confirmar visualmente un estado ambiguo, mostrarle algo al usuario en vivo | `agents/browser-control.md` |

## Qué NO es esta capability

- No reemplaza `agents/browser-control.md` — si el objetivo es que el usuario vea/
  participe con su navegador real y sesión logueada, esa sigue siendo la vía correcta.
  `browser-testing` opera siempre headless/aislado, sin navegador visible del usuario,
  sin sus cookies/sesiones reales.
- No reemplaza una suite de tests E2E propia del proyecto consumidor (ej. Playwright en
  CI, ya listada como opción de stack en `skills/stack-selection/SKILL.md`) — es una
  herramienta para validación ad-hoc/smoke conversacional del agente, no un framework de
  testing de proyecto. Si el proyecto ya tiene su propia suite E2E corriendo en CI, usar
  esa como fuente de verdad; `browser-testing` complementa con smoke tests rápidos
  durante el desarrollo, no la reemplaza.
- No usa el subcomando `mcp` de la herramienta bajo ninguna circunstancia (Pilar P1).

## Errores comunes

| Error | Solución |
|-------|----------|
| `agent-browser: no disponible` | Informar y ofrecer el comando de instalación exacto; nunca instalar sin aprobación explícita del usuario en el turno |
| Instalación falla por red/proxy restringido (entorno corporativo) | Reportar el error tal cual, sin enmascarar; no reintentar en loop, no asumir conectividad libre |
| Selector CSS frágil falla tras un cambio de UI menor | Usar `snapshot -i` + refs deterministas (`@eN`) en vez de CSS — patrón recomendado por la herramienta |
| Daemon queda corriendo con sesiones abandonadas | Cerrar la sesión/tab explícitamente al terminar el flujo (Paso 5 de `skills/e2e-testing/SKILL.md`); si igual queda colgado, verificar/matar el proceso `agent-browser` manualmente |
| Falta `--with-deps` en Linux sin dependencias de sistema | Instalar con `agent-browser install --with-deps` (documentado por la herramienta para distros sin las librerías de Chrome for Testing preinstaladas) |
