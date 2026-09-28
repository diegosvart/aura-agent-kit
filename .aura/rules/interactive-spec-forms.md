# Interactive Spec Forms — Formulario HTML local para decisiones tipo matriz

## Regla principal

Cuando la recolección de una spec requiere **muchas decisiones discretas de tipo
matriz** (N ítems × M opciones — ej. "para cada uno de 5 pantallas, qué hacer con cada
uno de ~13 controles"), no usar preguntas secuenciales una por una. En su lugar, generar
un **formulario HTML local autocontenido** que el usuario completa en su propio
navegador y cuyo resultado (un JSON estructurado) se pega de vuelta en el chat como
entrada del siguiente paso (spec, plan, etc.).

Para una sola pregunta con pocas opciones, seguir usando `AskUserQuestion` — este
patrón es específicamente para matrices grandes donde la alternativa secuencial es lenta
e improductiva.

---

## Regla dura — nunca publicar, siempre gitignored

El archivo HTML generado **SIEMPRE** se guarda en una ruta gitignored del proyecto
consumidor (convención: `output/`), **NUNCA** se publica con la herramienta `Artifact`
(`action: "publish"` o `"pin"`).

- Antes de usar este patrón, confirmar que el proyecto tiene:
  1. Una regla de "no publicar Artifacts" (ver `.claude/rules/no-artifact-publishing.md`
     si existe en el proyecto consumidor), o al menos el criterio explícito de este
     archivo aplicado igual aunque no exista esa regla local.
  2. `output/` (o el path equivalente que se use) agregado al `.gitignore` del repo
     consumidor.
  Si falta alguna de las dos, agregarla primero — no generar el formulario sin esa base.
- El agente nunca abre el archivo por el usuario ni lo publica externamente: solo indica
  la ruta exacta para que el usuario lo abra localmente (doble clic, o
  `start output/<archivo>.html` / equivalente del SO).
- Ninguna excepción por "es solo un form interno" o "no tiene datos sensibles" — la
  publicación en sí (no el contenido) es lo que esta regla prohíbe, mismo criterio que
  `no-artifact-publishing.md`.

---

## Pasos del patrón

1. **Inventario real primero.** Nunca inventar opciones, controles o valores por
   defecto. Investigar el código/dominio real (lectura directa o subagente de
   investigación) y construir el inventario a partir de eso — es lo que alimenta las
   opciones y los valores pre-marcados del formulario.
2. **HTML autocontenido, vanilla JS, sin dependencias externas.** Una sección por
   ítem/pantalla, con las opciones existentes pre-marcadas con una recomendación
   razonable derivada del inventario (pero siempre editable), más la posibilidad de
   agregar ítems nuevos que el inventario no contemplaba.
3. **Botón "Generar resumen"** que arma un JSON con todas las decisiones tomadas y lo
   muestra en un `<textarea>` visible, más un botón "Copiar al portapapeles" para
   facilitar el paso siguiente.
4. **El usuario pega el JSON de vuelta en el chat** — esa es la entrada real para
   escribir el artefacto siguiente (spec, plan, issue). El agente no infiere ni
   completa decisiones que el formulario no devolvió.

---

## Por qué existe esta regla

Recolectar N×M decisiones discretas por preguntas secuenciales (`AskUserQuestion` una
por una, o texto libre turno a turno) es lento, cansador para el usuario y propenso a
inconsistencia entre ítems similares. Un formulario con opciones pre-marcadas
razonablemente reduce la carga a revisar/corregir en vez de decidir desde cero cada
celda de la matriz, sin perder la superficie de auditoría de una spec escrita a partir
de decisiones explícitas del usuario (no inventadas por el agente).

Validado en sesión real (2026-09-28, proyecto `ebi-insight-power-apps`): spec de un
footer global (`cmpFooterApp`) con 5 pantallas y ~13 controles existentes, usando
`output/footer-spec-form.html` como entrada intermedia hacia
`docs/aura/specs/2026-09-28-footer-global-cmpfooterapp-design.md`.

---

## Cuándo NO usar este patrón

- Una sola decisión, o pocas decisiones independientes sin estructura de matriz →
  `AskUserQuestion`.
- La decisión requiere iteración conversacional (el usuario no tiene todavía un
  criterio claro y necesita pensarlo en voz alta) → seguir con preguntas secuenciales o
  `/brainstorm`.
- El proyecto no tiene forma de gitignorear el archivo de salida (ej. no hay control de
  versiones, o no se puede editar `.gitignore`) → no generar el formulario hasta
  resolver eso.
