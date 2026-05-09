# Aura Conventions — Aider

## Git

- NEVER commit directly to `develop` or `main`
- Branch from `develop`: `feature/issue-N-description`
- Conventional commits ALWAYS: `feat:` `fix:` `chore:` `docs:` `refactor:` `test:` `ci:`
- One issue = one branch = one PR

## Code

- TDD: write the failing test first, verify it fails, then implement
- Design before code: no implementation without an approved spec
- Stack-agnostic: detect linter/test runner from project files, never hardcode

## Files

- Never modify `.env`, `*.key`, `*.pem`, `credentials.json`
- Docs in `docs/aura/specs/` (specs) and `docs/aura/plans/` (plans)
- Session memory in `.agent/memory/current-session.json`

## CLI Preference

- Use `gh` CLI for GitHub operations (issues, PRs, merge)
- Use `git` CLI for all VCS operations
- Avoid MCP GitHub when `gh` covers the task

## Full harness

Read `AGENTS.md` for complete identity, pillars, and routing.
