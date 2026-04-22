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

pre_install() {
  # Install runtime dependencies before the main install step.
  # Example: core::pkg_install ripgrep fd
  :
}

install() {
  # Install the main subject of this module.
  # Example: core::pkg_install $ARGUMENTS
  :
}

post_install() {
  # Post-install configuration (symlinks, config generation, etc.)
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

## Dependencies

| Platform | Packages |
|---|---|
| macOS | — |
| Linux | — |

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
1. Fill in `MODULE_DESC`, `MODULE_PLATFORM`, `LINKS`, and add `core::pkg_install` calls in `install()` for any packages needed
2. Create `config/$ARGUMENTS/` and add the actual config files
3. Update `docs/modules/$ARGUMENTS.md` with accurate symlink and dependency tables
4. Run `./install.sh --module $ARGUMENTS --dry-run` to verify the module works
