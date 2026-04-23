Scaffold a new dotfiles module named: $ARGUMENTS

Create these three files:

**1. `modules/$ARGUMENTS.sh`**

```bash
#!/usr/bin/env bash
# modules/$ARGUMENTS.sh — [brief description of what this module manages]
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="$ARGUMENTS"
MODULE_DESC="[One-line description]"
MODULE_PLATFORM="all"   # all | mac | linux

LINKS=()

install() {
  # Install packages, external tools, or clone external repositories.
  # Example: core::pkg_install $ARGUMENTS
  :
}

uninstall() {
  # Clean up external side effects produced by install().
  # LINKS symlinks are removed automatically by uninstall.sh — do not touch them here.
  :
}
```

**2. `docs/modules/$ARGUMENTS.md`**

```markdown
# Module: $ARGUMENTS

[Description of what this module manages]

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/$ARGUMENTS/` | `~/.config/$ARGUMENTS/` | all |

## Module hooks

| Hook | Action |
|---|---|
| `install` | [what install() does] |
| `uninstall` | [what uninstall() does, or "no-op"] |

## Notes

[Any special setup steps, post-install configuration, or caveats]
```

**3. `.claude/rules/module-$ARGUMENTS.md`**

```markdown
---
paths:
  - "modules/$ARGUMENTS.sh"
  - "config/$ARGUMENTS/**"
---

@docs/modules/$ARGUMENTS.md
```

After creating all three files, remind the user to:
1. Fill in `MODULE_DESC`, `MODULE_PLATFORM`, `LINKS`, and add `core::pkg_install` calls
   in `install()` for any packages needed
2. Create `config/$ARGUMENTS/` and add the actual config files
3. Update `docs/modules/$ARGUMENTS.md` with accurate symlink and hooks tables
4. Run `./install.sh` to verify the module works end-to-end
