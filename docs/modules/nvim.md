# Module: nvim

Neovim editor with LazyVim configuration. The module installs runtime dependencies,
installs or upgrades Neovim itself, and clones the config repo directly to
`~/.config/nvim`.

## Symlinks

This module sets `LINKS=()` — no standard symlinks are created. `post_install` clones
the config repo directly to `~/.config/nvim` instead.

## Execution order

```
pre_install → install → (no LINKS) → post_install
```

---

## pre_install

Installs the runtime tools that LazyVim plugins depend on:

| Platform | Packages |
|---|---|
| macOS | `ripgrep fd lazygit node shfmt shellcheck` |
| Linux | `ripgrep fd-find lazygit nodejs npm shfmt shellcheck` |

Also installs `tree-sitter-cli` via `cargo install --locked tree-sitter-cli`. If `cargo`
is not available (i.e. the `rust` module has not run yet), this step is skipped with a
`WARN` log rather than a hard failure.

> **Module ordering:** `rust` must appear before `nvim` in the module list so `cargo` is
> available for `tree-sitter-cli`.

---

## install

Checks whether a sufficiently new Neovim is already present. The minimum required version
is **0.9** (LazyVim requirement).

Constants used:

| Constant | Value |
|---|---|
| `_NVIM_MIN_MINOR` | `9` |
| `_NVIM_SRC_REPO` | `https://github.com/neovim/neovim.git` |
| `_NVIM_BUILD_DIR` | `/tmp/neovim-build-$$` |

### Version check

Runs `nvim --version`, extracts `major.minor`, and skips installation when:

```
major > 0  OR  minor >= 9
```

### Install prompt

When Neovim is absent or too old the user is offered two options:

```
1) Package manager (brew/apt)
2) Build from source (latest stable tag)
```

In `DRY_RUN=1` mode both options are logged but no prompt is shown.

### Option 1 — package manager

Calls `core::pkg_install neovim` (same package name on both platforms).

### Option 2 — build from source

Build steps:

1. **macOS only**: if a Homebrew-managed `neovim` is installed, it is uninstalled first
   to avoid PATH conflicts with the source build.
2. Install platform-specific build dependencies:
   - macOS: `ninja cmake gettext curl`
   - Linux: `ninja-build gettext cmake curl build-essential`
3. Shallow-clone `_NVIM_SRC_REPO` into `_NVIM_BUILD_DIR`.
4. Find the latest stable semver tag (pattern `v[0-9]+.[0-9]+.[0-9]+`), check it out.
5. Build: `make CMAKE_BUILD_TYPE=RelWithDebInfo`
6. Install: `sudo make install`
7. A `trap … RETURN` ensures `_NVIM_BUILD_DIR` is removed on both success and failure.

---

## post_install

Clones the LazyVim config repo to `~/.config/nvim`.

Constants used:

| Constant | Value |
|---|---|
| `_NVIM_REPO` | `git@github.com:yangxingwu/neovim-lua-config.git` |
| `_NVIM_BRANCH` | `LazyVimV2` |
| `_NVIM_TARGET` | `~/.config/nvim` |

The clone is idempotent — the hook handles four possible states of `_NVIM_TARGET`:

| State | Action |
|---|---|
| Contains `.git/` (already cloned) | Skip |
| Stale symlink | Remove symlink, then clone |
| Existing non-git directory | `core::backup`, then clone |
| Absent | Clone |

In `DRY_RUN=1` mode the clone command is logged and the hook returns early.
