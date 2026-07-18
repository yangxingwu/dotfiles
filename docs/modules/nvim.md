# Module: nvim

[Neovim](https://github.com/neovim/neovim) editor with
[LazyVim](https://www.lazyvim.org) configuration
(yangxingwu/neovim-lua-config).

## Module hooks

| Hook | Action |
|---|---|
| `install` | install deps (node, shfmt, shellcheck, tree-sitter-cli, lua 5.1, luarocks, pynvim, neovim npm package); install nvim (brew or pkg/source); clone/update config repo; headless plugin sync + treesitter compile |
| `uninstall` | remove ~/.config/nvim and from-source builds (nvim, lua 5.1, luarocks, muon); **retain** dep binaries (shfmt, shellcheck, tree-sitter-cli, pynvim, neovim npm; muon/neovim if pkg-managed) and nvim runtime data (~/.local/share/nvim, ~/.local/state/nvim, ~/.cache/nvim) |

## Install behavior

**First run:** backs up existing nvim directories (timestamped), clones config
repo, runs headless initialization.

**Subsequent runs (idempotent):** pulls latest config from repo, re-syncs
plugins and treesitter parsers. No backup triggered.

## Headless initialization

After cloning the config, the module runs:
1. `nvim --headless "+Lazy! sync" +qa` — downloads all plugins
2. `nvim --headless "+TSUpdate" +qa` — compiles treesitter parsers

Mason LSP servers are NOT installed in headless mode (LazyVim's mason-lspconfig
uses async installation with no official synchronous headless command). They
auto-install on first real nvim launch (~10-20s in background).

## Backup and restore

Backups are timestamped (e.g. `~/.config/nvim.bak.20260516-143022`) and logged
during install. Four directories form a set:

- `~/.config/nvim` — configuration (lua files)
- `~/.local/share/nvim` — plugin data (lazy.nvim downloads)
- `~/.local/state/nvim` — state (shada, undo history)
- `~/.cache/nvim` — cache (treesitter compiled parsers)

To restore:
```bash
# Replace <TS> with timestamp shown in install log
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
mv ~/.config/nvim.bak.<TS> ~/.config/nvim
mv ~/.local/share/nvim.bak.<TS> ~/.local/share/nvim
mv ~/.local/state/nvim.bak.<TS> ~/.local/state/nvim
mv ~/.cache/nvim.bak.<TS> ~/.cache/nvim
```

## Prerequisites

- `lazyvim.json` must be committed to the nvim config repo (not gitignored).
  It declares enabled LazyVim extras. Without it, only base plugins are synced.
  See: https://github.com/LazyVim/starter/blob/main/.gitignore

## Notes

- On Linux, offers interactive choice between package manager and source build.
  Non-interactive (CI) defaults to package manager.
- tree-sitter-cli remains in this module (nvim-specific dependency, not a
  general CLI tool).
- rg, fd provided by cli-tools module; lazygit provided by git module.
