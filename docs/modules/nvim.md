# Module: nvim

Neovim editor with [LazyVim](https://www.lazyvim.org/) configuration.
https://github.com/neovim/neovim

## Module hooks

| Hook | Action |
|---|---|
| `install` | deps → tree-sitter-cli → nvim → clone config |
| `uninstall` | uninstall source-built nvim (if applicable); `rm -rf ~/.config/nvim` |

## install()

### 1. Runtime dependencies (`_nvim::install_deps`)

| Platform | Packages |
|---|---|
| macOS | `ripgrep fd lazygit node shfmt shellcheck` |
| Linux | `ripgrep fd-find lazygit nodejs npm shfmt shellcheck` |

`tree-sitter-cli` is installed via `cargo install --locked`. Fails if cargo is absent.

### 2. Neovim (`_nvim::install_nvim`)

- If already installed, logs the version and skips.
- macOS: `core::pkg_install neovim` (brew).
- Linux: interactive prompt — package manager or build from source.

Source build follows [BUILD.md](https://github.com/neovim/neovim/blob/master/BUILD.md):
`git clone` → `git checkout stable` → `make` → `sudo make install`.
Source kept at `~/.local/src/neovim` for future `make uninstall`.

### 3. Clone config (`_nvim::clone_config`)

Backs up existing nvim dirs per [LazyVim installation guide](https://www.lazyvim.org/installation):
```bash
mv ~/.config/nvim{,.bak}
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}
```

Then clones the personal config repo:
- Repo: `git@github.com:yangxingwu/neovim-lua-config.git`
- Branch: `LazyVimV2`
- Target: `~/.config/nvim`

## uninstall()

- If `~/.local/src/neovim/build` exists: `sudo make uninstall`, then remove source dir.
- `rm -rf ~/.config/nvim`
