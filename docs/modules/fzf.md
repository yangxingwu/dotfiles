# Module: fzf

[fzf](https://github.com/junegunn/fzf) fuzzy finder with zsh key bindings.

## Module hooks

| Hook | Action |
|---|---|
| `install` | `core::pkg_install fzf`; append `eval "$(fzf --zsh)"` to `~/.zshrc` as a managed `fzf` block |
| `uninstall` | remove the `fzf` block from `~/.zshrc` (package is preserved) |

## Notes

`fzf --zsh` emits the key-binding setup that enables:

- **Ctrl+R**: fuzzy search command history
- **Ctrl+T**: fuzzy file picker
- **Alt+C**: fuzzy directory jump

The fzf package must be installed before the sheldon module runs because
sheldon's `fzf-tab` plugin requires the `fzf` binary on PATH. Install order
is managed by `DOTFILES_MODULES` in `lib/modules.sh`.
