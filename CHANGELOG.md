# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.1] - 2026-08-02

### Fixed
- `session-start.ps1` detectaba `.aura/` como git submodule (Issue #94) pero seguía resolviendo
  `check-update.sh` con `$projectRoot` en vez de `$auraPath` — el script solo existe dentro de
  `.aura/skills/...` en cualquier consumidor, por lo que la detección de actualizaciones nunca
  se ejecutaba en la práctica (Issue #96, PR #97)
- `SKILL.md` de `harness-update`: corregida la ruta documentada de invocación de
  `apply-update.sh` (vive en `.aura/`, no en la raíz del consumidor) (PR #97)

### Changed
- TTL de cache de detección de actualizaciones bajado de 6h a 30min — el chequeo corre fuera
  del contexto de Claude (subproceso del hook `SessionStart`) y no consume tokens del agente;
  el único costo real es la latencia de red del `git fetch --tags`, que no justifica esperar
  6h para detectar una actualización disponible (PR #97)

## [2.1.0] - 2026-08-02

### Added
- Infraestructura ADR (`docs/aura/adr/`): template, registro e integración obligatoria
  (feat/docs) u opcional (chore/fix) en el flujo de `finish-branch` (Issues #33/#34, PRs #85/#86)
- Política de versionado de artefactos del harness formalizada en `AGENTS.md` ("Qué se
  Versiona"), reforzando `sensitive-data-safety.md` para el ledger de planes (Issue #38, PR #87)
- Barrido de scripting determinístico (idea [016]): `classify-branch.sh` (Issue #71, PR #72),
  `post-merge.sh` (Issue #74, PR #75), `apply-branch-protection.sh` (Issue #76, PR #77),
  `new-branch-for-issue.sh` (Issue #78, PR #79)
- Git hooks nativos: `.githooks/pre-push` bloquea push directo a `develop`/`main` como segunda
  capa de enforcement independiente de Claude Code, con auto-setup de `core.hooksPath` en
  `session-start.ps1` (Issue #80, PR #81)
- `agentic-dev-loop`: apertura de PR y rechazo de review scripteados, con hardening de
  enforcement (PR #69)

### Fixed
- `apply-update.sh` ahora sincroniza correctamente las reglas `Write`→`Edit` de
  `settings.json` a repos consumidores (PR #63)
- `context-guard.ps1`: timeout defensivo del hook `UserPromptSubmit` subido de 5s a 10s
  (Issue #35, PR #84)

## [2.0.0] - 2026-07-30

### Added
- Skill `harness-update` completo: detección y aplicación de actualizaciones del harness vía
  `/harness-update` (scripts `check-update.sh` / `apply-update.sh`) (Issue #45, PR #53)
- `session-start.ps1` expone `harness_update_available`/`harness_latest_version`, cacheado con
  TTL de 6h, sin fallar sin red o sin `.aura/` (Issue #46, PR #58)

### Fixed
- Hardening de `apply-update.sh` contra 3 fallas silenciosas: propagación de errores de Python al
  exit code del script, paso correcto de argumentos posicionales a los bloques heredoc (Issue #55, PR #56)
- Regex de "Depende de" en `pick-next-issue.sh` sin anclar a heading/bullet, causaba falsos
  positivos con el texto libre del issue (PR #50)
- Resolución explícita de `bash.exe` de Git for Windows en `session-start.ps1` — en máquinas con
  WSL instalado, `Get-Command bash` puede resolver al relay de System32 y fallar en silencio sin
  distro configurada (PR #58)

## [1.4.0] - 2026-07-30

### Fixed
- Fix de permisos: usar `Edit(...)` en vez de `Write(...)` para reglas deny de secretos en `.claude/settings.json` e `integrations/claude-code/settings.json` (commit 1bca309)
- Fix de dependency-parsing en `pick-next-issue.sh`: resolvía dependencias reales correctamente (commit 25c73b9)

### Added
- Bootstrap de versionado del harness con CHANGELOG.md y git tags (v1.4.0)
