# Comando — /harness-update

> **Invoca:** `skills/harness-update/SKILL.md`
> **Cuándo usar:** Para actualizar el harness a la versión más reciente disponible.

---

## Qué Hace

1. Detecta la versión más reciente disponible del harness (`aura-agent-kit`), sin importar
   si se instaló como submodule (`.aura/`) o como plugin de Claude Code (marketplace) —
   detección automática de canal, ver ADR-009
2. Muestra qué cambios se incluyen (entradas de CHANGELOG)
3. A pedido del usuario, aplica la actualización:
   - Submodule: checkout del nuevo tag en `.aura/`
   - Plugin: `claude plugin marketplace update` + `claude plugin update <id>` (requiere
     reiniciar la sesión de Claude Code para que el contenido nuevo tome efecto)
   - Copia de hooks actualizados (`.claude/hooks/*.ps1`)
   - Resincronización del bloque `CLAUDE.md`
   - Resumen de lo que se tocó

## Cuándo Usar

- **Automático (aviso sin costo):** `/harness-update` aparece en el menú de `session_start` si hay
  una versión más reciente disponible
- **Manual:** cuando el usuario decide explícitamente actualizar
  ```bash
  /harness-update
  ```

## Precondición

- `.aura/` como checkout git (git submodule) del harness, **o** el plugin `aura` instalado
  vía `claude plugin install` con su marketplace ya registrado (ver `QUICKSTART.md` Opción C)
- Si ninguno de los dos aplica, el comando avisa pero no falla

## Flujo Típico

```
1. Usuario ve en session_start: "⚠ Harness vX.Y.Z disponible (actual: vA.B.C)"
2. Usuario ejecuta /harness-update
3. Skill muestra CHANGELOG para vX.Y.Z
4. Usuario confirma
5. Skill ejecuta apply-update.sh
6. Hooks y CLAUDE.md se actualizan (sobreescritura directa, sin confirmación)
7. Resumen de cambios se imprime
8. Repo sigue funcionando con el harness actualizado (canal plugin: reiniciar la sesión de
   Claude Code para que el contenido nuevo tome efecto)
```

## Notas

- **Directo, sin diff-and-ask:** los hooks se sobreescriben directamente sin mostrar
  diferencias (son 100% del harness, no hay customización legítima por repo)
- **Cualquier necesidad local:** usa `.claude/settings.local.json` o `AGENTS.local.md`,
  nunca edites `.claude/hooks/*.ps1` directo
