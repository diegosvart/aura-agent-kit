---
name: harness-status
description: Genera un inventario del harness (conteo de AGENTS/SKILLS/PROTOCOLS/RULES/COMMANDS/HOOKS) y detecta referencias rotas en la tabla de routing de protocols/router.md. Usar cuando el usuario pide /harness-status o un diagnóstico de qué existe realmente en el harness.
---

# Skill — Harness Status

> **Cuándo usar:** Usuario invoca `/harness-status`, o quiere un inventario/diagnóstico de qué
> existe realmente en el harness (conteo de piezas, referencias rotas en el router).
> **Fase:** Esta skill cubre únicamente la Fase A del Issue #208 — salida en texto/tabla
> markdown dentro de la respuesta. La Fase B (visualización como HTML/artifact) es trabajo
> futuro, fuera del alcance de esta skill tal como está hoy.

---

## Qué Hace

1. Ejecuta `bash skills/observability/scripts/build-harness-inventory.sh` desde la raíz del
   repo.
2. El script cuenta, vía glob (sin dependencias externas más allá de git/grep/sed):
   - `AGENTS` — `agents/*.md`
   - `SKILLS` — `skills/*/SKILL.md`
   - `PROTOCOLS` — `protocols/*.md`
   - `RULES` — `.aura/rules/*.md` + `.claude/rules/*.md`
   - `COMMANDS` — `commands/*.md`
   - `HOOKS` — `.claude/hooks/*.ps1`
3. El script además recorre la tabla bajo `## Tabla de Routing` en `protocols/router.md` y,
   por cada ruta entre backticks en la columna "Archivos a cargar", verifica que el archivo
   exista en el repo. Si no existe, emite una línea `BROKEN-REF: <situación> → <ruta>`.
4. El agente toma la salida cruda del script (líneas `AGENTS: N`, `SKILLS: N`, etc., y
   cualquier `BROKEN-REF:` que aparezca) y la presenta al usuario como **tabla markdown**,
   más una sección aparte listando las referencias rotas (si las hay).

---

## Formato de Salida Esperado

```
## Inventario del Harness

| Categoría | Cantidad |
|-----------|----------|
| AGENTS    | N        |
| SKILLS    | N        |
| PROTOCOLS | N        |
| RULES     | N        |
| COMMANDS  | N        |
| HOOKS     | N        |

## Referencias Rotas en protocols/router.md
- <situación> → <ruta> (no existe)
```

Si no hay líneas `BROKEN-REF:`, reemplazar esa sección por:

```
## Referencias Rotas en protocols/router.md
Ninguna detectada.
```

---

## Reglas

1. **El script nunca se edita a mano** — `skills/observability/scripts/build-harness-inventory.sh`
   se regenera/mantiene como parte del Issue #208, Fase A. Esta skill solo lo invoca y
   formatea su salida; no reimplementa el conteo ni el parseo del router en prosa.
2. **Siempre correr desde la raíz del repo** — el script resuelve `REPO_ROOT` vía
   `git rev-parse --show-toplevel`, así que funciona desde cualquier cwd dentro del repo, pero
   se invoca tal cual, sin argumentos.
3. **Chequeo informativo, no bloqueante** — el script sale siempre con exit 0. Una
   `BROKEN-REF` no detiene ningún protocolo; es una señal para que el usuario decida si
   corregir la referencia o el archivo faltante.
4. **Sin HTML/artifact en esta fase** — no publicar un Artifact ni generar un archivo nuevo
   como parte de esta skill. La salida vive únicamente en la respuesta al usuario (Fase A).
