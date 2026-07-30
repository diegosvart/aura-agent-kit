# Comando — /harness-update

> **Invoca:** `skills/harness-update/SKILL.md`
> **Cuándo usar:** Para actualizar el harness a la versión más reciente disponible.

---

## Qué Hace

1. Detecta la versión más reciente disponible del harness (`aura-agent-kit`)
2. Muestra qué cambios se incluyen (entradas de CHANGELOG)
3. A pedido del usuario, aplica la actualización:
   - Checkout del nuevo tag en `.aura/`
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

- `.aura/` debe ser un checkout git (git submodule) del harness
- Si `.aura/` no existe o no es un git checkout, el comando avisa pero no falla

## Flujo Típico

```
1. Usuario ve en session_start: "⚠ Harness vX.Y.Z disponible (actual: vA.B.C)"
2. Usuario ejecuta /harness-update
3. Skill muestra CHANGELOG para vX.Y.Z
4. Usuario confirma
5. Skill ejecuta apply-update.sh
6. Hooks y CLAUDE.md se actualizan (sobreescritura directa, sin confirmación)
7. Resumen de cambios se imprime
8. Repo sigue funcionando con el harness actualizado
```

## Notas

- **Directo, sin diff-and-ask:** los hooks se sobreescriben directamente sin mostrar
  diferencias (son 100% del harness, no hay customización legítima por repo)
- **Cualquier necesidad local:** usa `.claude/settings.local.json` o `AGENTS.local.md`,
  nunca edites `.claude/hooks/*.ps1` directo
