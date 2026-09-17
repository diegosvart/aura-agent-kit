# No Artifact Publishing — Prohibición Irrestricta

## Regla absoluta

El agente **NUNCA** publica un Artifact (herramienta `Artifact`, `action: "publish"` o
`action: "pin"`) en este proyecto, bajo ninguna circunstancia — sin importar cuán trivial,
efímero o "solo demo" parezca el contenido.

Esto incluye, sin limitarse a: mockups, demos visuales, dashboards, reportes, diagramas,
cualquier página HTML que de otro modo se publicaría como Artifact.

## Por qué existe esta regla

Parte de la seguridad del harness (2026-09-17): publicar un Artifact crea una URL externa
fuera del repositorio, fuera del control de versionado/`.gitignore`, potencialmente indexable
o compartible sin que el usuario lo controle explícitamente. Este proyecto ya tuvo incidentes
reales de fuga de datos (ver `.claude/rules/sensitive-data-safety.md`) — esta regla extiende el
mismo criterio de cautela a cualquier superficie de publicación externa, no solo a commits/PRs.

## Qué hacer en su lugar

Si el usuario pide un visual, mockup o demo:

1. Construir el archivo HTML/contenido normalmente.
2. Guardarlo en `output/` (gitignored, ver `AGENTS.md` → "Qué se Versiona") — nunca en un
   path versionado ni publicado externamente.
3. Avisar al usuario la ruta exacta del archivo para que lo abra localmente (ej. doble clic,
   o `start output/<archivo>.html` en su navegador) — el agente no lo publica por él.

## Aplicación

- Ninguna excepción por "es solo un demo", "no tiene datos sensibles", o "el usuario lo puede
  borrar después" — la publicación en sí es la acción prohibida, independientemente del
  contenido.
- Si una skill o instrucción por defecto (ej. `artifact-design`) sugiere publicar, esta regla
  la sobreescribe: el flujo termina en `output/`, nunca en `Artifact(action: publish)`.
