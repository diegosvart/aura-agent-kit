---
name: requesting-code-review
description: Use after completing significant implementation work, before merging or moving forward
---

# Requesting Code Review

## Overview

Before submitting work for review, verify it aligns with the plan and meets quality standards.

## When to Use

- After completing a task or set of tasks
- Before creating a PR
- Before merging to develop

## Pre-Review Checklist

Run this yourself before requesting review:

### Plan Alignment
- [ ] Implementation matches the plan/spec
- [ ] All planned features are implemented
- [ ] No unauthorized scope changes

### Code Quality
- [ ] Linter passes (`ruff check .` / `npm run lint`)
- [ ] Tests pass (`pytest` / `npm test`)
- [ ] No debug code or console.logs left behind
- [ ] Code follows project conventions

### Documentation
- [ ] New functions/classes have docstrings
- [ ] Complex logic has comments
- [ ] README updated if needed

### Security
- [ ] No secrets or keys in code
- [ ] No .env files committed
- [ ] Input validation in place

## Review Request Format

When requesting review, provide:

```markdown
## Implementation Summary
- What was implemented
- Files changed
- Tests added/updated

## Self-Review
- Linter: ✅/❌
- Tests: ✅/❌
- Docs: ✅/❌

## Questions/Blockers
- Any specific areas to review?
- Any concerns?

## Link to Plan
- [Plan file or link]
```

## Communication

- Be specific about what you want feedback on
- Highlight non-obvious decisions
- Ask explicit questions where unsure

## After Review

- Address all critical comments
- Respond to each feedback item
- Don't take feedback personally - it's about the code