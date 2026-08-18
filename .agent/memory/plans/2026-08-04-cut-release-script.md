---
status: done
pr: 137
commit: dd66cef
completed_at: 2026-08-04
---

# Plan — Deterministic release tooling + git-guard exemption acotada

## Contexto

`git-guard.ps1` bloqueó dos releases (v2.2.0 y v2.2.1) al pushear el tag estando en `main`.
Investigación confirmó que `.githooks/pre-push` (git nativo, basado en refs reales) ya permite
tags correctamente — el único bloqueo indebido venía de `git-guard.ps1` (PreToolUse, texto).

## Resultado final (difiere del enfoque original aprobado)

Se aprobó agregar una excepción angosta en `git-guard.ps1` para la invocación literal de
`cut-release.sh`. Al implementarla y probarla en vivo se descubrió que era **innecesaria**
(el comando externo que invoca al script nunca contiene `git push` literal — `PreToolUse` ya
lo dejaba pasar sin ninguna excepción) y **insegura** (un `git push origin main` real
disfrazado con un comentario mencionando el nombre del script se colaba con la excepción
puesta, confirmado con una prueba real). Se revirtió la excepción por completo.

## Qué se implementó

- `skills/agentic-dev-loop/scripts/cut-release.sh` — 4 subcomandos idempotentes
  (`changelog-pr`, `promote`, `tag`, `sync-back`) que reemplazan el Proceso de Release en
  prosa de `agents/github.md`.
- `agents/github.md` — sección Proceso de Release actualizada para invocar el script, más
  nota explicando por qué no hizo falta tocar `git-guard.ps1`.
- Self-check de rama documentado en `agents/github.md` (Convenciones), con exclusión
  explícita del flujo de release.
- Idea `[018]` registrada en `.agent/memory/ideas.md`: router de flujos determinísticos por
  tipo de operación — la conclusión de fondo de esta investigación.

## Archivos clave
- `skills/agentic-dev-loop/scripts/cut-release.sh`
- `agents/github.md`
- `.agent/memory/ideas.md`
