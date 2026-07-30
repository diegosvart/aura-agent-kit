# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
