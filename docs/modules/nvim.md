# Module: nvim

Neovim editor with LazyVim configuration. The module installs runtime dependencies,
installs or upgrades Neovim itself, and clones the config repo directly to
`~/.config/nvim` — all inside a single `install()` hook.

## Symlinks

This module sets `LINKS=()` — no standard symlinks are created. `install()` clones the
config repo directly to `~/.config/nvim` instead.

## Module hooks

| Hook | Action |
|---|---|
| `install` | runtime deps → tree-sitter-cli → nvim (version-checked) → clone config |
| `uninstall` | `rm -rf ~/.config/nvim` if a git checkout |

## install()

The hook performs four sub-steps in order:

### 1. Runtime dependencies

Installed via `core::pkg_install`:

| Platform | Packages |
|---|---|
| macOS | `ripgrep fd lazygit node shfmt shellcheck` |
| Linux | `ripgrep fd-find lazygit nodejs npm shfmt shellcheck` |

### 2. `tree-sitter-cli`

Installed via `cargo install --locked tree-sitter-cli`. If `cargo` is not available
(i.e. the `rust` module has not run yet), this step is skipped with a `WARN` log rather
than a hard failure.

> **Module ordering:** `rust` must appear before `nvim` in `_MODULES` so `cargo` is
> available here.

### 3. Neovim version check

Uses `core::check_installed nvim && core::require_version nvim 0 9`. When the check
fails, the user is prompted:

```
Neovim not found (or too old — LazyVim requires >= 0.9)
Install options:
  1) Package manager (brew/apt)
  2) Build from source (latest stable tag)
Choice [1]:
```

Constants used:

| Constant | Value |
|---|---|
| `_NVIM_MIN_MAJOR` | `0` |
| `_NVIM_MIN_MINOR` | `9` |
| `_NVIM_SRC_REPO` | `https://github.com/neovim/neovim.git` |
| `_NVIM_BUILD_DIR` | `/tmp/neovim-build-$$` |

#### Option 1 — package manager

Calls `core::pkg_install neovim` (same package name on both platforms).

#### Option 2 — build from source

Build steps:

1. **macOS only**: if a Homebrew-managed `neovim` is installed, it is uninstalled first
   to avoid PATH conflicts with the source build.
2. Install platform-specific build dependencies:
   - macOS: `ninja cmake gettext curl`
   - Linux: `ninja-build gettext cmake curl build-essential`
3. Shallow-clone `_NVIM_SRC_REPO` into `_NVIM_BUILD_DIR`.
4. Find the latest stable semver tag (pattern `v[0-9]+.[0-9]+.[0-9]+`), check it out.
5. Build: `make CMAKE_BUILD_TYPE=RelWithDebInfo`.
6. Install: `sudo make install`.
7. A `trap … RETURN` ensures `_NVIM_BUILD_DIR` is removed on both success and failure.

### 4. Clone the LazyVim config repo

Constants used:

| Constant | Value |
|---|---|
| `_NVIM_REPO` | `git@github.com:yangxingwu/neovim-lua-config.git` |
| `_NVIM_BRANCH` | `LazyVimV2` |
| `_NVIM_TARGET` | `~/.config/nvim` |

The clone is idempotent — the step handles four possible states of `_NVIM_TARGET`:

| State | Action |
|---|---|
| Contains `.git/` (already cloned) | Skip |
| Stale symlink | Remove symlink, then clone |
| Existing non-git directory | `core::backup`, then clone |
| Absent | Clone |

## uninstall()

If `~/.config/nvim/.git` exists, removes the whole directory.
