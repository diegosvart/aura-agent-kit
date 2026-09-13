# Protocolo — Session End

> **Cuándo:** Al cerrar cada sesión de trabajo.
> **Obligatorio:** Sí.
>
> **Alcance (desde 2026-07-13):** este protocolo registra el estado de la SESIÓN (dónde
> quedó parado el trabajo, memoria de continuidad). **Ya NO es el único lugar donde se
> documenta "qué se implementó"** — eso vive en `.agent/memory/project-log.md` y se
> actualiza en el momento del merge a develop (ver `.aura/agents/github.md`, sección "Al
> Mergear una PR a Develop"), sin depender de que esta sesión llegue a cerrarse formalmente.
> Motivo del cambio: depender solo de la frase de cierre para documentar avances demostró
> ser poco confiable — sesiones que no cerraban formalmente no dejaban ningún registro.

---

## Paso 1 — Invocar session-end-gather.ps1 (gathering consolidado)

> **Issue #259.** Reemplaza en una sola invocación las ~7 tool-calls dispersas que este
> protocolo ejecutaba antes por separado (linter, tests, chequeo de rama, 4 llamadas `gh`).
> Diseño completo en
> `docs/aura/specs/2026-09-12-session-end-script-consolidation-design.md`.

Invocar, sin parámetros, al detectar el trigger de cierre de sesión:

```powershell
pwsh -NonInteractive -File .claude/hooks/session-end-gather.ps1
```

El script **no está registrado como hook** `SessionEnd` (ese evento dispara después de que la
conversación ya cerró — no sirve para este caso, ver spec sección "Problema"). Es el agente
quien lo invoca manualmente vía Bash/PowerShell tool al detectar el trigger textual
("terminamos", "cerramos", ...).

Emite un único JSON con:

```json
{
  "stack": { "profile": "...", "lint": "...", "test": "...", "source": "session-stack.json | detected | none" },
  "lint_result": { "ran": true, "command": "...", "exit_code": 0, "output_tail": "..." },
  "test_result": { "ran": true, "command": "...", "exit_code": 0, "output_tail": "..." },
  "branch": "feature/xyz",
  "branch_protected": false,
  "gh_authenticated": true,
  "recently_merged_prs": [ { "number": 264, "title": "...", "mergedAt": "...", "headRefName": "..." } ],
  "recently_closed_issues": [ { "number": 262, "title": "...", "closedAt": "..." } ],
  "open_prs": [ { "number": 265, "title": "...", "headRefName": "..." } ],
  "ready_issues": [ { "number": 231, "title": "..." } ],
  "commits_ahead_of_develop": 3,
  "pr_for_current_branch": { "number": 265, "title": "..." }
}
```

### Interpretación — Gate obligatorio (bloqueante, no permitir cierre si se dispara)

- `lint_result.exit_code != 0` (cuando `lint_result.ran == true`) → mostrar `output_tail` y
  **no permitir cierre** hasta corregir.
- `test_result.exit_code != 0` (cuando `test_result.ran == true`) → mismo bloqueo, mostrar
  `output_tail`.
- `branch_protected == true` → **no permitir cierre** (rama es `develop` o `main`).
- Si `stack.source == "none"` (repo sin lenguaje de código, como este mismo harness):
  `lint_result.ran` y `test_result.ran` vienen en `false` explícito — no es un salteo
  silencioso, no bloquea.

### Interpretación — Estado GitHub

- `gh_authenticated == false` es la **única** señal válida para "no hay datos de GitHub" — los
  4 arrays (`recently_merged_prs`, `recently_closed_issues`, `open_prs`, `ready_issues`) vienen
  vacíos en ese caso. Nunca interpretar un array vacío como "nada pendiente" sin chequear este
  flag primero. Con `gh_authenticated == false`: marcar `gh_verified: false` y continuar con
  advertencia (ver Paso 2).

### Fallback — si `session-end-gather.ps1` falla (obligatorio, nunca en silencio)

Si la invocación falla (script ausente, `pwsh` no disponible en el entorno, excepción no
controlada, o exit code sin JSON válido en stdout):

1. Mostrar explícitamente:
   ```
   ⚠ session-end-gather.ps1 no disponible (<motivo>) — degradando a verificación manual
   ```
   Nunca asumir en silencio que "no hay pendientes" ni saltear el gate de arriba.
2. Ejecutar los comandos manuales equivalentes uno por uno — **usar solo si el script falla**:

   **Linter y tests del stack detectado:**
   ```bash
   # Python
   if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
       python -m ruff check .   # 0 errores
       pytest tests/ --ignore=tests/e2e -q   # todos verdes
   # Node.js
   elif [ -f "package.json" ]; then
       npm run lint || eslint .   # 0 errores
       npm test   # todos pasando
   # Rust
   elif [ -f "Cargo.toml" ]; then
       cargo clippy
       cargo test
   fi
   ```

   **Branch no es develop/main:**
   ```bash
   BRANCH=$(git branch --show-current)
   if [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "main" ]; then
       echo "ERROR: No puedes cerrar sesión en develop/main"
       exit 1
   fi
   ```

   **Estado GitHub (equivalente a los 4 arrays del JSON):**
   ```powershell
   gh pr list --state merged --limit 10 --json number,title,mergedAt,headRefName
   gh pr list --state open --limit 20 --json number,title,headRefName
   gh issue list --state closed --limit 10 --json number,title,closedAt
   gh issue list --label ready --state open --json number,title
   ```

   **Commits ahead de develop:**
   ```bash
   git fetch origin develop --quiet
   git log origin/develop..HEAD --oneline | wc -l
   ```
3. Esta caída **cuenta como señal para la hipótesis P4**
   (`docs/aura/experiments/2026-09-12-session-end-script-consolidation.md`, sección "Qué la
   refutaría") — si ocurre en más de 1 de los 3 cierres de la ventana de observación, investigar
   la causa antes de darla por resuelta, no solo repetir el fallback cada vez.

---

## Paso 2 — Construir pending_verified (síntesis sobre el JSON del Paso 1)

> Sin cambio de lógica respecto al protocolo anterior — solo cambia la fuente de datos (un
> único JSON en vez de 4 llamadas `gh` sueltas).

Revisar cada item que se planea incluir en `pending`:

- Si menciona "Mergear/PR #N" y PR #N aparece en `recently_merged_prs` → **eliminar**
- Si menciona "Cerrar/Issue #N" y issue #N aparece en `recently_closed_issues` → **eliminar**
- Si menciona PR abierta (`open_prs`) o issue abierto (`ready_issues`) → **conservar**
- Si es trabajo local (código, docs) sin referencia GitHub → **conservar**

Si se eliminó algún item → agregar nota al `## Accomplished` del Paso 4 (Engram):
> "Verificación pre-Engram: PR #N ya mergeada — eliminado de pending."

### Si `gh_authenticated == false` (del JSON del Paso 1)

```
pending_verified = pending_raw  (sin filtrar)
⚠ Advertencia en current-session.json: "gh_verified: false — pending puede tener items desactualizados"
```

> **Nota de numeración (Issue #259):** el antiguo Paso 3 ("Verificación de Estado GitHub") se
> absorbió íntegramente en los Pasos 1–2 de arriba — no hay un Paso 3 independiente en esta
> versión del protocolo. Los pasos siguientes conservan su numeración original (4 en adelante)
> porque su lógica no cambió, solo la fuente de datos que consumen.

---

## Paso 4 — Guardar Memoria en Engram

Antes de guardar: si la observación es una decisión que ya se guardó antes y solo cambió
de estado (no un hecho puntual nuevo), buscar con `mem_search` la observación previa sobre
el mismo tema y usar el mismo `topic_key` para que `mem_save` la actualice (upsert) en vez
de crear una fila nueva. Ver convención completa en `AGENTS.md` → "Convención `topic_key`".

```bash
mem_session_summary(
  content="## Goal
[Una línea: en qué estuvimos trabajando]

## Instructions
[Preferencias del usuario, constraints, contexto descubierto]

## Discoveries
- [Hallazgo técnico 1]
- [Hallazgo técnico 2]

## Accomplished
- ✅ [Tarea completada 1]
- ✅ [Tarea completada 2]
- 🔲 [Identificado pero no hecho — para próxima sesión]

## Relevant Files
- [archivo 1] — [qué hace o cambió]
- [archivo 2] — [qué hace o cambió]",
  project="{{PROJECT_NAME}}"
)
```

---

## Paso 5 — Actualizar current-session.json (puntero local, no versionado)

> **Desde ADR-006:** Engram (Paso 4) es la memoria primaria real. `current-session.json` es
> solo un **puntero local de emergencia** — la única razón por la que existe es servir de
> fallback si Engram no está disponible al iniciar la próxima sesión (ver
> `protocols/session_start.md` Paso 5). Está en `.gitignore`: este paso es un `Write` directo
> al archivo, **nunca** un commit ni una rama/PR — no pasa por `git-guard.ps1` porque nunca
> invoca `git commit`/`git push`. Si en algún momento aparece como pendiente en `git status`,
> algo está mal (posible reversión accidental del `.gitignore`) — no commitearlo, corregir el
> `.gitignore` primero.

Archivo: `.agent/memory/current-session.json`

```json
{
  "last_updated": "{{ISO_TIMESTAMP}}",
  "branch": "{{CURRENT_BRANCH}}",
  "next_step": "{{SIGUIENTE_ACCIÓN_CONCRETA, UNA LÍNEA, SIN PROSA DE PROCESO}}"
}
```

**Reglas:**
- Solo estos 3 campos — sin `focus`, `pending` ni `required_reads` (narrativa/detalle real
  vive en Engram, Paso 4; `session_start.md` nunca leyó esos campos en la práctica).
- `next_step` debe ser un hecho verificable y telegráfico, no una narrativa del proceso de la
  sesión — ver Issue #121 (privacidad de la forma de trabajar del usuario).
- Usar EXCLUSIVAMENTE información ya verificada contra GitHub en el Paso 2 (`pending_verified`)
  al redactar `next_step`. Nunca escribir sobre algo sin verificar contra GitHub.
- Si `gh_verified: false` → agregar `" (⚠ gh no autenticado — verificar manualmente)"` al final
  de `next_step`.

---

## Paso 6 — Docs/ADRs (si corresponde)

Si durante la sesión se tomó una decisión arquitectural:
- Crear/actualizar ADR en `docs/adr/`
- Documentar en `docs/` si es necesario
- Referenciar en el commit/PR

> Nota: si el trabajo de la sesión ya se mergeó a develop, el resumen "qué se agregó" para
> el proyecto ya debería estar en `.agent/memory/project-log.md` (ver `agents/github.md`).
> Este paso es sobre decisiones arquitecturales que ameritan un ADR formal, no un duplicado
> de esa bitácora.

---

## Paso 7 — Verificar Issues de la Sesión

> Reusa `recently_merged_prs`, `recently_closed_issues`, `ready_issues`,
> `commits_ahead_of_develop` y `pr_for_current_branch` del JSON del Paso 1 — este paso **no
> ejecuta ningún comando `gh`/`git log` propio** (Issue #259; antes eran 3 comandos sueltos).

Presentar tabla de cierre:

```
## Issues esta sesión
| # | Título | Estado |
|---|--------|--------|
| #N | <título> | ✅ Cerrado |
| #N+1 | <título> | 🔲 Pendiente (ready) |
```

Usar `commits_ahead_of_develop` y `pr_for_current_branch` (ambos ya calculados en el Paso 1)
para decidir si hay trabajo listo para PR:

- Si `commits_ahead_of_develop > 0` y `pr_for_current_branch == null` → **Proponer:** "Hay
  {{commits_ahead_of_develop}} commit(s) sin PR. ¿Creamos la PR ahora con `/finish-branch`?"
- Si `pr_for_current_branch` no es `null` y no tiene reviewer → **Proponer:** "¿Solicitamos
  review con `/request-review`?"
- Si la PR fue aprobada y mergeada (aparece en `recently_merged_prs`) → **Proponer:** cerrar el
  issue asociado

---

## Paso 8 — Integridad Documental (si aplica)

Si durante la sesión se crearon o modificaron archivos `.md`:
```
Invocar /doc-check para verificar integridad antes de cerrar.
```
Si el reporte es ÍNTEGRO → continuar.
Si REQUIERE CORRECCIÓN → corregir antes de commitear.

---

## Paso 9 — Presentar Opciones para Próxima Sesión

```
## Sesión Lista para Cerrar
✓ Linter limpio
✓ Tests pasando
✓ Rama: {{rama}}
✓ Memoria guardada
✓ Issues verificados

## ¿Qué sigue?
1. [next_step] — continuar con lo pendiente
2. Nueva tarea — /plan-work para planificar
3. Revisión — mirar estado del proyecto
4. otra cosa — especificar
```

---

## Paso 10 — Auto-Research (si aplica)

Antes de cerrar, dedicar 30 segundos a observar:

- ¿Hubo algún paso que se repitió manualmente más de una vez esta sesión?
- ¿Algún protocolo o skill no aplicó bien al contexto?
- ¿El usuario tuvo que corregir al agente en algo recurrente?

**Si sí** → proponer `/auto-research` antes de cerrar:
> "Observé [fricción concreta]. ¿Querés que lo registremos como experimento de mejora del harness?"

**Si no** → cerrar normalmente.

---

## Paso 10.5 — Traza de Sesión (opcional, fail-open)

Ver `skills/session-trace/SKILL.md` para el proceso completo. Aplicar el mismo criterio de
"vale la pena" que Paso 10 (Auto-Research) — no preguntar en cada cierre, solo cuando hubo
señal concreta:

- ¿Hubo fricción real del harness, un desvío notable del flujo esperado, o una decisión de
  diseño no obvia que costó varios intentos resolver?

**Si sí** → proponer antes de cerrar:
> "Esta sesión tuvo [fricción/desvío concreto]. ¿Querés que genere una traza Archify para
> poder revisarla visualmente después?"

**Si el usuario acepta** → seguir el proceso de `skills/session-trace/SKILL.md` (autorear JSON
IR → validar `showcase` → entregar HTML → informar ruta local).

**Si el usuario rechaza, o no hay señal concreta** → cerrar normalmente, sin insistir. Este
paso nunca bloquea el cierre de sesión — el flujo completo de este protocolo funciona igual con
o sin traza.

---

## Reglas

1. **No cerrar si hay checks fallando** — el usuario debe saberlo
2. **Siempre guardar en Engram** — mantener continuidad
3. **Actualizar current-session.json** — mínimo viable de estado
4. **No perder trabajo** — si hay cambios sin commit, preguntar

---

##Errores Comunes

| Error | Solución |
|-------|----------|
| Linter falla | Corregir antes de cerrar |
| Tests fallan | Corregir antes de cerrar |
| Engram no disponible | Guardar en current-session.json como backup |
| Rama develop/main | Crear rama o cambiar de rama |
| `pending` con items ya mergeados/cerrados | Ejecutar Paso 2 completo antes de continuar — nunca saltear la verificación GitHub |
| `session-end-gather.ps1` no disponible o falla | Mostrar el aviso explícito del Paso 1 y degradar al fallback manual — nunca en silencio |

---

## Hooks Automáticos (si están configurados)

Si hay `session-end` hook en la configuración del IDE:
- Se ejecutará automáticamente
- No reemplazar la lógica manual

---

## Post-merge a develop (caso especial)

Si durante esta sesión se mergeó un PR a develop, el registro "qué se agregó" (ledger de
planes + `project-log.md`) **ya debería estar hecho** en el momento del merge — ver
`.aura/agents/github.md` sección "Al Mergear una PR a Develop". Si por algún motivo no se
hizo en su momento, hacerlo ahora antes de cerrar:
1. Actualizar el ledger de planes (`.agent/memory/plans/<...>.md` → `status: done`) si
   corresponde.
2. Guardar el bloque de `project-log.md` en Engram (`topic_key: project-log/pr-bookkeeping`)
   si no hay entrada para ese PR todavía — nunca un append directo ni una rama/PR dedicada
   solo para esto (ver `agents/github.md` → "Bookkeeping de `project-log.md`").
3. Verificar el merge y cerrar el issue referenciado (no reconstruir en prosa):
   ```bash
   skills/agentic-dev-loop/scripts/post-merge.sh <owner>/<repo> {{N}} {{PR}}
   ```
4. Mover item en Project board de Todo → Done