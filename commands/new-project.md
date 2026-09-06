# Comando — /new-project

> **Invoca:** `skills/new-project-setup/SKILL.md`
> **Cuándo usar:** Cuando el usuario quiere iniciar un repositorio nuevo con el harness Aura instalado de punta a punta, listo para arrancar `claude .` desde ahí.

---

## Qué Hace

1. Recolecta las decisiones del Paso 0 de la skill (repo remoto, directorio local, canal de
   instalación, stack, identidad, rama default, reglas opt-in) — una por una si el usuario no
   las dio todas.
2. Verifica prerrequisitos (repo remoto existe/vacío, directorio local libre).
3. Clona el repo y scaffoldea el harness (submodule pinneado a un tag, o plugin sin vendorizar).
4. Escribe `AGENTS.local.md`, `.gitignore`, `.claude/settings.json` con hooks, y
   `session-stack.json`.
5. Hace el primer commit y push.
6. Verifica el resultado y hace handoff: informa que ya se puede correr `claude .` en el
   proyecto nuevo.

---

## Cuándo Usar

- El usuario quiere crear/iniciar un proyecto nuevo con Aura instalado
- El usuario da una URL de un repo de GitHub (existente y vacío, o a crear) y pide dejarlo listo
- Router: caso compuesto "Proyecto nuevo desde cero" de `protocols/router.md`

**No usar para** agregar el harness a un repo que ya tiene código e historial — ese caso es
`install.sh`/`QUICKSTART.md` directo (append-only sobre `CLAUDE.md` existente).

---

## Uso

```
/new-project
/new-project https://github.com/<owner>/<repo>.git
```

Con o sin URL del repo — si no se da, se pregunta en el Paso 0 de la skill.

---

## Proceso

```
Usuario pide proyecto nuevo (con o sin URL)
    ↓
Agente recolecta las 7 decisiones del Paso 0 (una por una)
    ↓
Verificación de prerrequisitos (repo remoto, directorio local)
    ↓
Clonado + scaffold del harness (submodule/plugin) + identidad + hooks + gitignore + stack
    ↓
Primer commit + push
    ↓
Verificación (submodule pinneado, plugin registrado, commit en origin, AGENTS.local.md bien ubicado)
    ↓
Handoff: "ya podés correr claude . en el proyecto nuevo"
```

**No ejecutar nada sin confirmación del usuario en cada decisión del Paso 0** — esta skill
scaffoldea un repo real, no es reversible sin limpieza manual.
