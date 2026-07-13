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

## Paso 1 — Detectar Tecnología del Proyecto

Detectar automáticamente el stack para ejecutar verificaciones correctas:

```bash
# Python
if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    LINTER="ruff"
    TEST_RUNNER="pytest"
    TYPE_CHECKER="mypy"
# Node.js
elif [ -f "package.json" ]; then
    LINTER="npm run lint"
    TEST_RUNNER="npm test"
    TYPE_CHECKER="npx tsc --noEmit"
# Rust
elif [ -f "Cargo.toml" ]; then
    LINTER="cargo clippy"
    TEST_RUNNER="cargo test"
    TYPE_CHECKER="cargo check"
fi
```

---

## Paso 2 — Verificación Obligatoria (antes de permitir cierre)

Ejecutar en orden (si falla, no permitir cierre):

### 1. Linter
```bash
# Python
python -m ruff check .  # 0 errores

# Node.js
npm run lint || eslint .  # 0 errores
```

### 2. Tests
```bash
# Python
pytest tests/ --ignore=tests/e2e -q  # todos verdes

# Node.js
npm test  # todos pasando
```

### 3. Branch no es develop/main
```bash
BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "main" ]; then
    echo "ERROR: No puedes cerrar sesión en develop/main"
    exit 1
fi
```

---

## Paso 3 — Verificación de Estado GitHub (pre-Engram)

> Ejecutar SOLO si `gh_authenticated == true` (del hook output).
> Si gh no autenticado → marcar `gh_verified: false` y continuar con advertencia.

### Fast-path

Si el hook ya provee `recently_merged_prs` y `recently_closed_issues` → usar esos datos directamente y saltear el Paso 3.1.

### 3.1 — Capturar estado real (si no hay fast-path)

```powershell
# PRs mergeadas recientemente
gh pr list --state merged --limit 10 --json number,title,mergedAt,headRefName

# PRs aún abiertas
gh pr list --state open --limit 20 --json number,title,headRefName

# Issues cerrados recientemente
gh issue list --state closed --limit 10 --json number,title,closedAt

# Issues listos (trabajo real pendiente)
gh issue list --label ready --state open --json number,title
```

### 3.2 — Construir pending_verified

Revisar cada item que se planea incluir en `pending`:

- Si menciona "Mergear/PR #N" y PR #N está mergeada → **eliminar**
- Si menciona "Cerrar/Issue #N" y issue #N está cerrado → **eliminar**
- Si menciona PR abierta o issue abierto → **conservar**
- Si es trabajo local (código, docs) sin referencia GitHub → **conservar**

Si se eliminó algún item → agregar nota al `## Accomplished` del Paso 4 (Engram):
> "Verificación pre-Engram: PR #N ya mergeada — eliminado de pending."

### 3.3 — Si gh no autenticado

```
pending_verified = pending_raw  (sin filtrar)
⚠ Advertencia en current-session.json: "gh_verified: false — pending puede tener items desactualizados"
```

---

## Paso 4 — Guardar Memoria en Engram

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

## Paso 5 — Actualizar current-session.json

Archivo: `.agent/memory/current-session.json`

```json
{
  "last_updated": "{{ISO_TIMESTAMP}}",
  "branch": "{{CURRENT_BRANCH}}",
  "focus": "{{RESUMEN_DE_UN_LÍNEA}}",
  "next_step": "{{SIGUIENTE_ACCIÓN_CONCRETA}}",
  "pending": ["{{TAREA_1}}", "{{TAREA_2}}", "{{TAREA_3}}", "{{TAREA_4}}"],
  "required_reads": ["{{ARCHIVO_1}}", "{{ARCHIVO_2}}", "{{ARCHIVO_3}}"]
}
```

**Reglas:**
- Max 4 items en `pending`
- Max 4 items en `required_reads`
- No incluir lista `completed` — eso vive en Engram
- Usar EXCLUSIVAMENTE `pending_verified` del Paso 3. Nunca escribir este array sin verificar contra GitHub.
- Si `gh_verified: false` → incluir advertencia como último item: `"⚠ gh no autenticado — verificar manualmente"`

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

> Usar los datos de `gh_reality` capturados en el Paso 3. No ejecutar comandos `gh` adicionales.

Presentar tabla de cierre:

```
## Issues esta sesión
| # | Título | Estado |
|---|--------|--------|
| #N | <título> | ✅ Cerrado |
| #N+1 | <título> | 🔲 Pendiente (ready) |
```

Verificar activamente si hay trabajo listo para PR:

```bash
BRANCH=$(git branch --show-current)
COMMITS=$(git log origin/develop..HEAD --oneline 2>/dev/null | wc -l)
PR_COUNT=$(gh pr list --head "$BRANCH" --state open --json number -q 'length' 2>/dev/null || echo 0)
```

- Si `$COMMITS > 0` y `$PR_COUNT == 0` → **Proponer:** "Hay $COMMITS commit(s) sin PR. ¿Creamos la PR ahora con `/finish-branch`?"
- Si hay PR abierta sin reviewer → **Proponer:** "¿Solicitamos review con `/request-review`?"
- Si la PR fue aprobada y mergeada → **Proponer:** cerrar el issue asociado

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
| `pending` con items ya mergeados/cerrados | Ejecutar Paso 3 completo antes de continuar — nunca saltear la verificación GitHub |

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
2. Append a `.agent/memory/project-log.md` si no hay entrada para ese PR todavía.
3. Cerrar el issue referenciado:
   ```bash
   gh issue close {{N}} --comment "Implementado en PR #{{PR}} (merged a develop {{FECHA}})"
   ```
4. Mover item en Project board de Todo → Done