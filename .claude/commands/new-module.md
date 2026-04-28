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

install() {
  # Install packages, external tools, write config files.
  # Example: core::pkg_install $ARGUMENTS
  :
}

uninstall() {
  # Clean up side effects produced by install() (config files, clones, etc.).
  :
}
```

**2. `docs/modules/$ARGUMENTS.md`**

```markdown
# Module: $ARGUMENTS

[Description of what this module manages]

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
---

@docs/modules/$ARGUMENTS.md
```

After creating all three files, remind the user to:
1. Fill in `MODULE_DESC`, `MODULE_PLATFORM`, and add `core::pkg_install` calls
   in `install()` for any packages needed
2. Add `$ARGUMENTS` to `DOTFILES_MODULES` in `lib/modules.sh`
3. Update `docs/modules/$ARGUMENTS.md` with accurate hooks table
4. Run `./install.sh` to verify the module works end-to-end
