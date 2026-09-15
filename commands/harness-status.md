# Comando — /harness-status

> **Invoca:** `skills/harness-status/SKILL.md`
> **Cuándo usar:** Cuando el usuario quiere un inventario de qué existe realmente en el
> harness (conteo de AGENTS/SKILLS/PROTOCOLS/RULES/COMMANDS/HOOKS) o detectar referencias
> rotas en la tabla de routing de `protocols/router.md`.

---

## Qué Hace

1. Corre `bash skills/observability/scripts/build-harness-inventory.sh` desde la raíz del
   repo.
2. Presenta la salida del script como tabla markdown (conteos por categoría) más una sección
   con las líneas `BROKEN-REF:` detectadas, si las hay.

---

## Alcance

Fase A del Issue #208 — salida solo en texto/tabla dentro de la respuesta. Sin HTML ni
Artifact (eso es Fase B, futura, fuera del alcance de este comando por ahora). El script se
regenera en cada invocación; nunca se edita a mano.
