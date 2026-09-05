# Objetivos — Aura Agent Kit

> Norte (largo plazo) vs ASAP (bloqueante ahora). Se edita in-place, no es append-only.

---

## ASAP — Backlog priorizado (2026-09-05)

Priorización acordada con el usuario tras la sesión que descubrió: (a) la regla irrompible
de no trabajar en worktrees (el harness no funciona correctamente ahí — evidencia real:
Issues #213/#214, contaminación de checkout entre subagentes concurrentes), y (b)
`delegation_rate = 0/10` real (primer dato desde que existe la regla, Issue #179/#205).

**El usuario va a abrir los PRs manualmente** a partir de acá — no asumir que hay trabajo
de implementación en curso delegado, verificar estado real de cada issue antes de actuar.

### P0 — Bloqueante estructural
- **#217** — `agentic-dev-loop` sin `isolation:"worktree"` (spec lista: serializar + lock de
  checkout). Nada que use `/run-dev-loop` es seguro hasta esto. **Probar primero en el
  sandbox** (`diegosvart/aura-agent-kit-sandbox`, creado hoy) antes de tocar el repo real.

### P1 — Bugs con evidencia real de la sesión del 2026-09-05
- **#148** (rojo) — `gh pr create` sin `--base` (3er incidente). El usuario ya lo marcó máxima
  prioridad; pide solución estructural, no otro parche de texto.
- **#213** — current-session.json stale en sesiones background. Insight nuevo: el
  workaround "Bash en vez de Write" (usado para #205/#214/este mismo archivo) probablemente
  lo resuelve sin necesitar la P4 completa que el issue pide.
- **#196** — apply-update.sh confunde estados. Afecta a todos los proyectos consumidores
  del harness, no solo este repo.

### P2 — Visibilidad del harness (el gap de fondo que motivó la sesión)
- **#206** — log de errores de proceso (idea 021). Justificado con casos reales del mismo
  día (colisión de branch entre subagentes, worktree con fix atrapado, 2 falsos positivos
  de `git-guard.ps1`).
- **#207** — auto-declaración en trigger de router.md. Ya no es hipotético: `delegation_rate
  = 0/10` (PR #215) lo confirma.
- **#208 → #209** — `/harness-status` (idea 022 Fase A), cierra #147 automáticamente al
  implementarse.
- **#199** — sandbox ya creado (`diegosvart/aura-agent-kit-sandbox`). Falta completar Fase 0
  del plan (`~/.claude/plans/genera-un-plan-para-happy-babbage.md`): el usuario corre
  manualmente el push del mirror (bloqueado por falso positivo de `git-guard.ps1` al
  ejecutarlo el agente, ver Engram `bug/git-guard-false-positive-cross-repo`).

### P3 — Menores, bajo esfuerzo
- #155 (deny-pattern bloquea `.env.example`)
- #147 (se cierra solo con #209, o standalone)
- #142 (redacción, no ejecución, de DCL para test manual)

### P4 — Depende de lo anterior
- #210 — ampliar `agentic-dev-loop` a más tipos de trabajo. Depende de #217 implementado y
  probado (idealmente en el sandbox).
- #156 — verificación post-instalación de hooks. Bajo impacto, puede esperar.

## Housekeeping ya resuelto hoy (no repetir)
- #197, #161 cerrados (duplicado / postmortem ya corregido en PR #166).
- PR #215 (Issue #205) y PR #216 (Issue #214) abiertos — verificar si el usuario ya los
  mergeó antes de asumir que siguen pendientes.
- Sandbox `diegosvart/aura-agent-kit-sandbox` creado (repo vacío, falta el push del mirror).

---

## Norte (largo plazo)

(sin definir aún — este archivo se creó recién en esta sesión, 2026-09-05)
