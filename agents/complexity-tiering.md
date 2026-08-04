# Agente — Tiering de Modelo por Complejidad de Tarea

> **Propósito:** Elegir el tier de modelo (Haiku/Sonnet/Opus) antes de lanzar un agente,
> también fuera de `agentic-dev-loop`. Evita pagar tier alto por trabajo mecánico y evita
> subestimar trabajo ambiguo con un tier bajo.
> **Relación con `agentic-dev-loop`:** ese skill ya resuelve esto de forma determinística
> para issues de GitHub vía `skills/agentic-dev-loop/scripts/resolve-tier.sh` (lee el body y
> los comentarios del issue). Esta guía es la versión **generalizada** para cualquier otro
> momento en que un orquestador lanza un agente ad-hoc y no hay un issue de GitHub con
> `**Complejidad:**` ya declarada para grepear — challenger, doc-guardian, reviewer,
> orquestación manual de un bloque de trabajo repetitivo, etc.

---

## Por qué existe esta guía

Detectado en `crawler-mcp-diagram` (2026-08-03): un bloque de 11 issues de vistas SQL
Cash Flow — trabajo mecánico y repetitivo (clonar una plantilla ya validada, ajustar
cuenta/filtro, correr dos scripts de validación ya existentes, cerrar el issue) — se
implementó lanzando 11 agentes en tier default (sin tiering) porque el trabajo no pasó por
`agentic-dev-loop` (sin branch+PR real: los `.sql` de entrega vivían en un directorio
gitignored, así que el flujo formal del loop no aplicaba). Costo real: ~1.045.000 tokens /
285 tool calls para tareas que, por el propio criterio de `resolve-tier.sh` (sin
`**Complejidad:** alta`, sin comentarios previos de bloqueo), habrían calificado para tier
Haiku. Ver `docs/aura/experiments/2026-08-04-tiering-fuera-del-loop.md`.

---

## Señales para elegir tier

| Señal | Tier sugerido |
|---|---|
| Tarea mecánica: clonar/adaptar un artefacto ya validado (plantilla, script, query) siguiendo un patrón explícito y repetido ≥2 veces antes en la misma sesión | **Haiku** |
| Ejecutar y verificar un comando/script ya existente contra un resultado esperado conocido | **Haiku** |
| Tarea con ambigüedad real de diseño, o que requiere decidir entre 2+ enfoques válidos | **Sonnet** |
| Tarea que ya falló o quedó bloqueada una vez (mismo criterio que `resolve-tier.sh`: 1 intento fallido previo) | **Sonnet** |
| Cambios de arquitectura, lectura/síntesis de múltiples fuentes contradictorias, o 2+ intentos previos fallidos | **Opus** |
| No hay señal clara / es la primera vez que se hace algo así en el repo | **Sonnet** (default seguro cuando no aplica ninguna señal de la tabla) |

**Nota:** a diferencia de `resolve-tier.sh` (que usa Haiku como default porque parte de un
issue ya diseñado y con AC explícitos), acá el default cuando no hay señal clara es
**Sonnet** — sin un issue estructurado de por medio, asumir "mecánico" por defecto es más
riesgoso.

---

## Cómo aplicarlo

1. Antes de lanzar un agente (`Agent` tool o equivalente), clasificar la tarea contra la
   tabla de arriba en una oración («esto es N instancias del mismo patrón mecánico ya
   validado» / «esto requiere una decisión de diseño no tomada todavía»).
2. Pasar `model` explícito en la llamada al agente si el tier elegido no es el default de la
   sesión.
3. Si el bloque de trabajo tiene 3+ instancias del mismo patrón (como el caso de las 11
   vistas Cash Flow), la clasificación se hace **una vez** para todo el bloque, no por cada
   instancia — no vale la pena re-evaluar tier ítem por ítem si el patrón es idéntico.
4. Registrar el consumo real (`<usage>` de la notificación del agente) igual que pide el
   Paso 5.5 de `agentic-dev-loop` — también fuera del loop formal. Sirve para calibrar esta
   tabla con datos reales de sesiones futuras.

---

## Qué NO resuelve esta guía

- No reemplaza `resolve-tier.sh` dentro de `agentic-dev-loop` — ahí seguir usando el script,
  es determinístico y ya está probado.
- No es una política dura de costos — es una heurística para no gastar tier alto por default
  en trabajo mecánico. Si hay duda genuina sobre la complejidad, subir de tier es más seguro
  que forzar Haiku en algo ambiguo.
