# Module: zoxide

[zoxide](https://github.com/ajeetdsouza/zoxide) — a smarter `cd` command that learns
your most-visited directories and lets you jump to them with `z foo`. Cross-platform.

## Symlinks

None — zoxide needs no config files; it works out of the box.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install zoxide`; writes `eval "$(zoxide init zsh)"` block to `~/.zshrc` |
| `uninstall` | removes the zoxide block from `~/.zshrc` |

## Notes

- `zoxide init zsh` defines two shell functions:
  - `z <query>` — jump to the best-matching directory
  - `zi <query>` — interactive selection via fzf (if fzf is installed)
- The database is stored at `~/.local/share/zoxide/db.zo` and is not managed by this
  module (persists across install/uninstall cycles).
- `zi` integrates with fzf automatically when both are on PATH; no extra config needed.
