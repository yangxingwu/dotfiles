# Module: nvim

Neovim editor configuration using [LazyVim](https://www.lazyvim.org/) as the base
distribution, with Catppuccin Mocha as the default colorscheme.

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/nvim/` | `~/.config/nvim/` | all |

## Dependencies

| Platform | Packages |
|---|---|
| macOS | `neovim` |
| Linux | `neovim` |

## Notes

The entire `config/nvim/` directory is symlinked as a single unit (not file-by-file).
LazyVim bootstraps itself on first launch and installs all declared plugins via lazy.nvim.

Catppuccin Mocha is explicitly declared as a plugin spec in `config/nvim/init.lua` and
set as the `install.colorscheme` fallback so it is available from the very first startup
before lazy.nvim finishes installing other plugins.

To add custom plugins or override LazyVim defaults, add files under
`config/nvim/lua/plugins/`.
