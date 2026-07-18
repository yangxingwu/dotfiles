# Module: nvim

[Neovim](https://github.com/neovim/neovim) editor with
[LazyVim](https://www.lazyvim.org) configuration
(yangxingwu/neovim-lua-config).

## Module hooks

| Hook | Action |
|---|---|
| `install` | install deps (node, shfmt, shellcheck, tree-sitter-cli, lua 5.1, luarocks, pynvim, neovim npm package); install nvim (brew or pkg/source); clone/update config repo; headless plugin restore + treesitter/Mason install |
| `uninstall` | remove ~/.config/nvim and from-source builds (nvim, lua 5.1, luarocks, muon); **retain** dep binaries (shfmt, shellcheck, tree-sitter-cli, pynvim, neovim npm; muon/neovim if pkg-managed) and nvim runtime data (~/.local/share/nvim, ~/.local/state/nvim, ~/.cache/nvim) |

## Install behavior

**First run:** backs up existing nvim directories (timestamped), clones config
repo, runs headless initialization.

**Subsequent runs (idempotent):** pulls latest config from repo, re-syncs
plugins and treesitter parsers. No backup triggered.

## Headless initialization

After cloning the config, the module pre-installs everything in headless mode so
the first interactive launch is fast. Each step blocks until complete:

1. **Restore plugins** — `nvim --headless "+Lazy! restore" +qa` installs plugins
   at the exact versions pinned in `lazy-lock.json`. Retried up to 3 times, because
   `Lazy! restore` exits 0 even when clones fail on flaky networks; each attempt
   verifies that every plugin is actually installed.
2. **Load plugins + native libs** — force-loads all plugins (`Lazy! load all`) to
   trigger their config, then waits for blink.cmp to download its prebuilt native
   fuzzy-matching library from GitHub releases.
3. **Treesitter parsers** — reads LazyVim's `ensure_installed` list and installs
   the parsers via the nvim-treesitter Lua API, blocking until each is compiled.
4. **Mason tools** — reads mason.nvim's `ensure_installed` (formatters, linters,
   DAP adapters) and runs `MasonInstall`, waiting on install events for completion.

All steps run synchronously (`vim.wait`), so a successful install leaves nothing to
download on first launch. Requires Neovim >= 0.11.2 — headless init aborts early
with a clear error on older versions (LazyVim hangs in headless mode otherwise).

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
