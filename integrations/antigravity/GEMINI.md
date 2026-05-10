# Aura Agent Kit — Antigravity Override

> Primary harness rules are in `AGENTS.md` (read natively by Antigravity v1.20.3+).
> This file adds Antigravity-specific permissions and overrides only.

---

## Tool Permissions

Allow:
- Bash(git:*)
- Bash(gh:*)
- Bash(python:*)
- Bash(node:*)
- Bash(npm:*)
- Bash(cargo:*)
- Read(**)
- Write(src/**)
- Write(docs/**)
- Write(.agent/**)

Deny:
- Bash(rm -rf:*)
- Write(.env:*)
- Write(*.key:*)
- Write(*.pem:*)

---

## Reminder

Full harness identity, pillars, workflow, and routing → `AGENTS.md`
