# Aura Agent Kit — Claude Code

> **Este archivo es el punto de entrada del harness para Claude Code.**
> El harness completo vive en `AGENTS.md`. Este archivo carga el contexto necesario.

---

## Instrucciones de Carga

Al iniciar cualquier sesión en este proyecto, leer en orden:

1. `AGENTS.md` — identidad, pilares y router (siempre)
2. `protocols/router.md` — tabla de routing para saber qué cargar según el contexto
3. Según el router, cargar los archivos correspondientes a la situación actual

## Configuración de Permisos

Ver `.claude/settings.json` para permisos de herramientas.

## MCP Requerido

```json
{
  "mcpServers": {
    "engram": {
      "type": "stdio",
      "command": "engram",
      "args": ["mcp", "--tools=agent"]
    }
  }
}
```

Engram es obligatorio para memoria persistente entre sesiones (P5 del harness).

## Primer Paso

Una vez instalado, ejecutar el protocolo de inicio:
→ Leer `protocols/session_start.md`
