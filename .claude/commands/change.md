Generate a change document for the current session's work.

1. Run these commands to understand what changed:

```bash
git diff HEAD
git log --oneline -5
```

2. Based on the diff, determine:
   - A short slug for this change (e.g., `fix-tmux-symlink`, `add-ghostty-module`)
   - The change type: `bugfix` | `feature` | `refactor` | `chore`
   - Which files were affected (list the key ones)

3. Create the directory and file: `docs/changes/YYYY-MM-DD-<slug>/change.md`
   (Use today's actual date in YYYY-MM-DD format)

4. Write the file with this content:

```markdown
# <type>: <one-line summary>

Date: YYYY-MM-DD
Type: bugfix | feature | refactor | chore
Files: <comma-separated list of key changed files>

## Background

[What problem or context triggered this change. One to three sentences.]

## What changed

- [Specific change 1]
- [Specific change 2]

## Why

[Reasoning or trade-off, if non-obvious. Omit if self-evident.]
```

5. Report the path of the created document and its content.
