# Module: nvim

Neovim editor. Config is maintained in a separate repo and cloned by `post_install`.

## Symlinks

This module does **not** use the standard `LINKS[]` mechanism. Instead, `post_install`
clones the config repo and creates the symlink directly.

| Clone target | Symlink | Platform |
|---|---|---|
| `~/.local/share/nvim-config/` | `~/.config/nvim` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | `neovim` |
| Linux | `neovim` |

## Config Repo

```
git@github.com:yangxingwu/neovim-lua-config.git  (branch: lazyvimV2)
```

`post_install` does the following:

1. Clones the repo to `~/.local/share/nvim-config/` if not already present.
2. Creates `~/.config/nvim → ~/.local/share/nvim-config/` symlink.

Both steps are idempotent — a second run skips if the clone dir or symlink already exists.
