# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-07-30

### Fixed
- Fix de permisos: usar `Edit(...)` en vez de `Write(...)` para reglas deny de secretos en `.claude/settings.json` e `integrations/claude-code/settings.json` (commit 1bca309)
- Fix de dependency-parsing en `pick-next-issue.sh`: resolvía dependencias reales correctamente (commit 25c73b9)

### Added
- Bootstrap de versionado del harness con CHANGELOG.md y git tags (v1.4.0)
