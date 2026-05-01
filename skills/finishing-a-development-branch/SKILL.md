---
name: finishing-a-development-branch
description: Use when all tasks in a branch are complete and you're ready to close the work
---

# Finishing a Development Branch

## Overview

When all tasks are complete, verify the branch is ready and offer options for next steps.

## When to Use

- All tasks in the plan are done
- Tests pass
- Code review approved (if applicable)

## Pre-Finish Checklist

- [ ] All tests pass
- [ ] Linter clean
- [ ] No debug code
- [ ] Changes committed
- [ ] Branch is up to date with base

## Health Check

```bash
# Verify tests pass
pytest tests/ -v

# Verify linter passes  
ruff check .

# Check branch status
git status

# Verify no untracked files that should be tracked
git diff --stat
```

## Present Options

After verification, present to user:

```markdown
## Branch Ready: [branch-name]

**Status:** ✅ All checks passed

### Options:

1. **Create PR** → Merge to develop
   - Creates pull request with conventional title
   - Links to issue if applicable
   - Triggers CI if configured

2. **Commit & Push** → Keep branch for later PR
   - Commits all changes
   - Pushes to remote
   - Branch stays open for more work

3. **Squash commits** → Clean history
   - Combines all commits into one
   - Clean history in main/develop

4. **Discard branch** → Start fresh
   - Branch deleted locally and remotely
   - Only if work is not needed

### Recommendation: [X]
**Reason:** [based on context]
```

## Common Actions

### Option 1: Create PR
```bash
gh pr create --base develop --fill
```

### Option 2: Push Branch
```bash
git push -u origin branch-name
```

### Option 3: Squash
```bash
git rebase -i HEAD~N  # N = number of commits
```

### Option 4: Discard (with confirmation)
```bash
git branch -d branch-name
git push origin --delete branch-name
```

## Remember

- Always verify before presenting options
- Don't assume user's preference - ask
- Be ready to explain each option