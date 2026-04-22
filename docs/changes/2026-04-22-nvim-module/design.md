# nvim Module Redesign

**Date:** 2026-04-22
**Status:** Approved

## Problem

The current `modules/nvim.sh` has three issues:

1. It clones the config repo to a separate directory (`~/.local/share/nvim-config`) and
   then symlinks `~/.config/nvim` to it — an unnecessary indirection since the config
   lives in an independent external repo, not in the dotfiles repo itself.
2. It prompts the user interactively for the clone destination, which breaks unattended
   installs and dry-run parity.
3. It does not declare its runtime dependencies, so LazyVim tools are not provisioned
   automatically.

## Decisions

**1. Clone directly to `~/.config/nvim`** — the path LazyVim documents and expects.
No symlink layer is needed. The clone *is* the deployment.

**2. Declare all required external tools** in `pre_install` so the installer provisions
them before Neovim starts.

**3. Support building Neovim from source** as an opt-in alternative to the package
manager, prompted at install time. This is useful when the system-provided version is
too old for LazyVim (which requires Neovim ≥ 0.9).

**4. Install `tree-sitter-cli` via `cargo install`** in `pre_install`. It is a runtime
dependency of nvim and has no package-manager equivalent. Requires the `rust` module to
run before `nvim` (declared via module ordering in `install.sh`).

---

## Design

### Module interface

```bash
LINKS=()

pre_install()  # install all dependencies
install()      # install neovim (version check + pkg or source build)
post_install() # clone config repo to ~/.config/nvim
```

---

### Part 1 — `pre_install`: Runtime Dependencies

LazyVim and its default plugins require these tools:

| Tool | Mac package | Linux package | Purpose |
|---|---|---|---|
| ripgrep | `ripgrep` | `ripgrep` | Telescope live-grep |
| fd | `fd` | `fd-find` | Telescope file-find |
| lazygit | `lazygit` | `lazygit` | lazygit.nvim integration |
| node / npm | `node` | `nodejs npm` | LSP servers (via Mason) |
| shfmt | `shfmt` | `shfmt` | Shell formatting (null-ls) |
| shellcheck | `shellcheck` | `shellcheck` | Shell linting (null-ls) |
| tree-sitter-cli | `cargo install` | `cargo install` | Tree-sitter grammar builds |

```bash
pre_install() {
  # Install pkg-manager deps (platform-specific package names)
  case "$(detect::os)" in
    mac)   core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
    linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli has no pkg-manager package — install via cargo
  if command -v cargo &>/dev/null; then
    cargo install --locked tree-sitter-cli
  else
    core::log WARN "cargo not found — skipping tree-sitter-cli (run rust module first)"
  fi
}
```

---

### Part 2 — `install`: Neovim Installation

#### Why neovim is not installed via `core::pkg_install`

The installed version may be too old (LazyVim requires ≥ 0.9). `install()` checks the
current version and, if an upgrade is needed, prompts the user to choose between the
package manager and a source build.

#### Version check and prompt

```
Neovim found: v0.7.2 (LazyVim requires ≥ 0.9)
Install options:
  1) Package manager (brew/apt)
  2) Build from source (latest stable tag)
Choose [1/2]:
```

If neovim is already installed and meets the minimum version (≥ 0.9), skip with a log
message. In DRY_RUN mode: skip the prompt, log both paths.

#### Conflict handling

| Scenario | Action |
|---|---|
| brew-installed nvim present, user chooses source build | `brew uninstall neovim` before compiling |
| source-installed nvim present (`/usr/local/bin/nvim`), user chooses package manager | warn user, proceed — package manager will overwrite |
| correct version already installed (≥ 0.9) | skip entirely, log version |

#### Build process (source path)

1. Install build dependencies inline:
   - macOS: `ninja cmake gettext curl` (brew)
   - Linux: `ninja-build gettext cmake curl build-essential` (apt/dnf/pacman)
2. Clone `https://github.com/neovim/neovim.git` to `${_NVIM_BUILD_DIR}`
3. Checkout latest stable tag: `git tag --sort=-v:refname | grep -E '^v[0-9]' | head -1`
4. `make CMAKE_BUILD_TYPE=RelWithDebInfo`
5. `sudo make install`
6. `rm -rf "${_NVIM_BUILD_DIR}"`

#### Constants

```bash
readonly _NVIM_SRC_REPO="https://github.com/neovim/neovim.git"
readonly _NVIM_BUILD_DIR="/tmp/neovim-build-$$"   # $$ = PID, avoids collisions
readonly _NVIM_MIN_VERSION="0.9"
```

---

### Part 3 — `post_install`: Config Clone

#### Constants

```bash
readonly _NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
readonly _NVIM_BRANCH="LazyVimV2"
readonly _NVIM_TARGET="${HOME}/.config/nvim"
```

#### Behaviour

| Condition | Action |
|---|---|
| `~/.config/nvim/.git` exists | Skip — already cloned |
| `~/.config/nvim` is a non-git directory | `core::backup` it, then clone |
| `~/.config/nvim` is a symlink | Remove symlink, then clone |
| Neither | Clone directly |

No interactive prompts in any code path.

---

### Module Interface Summary

```bash
LINKS=()

pre_install() {
  # 1. Install pkg-manager deps (ripgrep, fd, lazygit, node, shfmt, shellcheck)
  # 2. cargo install --locked tree-sitter-cli
}

install() {
  # 1. Check installed neovim version
  # 2. Skip if already ≥ 0.9
  # 3. Prompt: package manager vs source build
  # 4. Handle conflict (uninstall existing if switching methods)
  # 5. Install neovim (package or source)
}

post_install() {
  # 1. Clone config repo to ~/.config/nvim (idempotent)
}
```

### Module ordering dependency

The `rust` module must run before `nvim` so that `cargo` is available for
`tree-sitter-cli`. This is handled by listing `rust` before `nvim` in the installer's
module load order (see `install.sh`).

---

## What Changes

- Remove interactive clone-destination prompt
- Remove `DEPS_MAC` / `DEPS_LINUX` — replaced by `pre_install`
- Remove `_NVIM_CLONE_DIR_DEFAULT` and `_NVIM_LINK` constants
- Clone config directly to `~/.config/nvim`
- Handle pre-existing directory/symlink at `~/.config/nvim`
- Add `pre_install` with full runtime dependency installation
- Add `install` with version check, pkg/source prompt, conflict handling
- Install `tree-sitter-cli` via `cargo` in `pre_install`

## What Does Not Change

- `LINKS=()` — no file-level symlinks needed
- Idempotency — config clone guarded by `.git` check
