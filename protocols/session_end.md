# Protocolo — Session End

> **Cuándo:** Al cerrar cada sesión de trabajo.
> **Obligatorio:** Sí.

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

## Paso 3 — Guardar Memoria en Engram

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

## Paso 4 — Actualizar current-session.json

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

---

## Paso 5 — Docs/ADRs (si corresponde)

Si durante la sesión se tomó una decisión arquitectural:
- Crear/actualizar ADR en `docs/adr/`
- Documentar en `docs/` si es necesario
- Referenciar en el commit/PR

---

## Paso 6 — Presentar Opciones para Próxima Sesión

```
## Sesión Lista para Cerrar
✓ Linter limpio
✓ Tests pasando
✓ Rama: {{rama}}
✓ Memoria guardada

## ¿Qué sigue?
1. [next_step] — continuar con lo pendiente
2. Nueva tarea — planificar algo nuevo
3. Revisión — mirar estado del proyecto
4. otra cosa — especificar
```

---

## Paso 8 — Auto-Research (si aplica)

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

---

## Hooks Automáticos (si están configurados)

Si hay `session-end` hook en la configuración del IDE:
- Se ejecutará automáticamente
- No reemplazar la lógica manual

---

## Post-merge a develop (caso especial)

Si durante esta sesión se mergeó un PR a develop:
1. Cerrar el issue referenciado:
   ```bash
   gh issue close {{N}} --comment "Implementado en PR #{{PR}} (merged a develop {{FECHA}})"
   ```
2. Mover item en Project board de Todo → Done
3. Documentar en el resumen de sesión