# Skill — Agentic Dev Loop (desarrollo + verificación de issues)

> **Propósito:** Ejecutar issues `ready` con agentes, separando desarrollo (no supervisado) de
> verificación (nunca mergea sola). Reduce la atención humana requerida por issue a: aprobar el
> plan una vez, y decidir el merge al final.
> **Comando asociado:** `/run-dev-loop`
> **Spec / hipótesis:** `docs/aura/specs/2026-07-19-loop-dev-verificacion.md` (P4)
> **Precondición:** `gh` autenticado y con permisos de escritura (labels, comentarios, PRs) en
> `<OWNER>/<REPO>`. Si no está autenticado, no ejecutar — avisar y detenerse.

---

## Vocabulario de Labels

| Label | Significado | Quién lo pone | Excluye a |
|---|---|---|---|
| `ready` | Sin dependencias abiertas, libre para tomar | `issue-planning` / manual | los otros 4 |
| `blocked` | Depende de algo no resuelto (otro issue abierto, un repo externo) | manual / dev-runner | los otros 4 |
| `in-progress` | El dev-runner lo está trabajando ahora | dev-runner | los otros 4 |
| `review` | PR abierto, esperando auditoría | dev-runner al terminar | los otros 4 |
| `changes-requested` | La verificación encontró que no cumple el DoD | verifier | los otros 4 |

Un issue solo debe tener **uno** de estos cinco labels a la vez. Si un repo no tiene alguno de
estos labels todavía, crearlo antes de la primera corrida:
```bash
gh label create in-progress --repo <OWNER>/<REPO> --description "El dev-runner lo está trabajando" --color 0e8a16
gh label create review --repo <OWNER>/<REPO> --description "PR abierto, esperando auditoría" --color fbca04
gh label create changes-requested --repo <OWNER>/<REPO> --description "No cumple el DoD, requiere ajuste" --color d93f0b
```

---

## Precondición de contenido — ¿el issue es apto para el loop?

Antes de tomar un issue `ready`, confirmar que su body es **autocontenido**: objetivo, archivos
a tocar, criterio de éxito (DoD) explícito, y — si depende de otro issue — que esa dependencia
esté declarada en texto ("Depende de: Issue N"). Si el body es vago (sin DoD verificable, sin
archivos, requiere una decisión de diseño que no está tomada), **no tomarlo**: dejarlo `ready`
y señalar al usuario que necesita más detalle antes de entrar al loop (volver a
`issue-planning` si hace falta). Esto es lo que separa a un issue "loop-ready" de uno que solo
tiene el label `ready` por convención de `session_start`.

---

## Fase 1 — Dev-runner (desarrollo, no supervisado)

### Paso 1 — Elegir issue
```bash
gh issue list --repo <OWNER>/<REPO> --label ready --state open --json number,title,body --limit 30
gh issue list --repo <OWNER>/<REPO> --label in-progress --state open --json number
```
- Si ya hay un issue `in-progress` → **no tomar ninguno nuevo**, terminar esta fase (evita
  pisar una cadena de dependencias con corridas concurrentes).
- Si no: de los `ready`, elegir el de **menor número** cuyo "Depende de: Issue N" (si existe en
  el body) esté cerrado (`gh issue view N --json state -q .state` → `CLOSED`). Saltar los que
  tengan una dependencia abierta (deberían tener `blocked`, no `ready` — si aparece uno así,
  corregir el label a `blocked` y seguir con el próximo).

### Paso 2 — Marcar in-progress (antes de lanzar el agente)
```bash
gh issue edit <N> --repo <OWNER>/<REPO> --remove-label ready --add-label in-progress
```

### Paso 3 — Resolver tier de modelo (D3 de la spec)
- Default: **Haiku**.
- Si el body del issue trae `**Complejidad:** alta` (o similar marca explícita de
  `issue-planning`) → arrancar directo en **Sonnet**.
- Si un intento previo en este mismo issue fue registrado como fallido (comentario del
  dev-runner en el issue) → escalar al siguiente tier (Haiku→Sonnet→Opus) en el reintento.

### Paso 4 — Lanzar el agente de desarrollo
Prompt autocontenido (el agente parte de cero — sin memoria de esta sesión):
- Body completo del issue (ya trae objetivo, archivos, tareas RED→GREEN, DoD).
- Comandos de verificación resueltos desde `.agent/memory/session-stack.json` (lint, typecheck
  si aplica, test) — nunca asumir `ruff`/`pytest` a menos que el stack lo confirme.
- Instrucciones operativas:
  1. `git fetch && git checkout develop && git pull && git checkout -b feature/issue-<N>-<slug-corto>`.
  2. Implementar **exactamente** las tareas listadas (RED→GREEN si el issue las trae así), sin
     tocar archivos fuera de la lista "Archivos" salvo que el DoD lo exija explícitamente.
  3. Correr lint/typecheck/test; deben quedar verdes antes de commitear (tests gateados por
     entorno real, ej. `@skipif`, se respetan tal cual están — no forzarlos a correr).
  4. Commit con mensaje convencional, push a la rama remota.
  5. Abrir PR hacia `develop` con `Closes #<N>` en el body y un resumen de los cambios.
  6. Si en algún punto queda bloqueado (dependencia no resuelta que no se había detectado,
     ambigüedad real del DoD): **no commitear a medias** — comentar en el issue qué falta y
     terminar sin PR.

### Paso 5 — Cerrar el ciclo
- **Si el agente abrió PR:** `gh issue edit <N> --remove-label in-progress --add-label review`.
- **Si el agente no abrió PR (bloqueo):** `gh issue edit <N> --remove-label in-progress --add-label ready` (o `blocked` si identificó una dependencia real) y confirmar que el comentario de bloqueo quedó en el issue.

---

## Fase 2 — Verifier (auditoría, nunca mergea sola)

Se dispara igual por cron que a demanda ("cerré/revisá el issue N").

### Paso 1 — Ubicar candidatos
```bash
gh issue list --repo <OWNER>/<REPO> --label review --state open --json number,title,body
```
O, si el usuario indica un issue puntual, usar ese directamente aunque no tenga el label
`review` todavía (caso "cerré el issue a mano, revisalo").

### Paso 2 — Ubicar el PR asociado
```bash
gh pr list --repo <OWNER>/<REPO> --search "Closes #<N>" --json number,headRefName,state
# fallback si el texto de Closes no matchea la búsqueda:
gh pr list --repo <OWNER>/<REPO> --head feature/issue-<N>- --json number
```

### Paso 3 — Auditar (mismo método que un code review manual)
No confiar en el resumen del PR. Para cada tarea del DoD del issue:
1. Leer el diff real (`git diff develop..<rama> -- <archivos>` o `gh pr diff <N>`).
2. Confirmar que el comportamiento descrito existe en el código, no solo que se tocó el
   archivo correcto.
3. Correr lint/typecheck/test localmente sobre la rama (comandos resueltos vía
   `session-stack.json`, igual que en la Fase 1).
4. Listar hallazgos concretos (archivo, línea, qué falla) si algo no cumple.

### Paso 4 — Veredicto
- **Pasa (sin hallazgos bloqueantes):** comentar en el PR/issue "DoD cumplido, listo para
  mergear" con un resumen de lo verificado; notificar al usuario. **No mergear** — el usuario
  decide y ejecuta el merge.
- **No pasa:** comentar los hallazgos concretos (qué falta, con evidencia), 
  `gh issue edit <N> --remove-label review --add-label changes-requested`, y si el issue ya
  estaba cerrado (cierre prematuro vía un merge que no debió pasar), reabrirlo
  (`gh issue reopen <N>`).

---

## Regla de Concurrencia

Un solo issue `in-progress` por vez en todo el repo (Fase 1, Paso 1). La Fase 2 sí puede auditar
varios issues `review` en la misma corrida — auditar no muta código, solo lee y comenta.

---

## Errores Comunes

| Error | Solución |
|---|---|
| Dos labels de flujo en el mismo issue | Corregir a mano antes de la próxima corrida — señal de que algo pisó un label a mitad de camino |
| Issue `ready` con dependencia abierta | Corregir a `blocked`, no confiar en que el dev-runner lo detecte siempre |
| `gh` no autenticado en corrida programada (cron/headless) | Las integraciones autenticadas interactivamente pueden no estar disponibles en ejecuciones remotas — validar esto manualmente antes de programar el cron, no asumir que funciona igual que en sesión interactiva |
| El dev-runner abre PR pero no pushea (o viceversa) | Tratar como fallo — el issue debe quedar `ready`/`blocked` con comentario, nunca `review` sin PR real |

---

## Extensión futura — ejecutor intercambiable

El contrato de la Fase 1 es *"dado el body autocontenido de un issue → producir una rama + PR
que lo cierre"*. Cualquier backend de desarrollo automatizado que cumpla ese contrato podría
reemplazar al agente Haiku/Sonnet sin cambiar la Fase 2. Hoy el único ejecutor soportado es un
agente Claude vía la herramienta de agentes del entorno — no hay integración con otros
productos de desarrollo automatizado.
