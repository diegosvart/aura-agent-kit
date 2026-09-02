---
name: repo-integrity
description: Detecta trabajo stranded (issue cerrado sin PR mergeada) y ramas que requieren limpieza. Invocada desde el Paso 3 de session_start.
---

# Skill — Repo Integrity Check

> **Cuándo usar:** Invocada desde Paso 3 de `protocols/session_start.md`.
> **Precondición:** `gh` autenticado (verificado en Paso 2). Si no está autenticado, omitir silenciosamente.
> **Límite:** Máximo 10 ramas candidatas para no extender el tiempo de session_start.

---

## Algoritmo de Detección

### Paso A — Identificar ramas candidatas

```bash
# Ramas locales con commits NO mergeados en develop (excluyendo main, develop, rama actual)
git branch --no-merged develop | grep -v "^\*\|main\|develop"
```

Tomar las primeras 10 (si hay más, indicarlo en el resumen).

### Pasos B, C y D — Clasificar cada rama candidata

Para cada rama candidata, invocar el script (no reconstruir en prosa):

```bash
skills/repo-integrity/scripts/classify-branch.sh <owner>/<repo> <rama>
```

El script encapsula:
- **Paso B** — busca en el mensaje completo (no solo el subject — el keyword suele ir en el
  body) de los commits exclusivos de la rama (`git log develop..<rama> --format=%B`) un patrón
  `Closes/Fixes/Resolves #N` (case-insensitive).
- **Paso C** — si hay match, `gh issue view <N> --json state`.
- **Paso D** — si el issue está `CLOSED`, `gh pr list --head <rama> --state merged` filtrando
  `baseRefName == develop`.

Salida por stdout (una sola línea, parseable):

| Salida | Significado | Acción |
|--------|-------------|--------|
| `CLEAN:no-issue-ref` | Sin referencia a issue en los commits exclusivos | No alertar |
| `CLEAN:issue-open:<N>` | Issue #N referenciado sigue abierto | No alertar |
| `CLEAN:merged:<N>:<PR>` | Issue #N cerrado, PR #PR mergeada hacia develop | No alertar |
| `STRANDED:<N>` | Issue #N cerrado, sin PR mergeada hacia develop | **Alertar y bloquear** |

Exit 0 en cualquier clasificación completada; exit 1 solo si falla una llamada real a `gh`
(la rama se trata entonces como "pendiente normal", ver Errores Comunes).

---

## Tabla de Clasificación

| Condición | Clasificación | Acción |
|-----------|--------------|--------|
| Rama ahead + issue ABIERTO | En progreso | No alertar |
| Rama ahead + sin referencias a issues | Pendiente normal | No alertar |
| Rama ahead + issue CERRADO + PR mergeada en develop | Limpio | No alertar |
| Rama ahead + issue CERRADO + SIN PR mergeada | **STRANDED** | Alertar y bloquear |

---

## Comportamiento ante Trabajo Stranded

Mostrar el siguiente bloque y **DETENERSE**. No continuar al Paso 4 hasta que el usuario decida:

```
## Alerta — Trabajo Stranded Detectado

La rama `<rama>` tiene el commit `<hash> <mensaje>` que dice cerrar Issue #N.
El Issue #N está CERRADO pero la rama NUNCA fue mergeada a develop via PR.
El código está stranded — el issue figura como "done" pero el trabajo no llegó a develop.

**¿Qué contiene esta rama?**
<git log develop..<rama> --oneline — mostrar los commits>

**Opciones:**
1. Recuperar el trabajo — crear PR ahora: `gh pr create --base develop --head <rama>`
2. Revisar el contenido — `git diff develop..<rama> --stat` para ver qué archivos
3. Descartar — el trabajo ya no sirve, eliminar rama
4. Ignorar por ahora — continuar la sesión (no recomendado)

¿Cuál elegís? (1/2/3/4)
```

### Según la respuesta del usuario:

| Opción | Acción |
|--------|--------|
| 1 — Recuperar | Ejecutar `gh pr create --base develop --head <rama>` y continuar al Paso 4 |
| 2 — Revisar | Mostrar `git diff develop..<rama> --stat` y esperar nueva decisión |
| 3 — Descartar | `git branch -d <rama>` (local) + `git push origin --delete <rama>` (remote si existe). Reabrir el issue si corresponde |
| 4 — Ignorar | Registrar en la sección "Advertencias" del Paso 6. Continuar al Paso 4 |

---

## Múltiples Ramas Stranded

Si hay más de una rama stranded, resolverlas secuencialmente antes de continuar.

---

## Output si todo está limpio

```
✓ Integridad repo-remote verificada — no hay trabajo stranded
```

Incluir esta línea en el bloque de "Salud de Ramas" del Paso 6.

---

## Errores comunes

| Error | Solución |
|-------|----------|
| `gh` no autenticado | Omitir este chequeo silenciosamente |
| Issue no encontrado (404) | Considerar la rama como "pendiente normal" |
| Rama remota sin tracking local | Omitir — solo chequear ramas con tracking local |
| `git log --oneline` no detecta `Closes #N` en el body | Bug real encontrado al scriptear el Paso B (Issue #71): la convención real (ver commit 21fd2e8 de este repo) escribe el keyword en el body del mensaje, no en el subject — `--oneline` solo muestra el subject y lo pierde. `classify-branch.sh` usa `git log --format=%B` (mensaje completo) en vez de `--oneline`. |
