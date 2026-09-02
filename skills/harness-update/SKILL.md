---
name: harness-update
description: Detect and apply updates to the harness submodule
---

# Skill — Actualización del Harness (detección y aplicación)

> **Propósito:** Detectar actualizaciones disponibles del harness (`aura-agent-kit`) y
> aplicarlas de forma controlada (nunca automático, solo a pedido explícito del usuario).
> **Comando asociado:** `/harness-update`
> **Spec / hipótesis:** `docs/aura/specs/2026-07-30-harness-self-update.md`,
> `docs/aura/specs/2026-09-02-harness-update-plugin-apply-design.md` (P4)
> **Precondición:** el repo debe tener el harness instalado por al menos uno de los dos
> canales soportados (`.aura/` como submodule, o el plugin `aura` instalado vía marketplace
> de Claude Code). `/harness-update` detecta cuál aplica automáticamente (ver ADR-009) — si
> ninguno aplica, avisa pero no falla.

---

## Dos Canales, un Solo Comando (Issue #181 / #187, ADR-009)

El harness se distribuye por dos vías, y cada una necesita su propio mecanismo de detección
y aplicación de actualizaciones — mutuamente excluyentes por construcción, tanto en el hook
de detección como en `apply-update.sh`:

| Canal | Cómo se instala | Detección | Aplicación (ambas vía `/harness-update`) |
|---|---|---|---|
| `submodule` (legacy) | `.aura/` como git submodule | `check-update.sh` compara tags git | `apply-update.sh` hace `git fetch --tags` + `git checkout <tag>` en `.aura/` |
| `plugin` | `claude plugin install aura@<marketplace>` (ver `QUICKSTART.md` Opción C) | compara versión instalada vs. cache local del marketplace | `apply-update.sh` hace `claude plugin marketplace update` + `claude plugin update <plugin_id>` |

Ningún agente necesita saber a mano qué canal aplica ni armar el comando de `claude plugin`
correspondiente — `/harness-update` detecta el canal (misma señal en ambos scripts: ¿existe
`.aura/.git`?) y ejecuta la rama correcta. Los 4 pasos de sincronización posteriores (hooks,
`CLAUDE.md`, permisos, registro de `git-guard.ps1`/`sensitive-data-guard.ps1`) son
**idénticos** en ambos canales — solo cambia la fuente (`.aura/`, o el `installPath` del
plugin recién actualizado, resuelto vía `claude plugin list --json`).

### Canal `plugin` — cómo funciona

Sin `.aura/` no hay submódulo que chequear vía git — antes esta rama quedaba **muda** (ni
error ni aviso), dejando a los consumidores vía plugin sin ninguna señal de actualización
disponible. El hook `session-start.ps1` resuelve esto sin necesitar tags ni fetch propio:

1. `claude plugin list --json` → versión **instalada** del plugin `aura@*` (prioriza scope
   `project` sobre `user` si hay ambos)
2. `claude plugin marketplace list --json` → resuelve `installLocation`, el checkout local
   cacheado de la fuente del marketplace configurado (Claude Code ya lo mantiene actualizado
   vía `claude plugin marketplace update`, esta skill no dispara ningún fetch propio)
3. Lee `<installLocation>/.claude-plugin/plugin.json` → versión **publicada** (tal como está
   en el ref que trackea ese marketplace, ej. `develop` o `main` según cómo se configuró)
4. Si difieren → inyecta `harness_update_available`, `harness_latest_version`,
   `harness_update_channel: "plugin"` y `harness_update_plugin_id` (ej. `aura@aura-agent-kit`) en
   el JSON del hook — mismo cache TTL de 30 min que el canal legacy

**Precondición crítica:** `.claude-plugin/plugin.json` → `version` debe bumpearse en cada
release, o esta comparación siempre compara contra un número congelado. `cut-release.sh
changelog-pr` lo hace automáticamente en el mismo commit que `CHANGELOG.md` (ver
`agents/github.md` → "Proceso de Release").

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
   - Ejecuta `.aura/skills/harness-update/scripts/apply-update.sh <version>` desde la raíz del
     repo consumidor (el script vive dentro de `.aura/`, no en la raíz — ver issue #96) — o,
     si no hay `.aura/`, el mismo script instalado por el plugin (resuelto por su propio
     `installPath`)
   - Detecta el canal (`.aura/.git` existe → submodule; si no → plugin, leyendo
     `harness_update_plugin_id` del cache del hook)
   - Trae la versión nueva: `git checkout <tag>` (submodule) o `claude plugin marketplace
     update` + `claude plugin update <id>` (plugin) — **canal plugin: Claude Code requiere
     reiniciar la sesión para que el contenido nuevo tome efecto**
   - Copia de `.claude/hooks/*.ps1` (sobreescritura directa, sin confirmación — D5)
   - Resincronización del bloque `aura:begin/aura:end` en `CLAUDE.md` (si existe)
   - Sincronización de patrones muertos `Write(...)` → `Edit(...)` en `permissions.allow`/
     `permissions.deny` de `.claude/settings.json` (si existe y aplica — ver tabla abajo)
   - Verificación/registro de `git-guard.ps1` y `sensitive-data-guard.ps1` como `PreToolUse`
     en `.claude/settings.json` (autofix, sin confirmación — ver "Registro de
     `git-guard.ps1` en `PreToolUse`" abajo)
   - Imprime resumen de lo que cambió + entradas relevantes del CHANGELOG

---

## Scripts de Orquestación

| Script | Hace | Contrato |
|---|---|---|
| `check-update.sh [aura_path]` | Compara tag local vs. remoto en `.aura/` (solo canal submodule — el canal plugin se detecta en `session-start.ps1`, ver `.claude/hooks/session-start.ps1`) | stdout = versión nueva, o vacío si al día |
| `apply-update.sh <tag> [aura_path]` | Detecta canal, trae la versión nueva (checkout de tag o `claude plugin update`) + copia de hooks + resync de CLAUDE.md + resync de permisos en `.claude/settings.json` | exit 0 si éxito, exit 1 si error; imprime resumen |

### Resync de `.claude/settings.json` (patrones muertos `Write(...)`)

`apply-update.sh` reemplaza, de forma determinística y acotada (mismo principio que el resync
de `aura:begin/aura:end` en `CLAUDE.md`), los siguientes patrones muertos que Claude Code ya no
aplica (el tool real es `Edit`, no `Write`) por su equivalente vigente:

| Patrón muerto | Reemplazo |
|---|---|
| `Write(**)` | `Edit(**)` |
| `Write(.env)` | `Edit(.env)` |
| `Write(.env.*)` | `Edit(.env.*)` |
| `Write(*.pem)` | `Edit(*.pem)` |
| `Write(*.key)` | `Edit(*.key)` |
| `Write(*.secret)` | `Edit(*.secret)` |

Si `.claude/settings.json` no existe, o no contiene ninguno de estos patrones, el paso no hace
nada y no falla. Ninguna otra línea o regla del archivo se modifica. El resumen final reporta si
se aplicó (`Permisos settings.json: sincronizados (N patrones)`) o no
(`Permisos settings.json: sin cambios`).

### Registro de `git-guard.ps1` en `PreToolUse`

> **Por qué existe este paso:** caso real en `crawler-mcp-diagram` — el archivo
> `.claude/hooks/git-guard.ps1` existía (sincronizado por el paso de copia de hooks) pero
> nunca quedó registrado como `PreToolUse` en `.claude/settings.json`. Claude Code nunca lo
> invocaba, y 3 commits terminaron pusheados directo a `develop` sin que nada lo bloqueara —
> silencioso hasta que se investigó explícitamente por qué el push no había sido rechazado.
> `apply-update.sh` sincronizaba los *archivos* de hooks pero nunca verificaba que estuvieran
> *registrados*.

Tras copiar los hooks, `apply-update.sh` verifica que `PreToolUse` tenga un matcher `Bash` y
uno `PowerShell` cuyo `command` referencie `git-guard.ps1`. Si falta alguno, lo agrega
(preserva cualquier otra entrada existente en `PreToolUse` — no reemplaza el array completo).
Mismo criterio que el paso de copia de hooks (D5): autofix sin confirmación, porque un hook de
seguridad sin registrar es tan grave como uno desactualizado. Si `.claude/settings.json` no
existe, o `.claude/hooks/git-guard.ps1` todavía no se sincronizó, el paso se omite sin fallar
(se corrige solo en la próxima corrida). El resumen final reporta si se registró
(`git-guard.ps1 en PreToolUse: registrado (Bash,PowerShell) — antes NO estaba enforced`) o ya
estaba presente.

---

## Cuándo Usar `/harness-update`

- El usuario ve la línea de aviso en el Resumen Ejecutivo y quiere actualizar ahora
- El usuario sospecha que el harness está desactualizado
- Después de que se mergeó una PR al harness que corrige un bug o agrega una feature que el repo
  consumidor necesita (ej. nueva skill, fix de permisos, cambio de comportamiento)

## Precondición de Contenido

Uno de los dos: `.aura/` como checkout git del harness (`aura-agent-kit`), o el plugin `aura`
instalado vía `claude plugin install` con su marketplace registrado. Si es una instalación
antigua con `.aura/` copiado (no submodule, no plugin), el skill avisa pero no falla — sin
actualización disponible en ese caso.

---

## Defin ición de Done (DoD) para `/harness-update`

- [ ] Hook `SessionStart` injeta `harness_update_available`, `harness_latest_version` y
      `harness_update_channel` en contexto, para ambos canales
- [ ] Línea de aviso aparece en Resumen Ejecutivo si hay actualización, con el comando
      correcto según el canal
- [ ] `/harness-update` ejecuta `apply-update.sh` sin error en ambos canales (submodule y
      plugin), sin que el agente arme comandos de `claude plugin` a mano
- [ ] Hooks en `.claude/hooks/` se actualizan si hay cambios (desde `.aura/` o desde el
      `installPath` del plugin, según el canal)
- [ ] Bloque `aura:begin/aura:end` en `CLAUDE.md` se resincroniza si existe
- [ ] Patrones muertos `Write(...)` en `.claude/settings.json` se resincronizan a `Edit(...)` si existen
- [ ] `git-guard.ps1` queda registrado como `PreToolUse` (`Bash` y `PowerShell`) en `.claude/settings.json` si el hook existe
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
