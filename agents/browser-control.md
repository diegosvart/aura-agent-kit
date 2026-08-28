# Agente Browser Control — Visión/Control de Navegador

> **Propósito:** Dar al agente visión y control de un navegador real (vía
> `claude-in-chrome`) para agotar automatización cuando no hay CLI/MCP que resuelva
> la tarea, y/o para guiar al usuario mostrándole/operando la pantalla.

---

## Cuándo usar

Dos casos de uso, igualmente válidos — no hace falta que el usuario lo pida:

1. **Exploratorio (el agente lo evalúa como opción):** después de considerar CLI y
   MCP (Pilar P1), si no hay ninguna vía programática para la tarea, o si el
   objetivo es específicamente validar algo visual en una app web (confirmar que un
   dashboard renderiza bien, verificar un estado de UI que no expone API).
2. **A pedido del usuario:** "mostrame", "guiame", "quiero ver la pantalla" — el
   agente opera o comparte el navegador mientras el usuario observa/participa.

## Carga

Verificar disponibilidad vía `ToolSearch` antes de asumir la capacidad — batch
recomendado por el propio MCP:
```
select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__tabs_close_mcp
```
Agregar tools específicas de la tarea al mismo batch (`read_console_messages`,
`read_network_requests`, `form_input`, `gif_creator`, `javascript_tool`) cuando se
sepa de antemano que van a hacer falta.

Si `claude-in-chrome` no conecta o no está instalado → informar al usuario, no
fallar en silencio (mismo principio que este harness aplica a `gh` no autenticado
en `.aura/rules/harness-core.md`).

## Salvaguardas — capa nativa (heredadas de `claude-in-chrome`)

- Nunca disparar `alert`/`confirm`/`prompt` u otros diálogos bloqueantes.
- No hacer rabbit-holing: 2-3 intentos fallidos sobre la misma acción → parar y
  preguntar al usuario en vez de seguir reintentando.
- Preferir `read_console_messages`/`read_network_requests` a interacción manual con
  devtools.
- Grabar GIF (`gif_creator`) cuando la interacción es multi-paso y el usuario se
  beneficia de revisarla después.

## Salvaguardas — capa harness

- Nunca ejecutar una acción irreversible (pago, envío, borrado, alta/baja de datos
  reales, ingreso de credenciales) sin confirmación explícita del usuario en ese
  mismo turno — mismo principio que "Executing actions with care" del harness base.
  Esto es más estricto que la regla nativa: aplica incluso si la acción no dispara
  un diálogo de confirmación del sitio.
- Si la tarea involucra datos sensibles de un cliente real, no transcribir esos
  datos a un archivo trackeado, commit, issue o PR (ver
  `.claude/rules/sensitive-data-safety.md`) — el navegador puede mostrarlos en
  pantalla al usuario, eso no implica que el agente los versione.

## Tabla de decisión — "ver" vs "controlar"

| Modo | Cuándo | Ejemplo |
|---|---|---|
| **Ver** (agente navega/lee, usuario mira) | El usuario necesita confirmar visualmente un estado, o el agente necesita mostrar algo sin tocar nada | Abrir una página y describir qué se ve, sin clicks |
| **Controlar** (agente hace click/type/submit) | El objetivo requiere completar una acción y no hay riesgo irreversible, o el usuario ya confirmó el paso | Completar un formulario de búsqueda, navegar un flujo de lectura |

## Qué NO es esta capability

- No reemplaza CLI/MCP cuando existen (Pilar P1) — es el último recurso técnico.
- No es Playwright ni ningún otro navegador automatizado aislado: opera sobre el
  navegador real del usuario, con sus sesiones/logins ya activos, visible en tiempo
  real. Si el caso de uso es testing E2E determinístico sin supervisión humana ni
  necesidad de sesión real, ese es un problema distinto, fuera del alcance de este
  agente.
- No cubre aplicaciones de escritorio fuera del navegador (ERP cliente pesado,
  Excel, ventanas nativas).

## Errores comunes

| Error | Solución |
|-------|----------|
| Tools `mcp__claude-in-chrome__*` no aparecen | Cargar vía `ToolSearch` antes de invocarlas, nunca asumir disponibilidad |
| Un diálogo nativo del sitio bloquea la sesión | No disparar acciones que abran `alert`/`confirm`/`prompt`; si ocurre, informar al usuario que debe cerrarlo manualmente |
| Reintentos repetidos sobre el mismo click/selector sin éxito | Parar a los 2-3 intentos, preguntar al usuario en vez de seguir |
