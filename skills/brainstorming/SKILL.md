---
name: brainstorming
description: Use before any creative work - creating features, building components, or modifying behavior.
---

# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs and specs through collaborative dialogue.

Start by understanding the current project context, then ask questions to refine the idea.

## Checklist

Complete these in order:

1. **Explore project context** — check files, docs, recent commits
2. **Ask clarifying questions** — one at a time, understand purpose/constraints
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design** — in sections, get user approval after each
5. **Write design doc** — save to `docs/aura/specs/YYYY-MM-DD-<topic>-design.md`
6. **Spec self-review** — check for placeholders, contradictions, scope
7. **User reviews written spec** — ask user to review before proceeding
8. **Transition to implementation** — preguntar si pasar a `/plan-work` (issue-planning)

## The Process

**Understanding the idea:**
- Check current project state first
- Ask questions one at a time
- Focus on: purpose, constraints, success criteria

**Exploring approaches:**
- Propose 2-3 different approaches with trade-offs
- Lead with your recommended option and explain why

**Presenting the design:**
- Scale each section to its complexity
- Ask after each section whether it looks right
- Cover: architecture, components, data flow, error handling, testing

**Design for isolation:**
- Break into smaller units with clear purpose
- Well-defined interfaces
- Each unit understandable and testable independently

## After the Design

**Documentation:**
- Write validated design to `docs/aura/specs/YYYY-MM-DD-<topic>-design.md`

**User Review Gate:**
After spec review passes, ask user to review:

> "Spec written and saved. Please review and let me know if you want changes before we start implementation."

Wait for response. Only proceed once approved.

**Implementation:**
- Preguntar: "¿Pasamos a planificar los issues con `/plan-work`?"
  - Sí → Invocar `skills/issue-planning/SKILL.md` vía `/plan-work`
  - No → Guardar spec en `docs/aura/specs/` y cerrar. Los issues se pueden crear en otra sesión.

## Key Principles

- **One question at a time** - Don't overwhelm
- **Multiple choice preferred** - Easier to answer
- **YAGNI ruthlessly** - Remove unnecessary features
- **Explore alternatives** - Always propose 2-3 approaches
- **Incremental validation** - Present design, get approval before moving on
- **Be flexible** - Go back and clarify when needed