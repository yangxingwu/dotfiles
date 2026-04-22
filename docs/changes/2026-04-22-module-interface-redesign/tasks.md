# Module Interface Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `DEPS_MAC`/`DEPS_LINUX` arrays with `pre_install`/`install`/`post_install` hooks, giving each phase a clear semantic meaning, and update all modules plus the orchestrator accordingly.

**Architecture:** `lib/core.sh` gains multi-arg support for `core::pkg_install`. `install.sh` drops the deps loop and runs `pre_install → install → LINKS → post_install`. All modules (`git`, `tmux`, `zsh`, `ghostty`, `nvim`) are updated; a new `rust` module is added. The `rust` module must be ordered before `nvim` in the filesystem (alphabetical load order works since `r` < `n` is false — use a numeric prefix or explicit ordering).

**Tech Stack:** Bash, shfmt (auto-formats on save via PostToolUse hook), shellcheck

---

## File Map

| File | Action | What changes |
|---|---|---|
| `lib/core.sh` | Modify | `core::pkg_install` loops over `"$@"` instead of `"${1}"` |
| `install.sh` | Modify | Drop deps loop, add `install() { :; }` default, reorder phases |
| `modules/git.sh` | Modify | Remove `DEPS_*`, add `install()` |
| `modules/tmux.sh` | Modify | Remove `DEPS_*`, add `install()` |
| `modules/ghostty.sh` | Modify | Remove `DEPS_*`, add `install()` no-op |
| `modules/zsh.sh` | Modify | Remove `DEPS_*`, add `install()`, add `zshenv` to LINKS, update `post_install` |
| `modules/nvim.sh` | Rewrite | New `pre_install`/`install`/`post_install` per design doc |
| `modules/rust.sh` | Create | New module: rustup installer |
| `config/zsh/zshrc.mac` | Create | macOS interactive shell config |
| `config/zsh/zshrc.linux` | Create | Linux interactive shell config |
| `config/zsh/zshenv` | Create | Portable env vars for all shell types |
| `docs/modules/nvim.md` | Modify | Update to reflect new behaviour |
| `docs/modules/zsh.md` | Modify | Update to reflect new behaviour |

### Module load order note

`install.sh` loads modules alphabetically. Current order: `ghostty git nvim tmux zsh`.
`rust` needs to run before `nvim`. Since `r` sorts after `n`, modules must be loaded
explicitly (not via glob) **or** the glob used with an explicit ordering override.
The simplest fix: rename `modules/rust.sh` → `modules/00-rust.sh` is ugly. Better:
change `install.sh` to load modules in an explicit list instead of a glob. This is
done in Task 2.

---

## Task 1: Extend `core::pkg_install` to accept multiple arguments

**Files:**
- Modify: `lib/core.sh`

- [ ] **Step 1: Read current implementation**

Open `lib/core.sh` lines 102-150. Note that `core::pkg_install` uses `local package="${1}"` — a single fixed argument.

- [ ] **Step 2: Replace single-arg with multi-arg loop**

Change `core::pkg_install` from:

```bash
# core::pkg_install <package-name>
# Installs a package via the detected package manager. Skips if already installed.
core::pkg_install() {
  local package="${1}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would install package: ${package}"
    return 0
  fi

  case "${DOTFILES_PKG_MANAGER}" in
    brew)
      if brew list --formula "${package}" &>/dev/null \
        || brew list --cask "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        brew install "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    apt)
      if dpkg -s "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo apt-get install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    dnf)
      if rpm -q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo dnf install -y "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    pacman)
      if pacman -Q "${package}" &>/dev/null; then
        core::log INFO "Already installed: ${package}"
      else
        sudo pacman -S --noconfirm "${package}"
        core::log INFO "Installed: ${package}"
      fi
      ;;
    *)
      core::log WARN "Unknown package manager — cannot install: ${package}"
      ;;
  esac
}
```

To:

```bash
# core::pkg_install <package> [<package> ...]
# Installs one or more packages via the detected package manager.
# Skips any package that is already installed.
core::pkg_install() {
  local package
  for package in "$@"; do
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would install package: ${package}"
      continue
    fi

    case "${DOTFILES_PKG_MANAGER}" in
      brew)
        if brew list --formula "${package}" &>/dev/null \
          || brew list --cask "${package}" &>/dev/null; then
          core::log INFO "Already installed: ${package}"
        else
          brew install "${package}"
          core::log INFO "Installed: ${package}"
        fi
        ;;
      apt)
        if dpkg -s "${package}" &>/dev/null; then
          core::log INFO "Already installed: ${package}"
        else
          sudo apt-get install -y "${package}"
          core::log INFO "Installed: ${package}"
        fi
        ;;
      dnf)
        if rpm -q "${package}" &>/dev/null; then
          core::log INFO "Already installed: ${package}"
        else
          sudo dnf install -y "${package}"
          core::log INFO "Installed: ${package}"
        fi
        ;;
      pacman)
        if pacman -Q "${package}" &>/dev/null; then
          core::log INFO "Already installed: ${package}"
        else
          sudo pacman -S --noconfirm "${package}"
          core::log INFO "Installed: ${package}"
        fi
        ;;
      *)
        core::log WARN "Unknown package manager — cannot install: ${package}"
        ;;
    esac
  done
}
```

- [ ] **Step 3: Verify with shellcheck**

```bash
shellcheck lib/core.sh
```

Expected: no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/core.sh
git commit -m "feat(core): extend core::pkg_install to accept multiple packages"
```

---

## Task 2: Refactor `install.sh` — new execution order + explicit module list

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Update module state reset and execution order in `install::run_module`**

In `install::run_module`, make these changes:

1. In the state reset block, replace `unset MODULE_NAME MODULE_DESC MODULE_PLATFORM LINKS DEPS_MAC DEPS_LINUX` with `unset MODULE_NAME MODULE_DESC MODULE_PLATFORM LINKS` and add `install() { :; }` alongside `pre_install() { :; }` and `post_install() { :; }`.

2. Delete the deps install loop (the block from `# Install platform-specific dependencies` through `done`).

3. Change the execution sequence from `pre_install → LINKS → post_install` to `pre_install → install → LINKS → post_install`.

The updated `install::run_module` body (after the source/guard block) becomes:

```bash
  core::log INFO "▶ ${MODULE_NAME} — ${MODULE_DESC}"

  pre_install

  install

  local link_entry src target
  for link_entry in "${LINKS[@]+"${LINKS[@]}"}"; do
    src="${link_entry%%:*}"
    target="${link_entry##*:}"
    core::symlink "${src}" "${target}"
  done

  post_install

  core::log INFO "✓ ${MODULE_NAME}"
```

- [ ] **Step 2: Change module glob to explicit ordered list**

`rust` must run before `nvim` but `r` sorts after `n` alphabetically. Replace the
glob loop at the bottom of `install.sh`:

```bash
# Iterate all module files in alphabetical order
_found_modules=0
_target_found=0
for _module_file in "${DOTFILES_ROOT}/modules"/*.sh; do
  [[ -f "${_module_file}" ]] || continue
  _found_modules=$((_found_modules + 1))
  install::run_module "${_module_file}"
  # Track whether --module target was matched (check MODULE_NAME after sourcing)
  if [[ -n "${TARGET_MODULE}" ]] && [[ "${MODULE_NAME}" == "${TARGET_MODULE}" ]]; then
    _target_found=1
  fi
done
```

With:

```bash
# Modules are loaded in explicit order — dependencies first.
# rust must precede nvim (cargo is required for tree-sitter-cli).
_MODULES=(
  "${DOTFILES_ROOT}/modules/ghostty.sh"
  "${DOTFILES_ROOT}/modules/git.sh"
  "${DOTFILES_ROOT}/modules/rust.sh"
  "${DOTFILES_ROOT}/modules/nvim.sh"
  "${DOTFILES_ROOT}/modules/tmux.sh"
  "${DOTFILES_ROOT}/modules/zsh.sh"
)

_found_modules=0
_target_found=0
for _module_file in "${_MODULES[@]}"; do
  [[ -f "${_module_file}" ]] || continue
  _found_modules=$((_found_modules + 1))
  install::run_module "${_module_file}"
  if [[ -n "${TARGET_MODULE}" ]] && [[ "${MODULE_NAME}" == "${TARGET_MODULE}" ]]; then
    _target_found=1
  fi
done
```

- [ ] **Step 3: Verify with shellcheck**

```bash
shellcheck install.sh
```

Expected: no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(installer): new execution order pre_install→install→LINKS→post_install; explicit module list"
```

---

## Task 3: Update simple existing modules (`git`, `tmux`, `ghostty`)

**Files:**
- Modify: `modules/git.sh`
- Modify: `modules/tmux.sh`
- Modify: `modules/ghostty.sh`

- [ ] **Step 1: Update `modules/git.sh`**

Remove `DEPS_MAC`/`DEPS_LINUX`, add `install()`:

```bash
#!/usr/bin/env bash
# modules/git.sh — Git configuration and global hooks
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration and global hooks"
MODULE_PLATFORM="all"

LINKS=(
  "config/git/gitconfig:${HOME}/.gitconfig"
  "config/git/git-hooks:${HOME}/.git-hooks"
)

pre_install() { :; }

install() {
  core::pkg_install git
}

post_install() {
  # Point git at a shared hooks directory so all repos on this machine
  # pick up the hooks without needing per-repo configuration.
  if [[ "${DRY_RUN}" == "1" ]]; then
    core::log DRY "Would run: git config --global core.hooksPath ${HOME}/.git-hooks"
    return 0
  fi
  git config --global core.hooksPath "${HOME}/.git-hooks"
  core::log INFO "Set global git hooks path: ${HOME}/.git-hooks"
}
```

- [ ] **Step 2: Update `modules/tmux.sh`**

Remove `DEPS_MAC`/`DEPS_LINUX`, add `install()`:

```bash
#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux configuration (oh-my-tmux base + local overrides)"
MODULE_PLATFORM="all"

# oh-my-tmux is cloned by post_install; only the local override file is symlinked.
LINKS=(
  "config/tmux/tmux.conf.local:${HOME}/.config/tmux/tmux.conf.local"
)

readonly _TMUX_REPO="https://github.com/gpakosz/.tmux.git"
readonly _TMUX_CLONE_DIR="${HOME}/.local/share/tmux/oh-my-tmux"
readonly _TMUX_LINK="${HOME}/.config/tmux/tmux.conf"

pre_install() { :; }

install() {
  core::pkg_install tmux
}

post_install() {
  # Clone oh-my-tmux if not already present.
  if [[ ! -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would clone ${_TMUX_REPO} → ${_TMUX_CLONE_DIR}"
    else
      git clone --depth 1 "${_TMUX_REPO}" "${_TMUX_CLONE_DIR}"
      core::log INFO "Cloned oh-my-tmux → ${_TMUX_CLONE_DIR}"
    fi
  else
    core::log INFO "oh-my-tmux already present: ${_TMUX_CLONE_DIR}"
  fi

  # Symlink ~/.config/tmux/tmux.conf → oh-my-tmux's .tmux.conf.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would symlink: ${_TMUX_LINK} → ${_TMUX_CLONE_DIR}/.tmux.conf"
    return 0
  fi

  if [[ -L "${_TMUX_LINK}" ]] \
    && [[ "$(readlink "${_TMUX_LINK}")" == "${_TMUX_CLONE_DIR}/.tmux.conf" ]]; then
    core::log INFO "Already linked: ${_TMUX_LINK}"
    return 0
  fi

  mkdir -p "$(dirname "${_TMUX_LINK}")"
  ln -sf "${_TMUX_CLONE_DIR}/.tmux.conf" "${_TMUX_LINK}"
  core::log INFO "Linked: ${_TMUX_LINK} → ${_TMUX_CLONE_DIR}/.tmux.conf"
}
```

- [ ] **Step 3: Update `modules/ghostty.sh`**

Remove `DEPS_MAC`/`DEPS_LINUX`, add `install()` no-op (Ghostty is installed manually):

```bash
#!/usr/bin/env bash
# modules/ghostty.sh — Ghostty terminal emulator configuration
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ghostty"
MODULE_DESC="Ghostty terminal emulator configuration"
MODULE_PLATFORM="mac"

LINKS=(
  "config/ghostty/config:${HOME}/.config/ghostty/config"
)

pre_install() { :; }

install() { :; }

post_install() { :; }
```

- [ ] **Step 4: Verify with shellcheck**

```bash
shellcheck modules/git.sh modules/tmux.sh modules/ghostty.sh
```

Expected: no errors or warnings.

- [ ] **Step 5: Commit**

```bash
git add modules/git.sh modules/tmux.sh modules/ghostty.sh
git commit -m "feat(modules): migrate git/tmux/ghostty to new install() hook interface"
```

---

## Task 4: Create `modules/rust.sh`

**Files:**
- Create: `modules/rust.sh`

- [ ] **Step 1: Write the module**

```bash
#!/usr/bin/env bash
# modules/rust.sh — Rust toolchain via rustup
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

LINKS=()

pre_install() { :; }

# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present.
install() {
  if command -v rustup &>/dev/null; then
    core::log INFO "rustup already installed — skipping"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would install rustup (stable toolchain)"
    return 0
  fi

  # --no-modify-path: ~/.cargo/env is already sourced via config/zsh/zshenv
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path
  core::log INFO "rustup installed"
}

post_install() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would source ${HOME}/.cargo/env"
    return 0
  fi

  # Make cargo available for the rest of the current install session
  # (e.g. nvim module's tree-sitter-cli step) without requiring a new shell.
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
    core::log INFO "Sourced ~/.cargo/env — rustc $(rustc --version)"
  else
    core::log WARN "~/.cargo/env not found — cargo may not be on PATH"
  fi
}
```

- [ ] **Step 2: Verify with shellcheck**

```bash
shellcheck modules/rust.sh
```

Expected: no errors or warnings.

- [ ] **Step 3: Commit**

```bash
git add modules/rust.sh
git commit -m "feat(modules): add rust module — installs rustup stable toolchain"
```

---

## Task 5: Update `modules/zsh.sh` and create `config/zsh/` files

**Files:**
- Modify: `modules/zsh.sh`
- Create: `config/zsh/zshrc.mac`
- Create: `config/zsh/zshrc.linux`
- Create: `config/zsh/zshenv`

- [ ] **Step 1: Write `config/zsh/zshenv`**

```zsh
# Cargo / Rust — loaded for all shell types (login, interactive, scripts).
# Guard prevents errors on machines where rustup has not been installed yet.
[[ -f "${HOME}/.cargo/env" ]] && . "${HOME}/.cargo/env"

# machine-local env (API keys, tool-specific vars, etc.) — never committed
[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local
```

- [ ] **Step 2: Write `config/zsh/zshrc.mac`**

```zsh
# Homebrew (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# sheldon plugin manager
eval "$(sheldon source)"

# completion system (after sheldon so fpath is fully populated)
autoload -Uz compinit && compinit

# history substring search key bindings (after sheldon)
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Starship prompt
eval "$(starship init zsh)"

# fzf key bindings (Ctrl+R history search, Ctrl+T file search)
eval "$(fzf --zsh)"

# ssh wrapper — auto-fills password from ~/.ssh/passwords/<host> via sshpass
ssh() {
  local host="${*: -1}"
  local pass_file="${HOME}/.ssh/passwords/${host}"
  if [[ -f "${pass_file}" ]]; then
    sshpass -f "${pass_file}" command ssh "$@"
  else
    command ssh "$@"
  fi
}

# machine-local overrides (NVM, IDE tools, etc.) — never committed
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

- [ ] **Step 3: Write `config/zsh/zshrc.linux`**

```zsh
# sheldon plugin manager
eval "$(sheldon source)"

# completion system (after sheldon so fpath is fully populated)
autoload -Uz compinit && compinit

# history substring search key bindings (after sheldon)
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Starship prompt
eval "$(starship init zsh)"

# fzf key bindings (Ctrl+R history search, Ctrl+T file search)
eval "$(fzf --zsh)"

# machine-local overrides (NVM, IDE tools, etc.) — never committed
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
```

- [ ] **Step 4: Rewrite `modules/zsh.sh`**

```bash
#!/usr/bin/env bash
# modules/zsh.sh — Zsh configuration (sheldon plugin manager, starship prompt)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zsh"
MODULE_DESC="Zsh shell configuration (sheldon plugins, starship prompt)"
MODULE_PLATFORM="all"

LINKS=(
  "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
  "config/zsh/zshenv:${HOME}/.zshenv"
)

pre_install() { :; }

install() {
  # macOS ships with a system zsh; Linux needs it explicitly.
  case "$(detect::os)" in
    mac)   core::pkg_install sheldon starship ;;
    linux) core::pkg_install zsh sheldon starship ;;
  esac
}

post_install() {
  # Back up existing non-symlink files before taking ownership.
  # The user can then migrate machine-specific lines to ~/.zshrc.local / ~/.zshenv.local.
  [[ -f "${HOME}/.zshrc" && ! -L "${HOME}/.zshrc" ]] && core::backup "${HOME}/.zshrc"
  [[ -f "${HOME}/.zshenv" && ! -L "${HOME}/.zshenv" ]] && core::backup "${HOME}/.zshenv"

  # Symlink platform-specific zshrc.
  case "$(detect::os)" in
    mac)   core::symlink "config/zsh/zshrc.mac"   "${HOME}/.zshrc" ;;
    linux) core::symlink "config/zsh/zshrc.linux" "${HOME}/.zshrc" ;;
  esac

  # Generate starship config from the catppuccin-powerline preset.
  # The preset is the unmodified upstream — no point tracking it in the repo.
  local starship_cfg="${HOME}/.config/starship.toml"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would run: starship preset catppuccin-powerline -o ${starship_cfg}"
    return 0
  fi

  mkdir -p "$(dirname "${starship_cfg}")"
  starship preset catppuccin-powerline -o "${starship_cfg}"
  core::log INFO "Generated starship config from catppuccin-powerline preset"
}
```

- [ ] **Step 5: Verify with shellcheck**

```bash
shellcheck modules/zsh.sh
```

Expected: no errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add modules/zsh.sh config/zsh/zshrc.mac config/zsh/zshrc.linux config/zsh/zshenv
git commit -m "feat(zsh): track .zshrc and .zshenv in dotfiles; platform-split zshrc; .local escape hatch"
```

---

## Task 6: Rewrite `modules/nvim.sh`

**Files:**
- Modify: `modules/nvim.sh`

- [ ] **Step 1: Write the new module**

```bash
#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor + LazyVim configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor with LazyVim configuration"
MODULE_PLATFORM="all"

# Config is cloned directly to ~/.config/nvim by post_install — no LINKS needed.
LINKS=()

readonly _NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
readonly _NVIM_BRANCH="LazyVimV2"
readonly _NVIM_TARGET="${HOME}/.config/nvim"
readonly _NVIM_SRC_REPO="https://github.com/neovim/neovim.git"
readonly _NVIM_BUILD_DIR="/tmp/neovim-build-$$"
readonly _NVIM_MIN_MINOR=9   # LazyVim requires neovim >= 0.9

# Installs all runtime dependencies that LazyVim and its plugins require.
pre_install() {
  case "$(detect::os)" in
    mac)   core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
    linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli has no pkg-manager package — install via cargo.
  # Requires the rust module to have run first.
  if command -v cargo &>/dev/null; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would run: cargo install --locked tree-sitter-cli"
    else
      cargo install --locked tree-sitter-cli
      core::log INFO "Installed tree-sitter-cli via cargo"
    fi
  else
    core::log WARN "cargo not found — skipping tree-sitter-cli (run rust module first)"
  fi
}

# Returns the installed neovim minor version, or 0 if not installed.
_nvim::installed_minor() {
  if ! command -v nvim &>/dev/null; then
    printf '0'
    return 0
  fi
  # nvim --version first line: "NVIM v0.10.3"
  local ver
  ver="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  printf '%s' "${ver##*.}"
}

# Returns 0 if brew-managed neovim is installed, 1 otherwise.
_nvim::brew_installed() {
  brew list --formula neovim &>/dev/null
}

# Installs neovim via the package manager.
_nvim::install_pkg() {
  core::log INFO "Installing neovim via package manager..."
  case "$(detect::os)" in
    mac)
      if _nvim::brew_installed; then
        brew upgrade neovim
      else
        brew install neovim
      fi
      ;;
    linux) core::pkg_install neovim ;;
  esac
}

# Installs neovim from source (latest stable tag).
_nvim::install_source() {
  core::log INFO "Installing neovim from source..."

  # Install build dependencies.
  case "$(detect::os)" in
    mac)   core::pkg_install ninja cmake gettext curl ;;
    linux) core::pkg_install ninja-build gettext cmake curl build-essential ;;
  esac

  # Remove brew-managed neovim if present to avoid PATH conflicts.
  if [[ "$(detect::os)" == "mac" ]] && _nvim::brew_installed; then
    core::log INFO "Removing brew-managed neovim before source build..."
    brew uninstall neovim
  fi

  git clone --depth 1 "${_NVIM_SRC_REPO}" "${_NVIM_BUILD_DIR}"

  local latest_tag
  latest_tag="$(
    git -C "${_NVIM_BUILD_DIR}" tag --sort=-v:refname \
      | grep -E '^v[0-9]' \
      | head -1
  )"
  core::log INFO "Building neovim ${latest_tag}..."

  git -C "${_NVIM_BUILD_DIR}" checkout "${latest_tag}"

  pushd "${_NVIM_BUILD_DIR}" > /dev/null
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  popd > /dev/null

  rm -rf "${_NVIM_BUILD_DIR}"
  core::log INFO "neovim built and installed from source (${latest_tag})"
}

# Checks the installed neovim version and installs/upgrades as needed.
install() {
  local minor
  minor="$(_nvim::installed_minor)"

  if [[ "${minor}" -ge "${_NVIM_MIN_MINOR}" ]]; then
    core::log INFO "neovim $(nvim --version | head -1) already satisfies >= 0.${_NVIM_MIN_MINOR} — skipping"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    if [[ "${minor}" -eq 0 ]]; then
      core::log DRY "neovim not found — would install via package manager or source build"
    else
      core::log DRY "neovim v0.${minor} found (< 0.${_NVIM_MIN_MINOR}) — would upgrade"
    fi
    return 0
  fi

  if [[ "${minor}" -eq 0 ]]; then
    core::log INFO "neovim not found"
  else
    core::log WARN "neovim v0.${minor} is older than required >= 0.${_NVIM_MIN_MINOR}"
  fi

  printf '\nInstall options:\n'
  printf '  1) Package manager (brew/apt)\n'
  printf '  2) Build from source (latest stable tag)\n'
  printf 'Choose [1/2]: '
  local choice
  read -r choice

  case "${choice}" in
    1) _nvim::install_pkg ;;
    2) _nvim::install_source ;;
    *)
      core::log WARN "Invalid choice — defaulting to package manager"
      _nvim::install_pkg
      ;;
  esac
}

# Clones the LazyVim config repo directly to ~/.config/nvim.
post_install() {
  # Already cloned — nothing to do.
  if [[ -d "${_NVIM_TARGET}/.git" ]]; then
    core::log INFO "nvim config already present: ${_NVIM_TARGET}"
    return 0
  fi

  # Back up any non-git directory that happens to be at the target path.
  if [[ -d "${_NVIM_TARGET}" && ! -L "${_NVIM_TARGET}" ]]; then
    core::backup "${_NVIM_TARGET}"
  fi

  # Remove a stale symlink (e.g. left by the old module version).
  if [[ -L "${_NVIM_TARGET}" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would remove symlink: ${_NVIM_TARGET}"
    else
      rm "${_NVIM_TARGET}"
      core::log INFO "Removed stale symlink: ${_NVIM_TARGET}"
    fi
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would clone ${_NVIM_REPO} (branch ${_NVIM_BRANCH}) → ${_NVIM_TARGET}"
    return 0
  fi

  git clone --branch "${_NVIM_BRANCH}" "${_NVIM_REPO}" "${_NVIM_TARGET}"
  core::log INFO "Cloned nvim config → ${_NVIM_TARGET}"
}
```

- [ ] **Step 2: Verify with shellcheck**

```bash
shellcheck modules/nvim.sh
```

Expected: no errors or warnings.

- [ ] **Step 3: Commit**

```bash
git add modules/nvim.sh
git commit -m "feat(nvim): rewrite module — direct clone to ~/.config/nvim, full deps, source-build option"
```

---

## Task 7: Update module docs

**Files:**
- Modify: `docs/modules/nvim.md`
- Modify: `docs/modules/zsh.md`

- [ ] **Step 1: Update `docs/modules/nvim.md`**

```markdown
# Module: nvim

Neovim editor with LazyVim configuration.

## Hooks

| Hook | Action |
|---|---|
| `pre_install` | Installs LazyVim runtime deps via pkg manager; installs `tree-sitter-cli` via `cargo install` |
| `install` | Checks installed neovim version; installs/upgrades via pkg manager or source build |
| `post_install` | Clones config repo directly to `~/.config/nvim` |

## Symlinks

None — config is cloned directly to `~/.config/nvim`, not symlinked.

## Runtime Dependencies

| Tool | Mac package | Linux package | Purpose |
|---|---|---|---|
| ripgrep | `ripgrep` | `ripgrep` | Telescope live-grep |
| fd | `fd` | `fd-find` | Telescope file-find |
| lazygit | `lazygit` | `lazygit` | lazygit.nvim integration |
| node/npm | `node` | `nodejs npm` | LSP servers via Mason |
| shfmt | `shfmt` | `shfmt` | Shell formatting |
| shellcheck | `shellcheck` | `shellcheck` | Shell linting |
| tree-sitter-cli | `cargo install` | `cargo install` | Grammar builds |

## neovim Installation

LazyVim requires neovim >= 0.9. `install()` checks the current version and, if it is
absent or too old, prompts the user:

```
Install options:
  1) Package manager (brew/apt)
  2) Build from source (latest stable tag)
```

In DRY_RUN mode the prompt is skipped and both paths are logged.

## Config Repo

```
git@github.com:yangxingwu/neovim-lua-config.git  (branch: LazyVimV2)
```

Cloned directly to `~/.config/nvim`. Idempotent — skips if `.git` already present.

## Module Ordering

The `rust` module must run before `nvim` so that `cargo` is available when
`pre_install` calls `cargo install --locked tree-sitter-cli`.
```

- [ ] **Step 2: Update `docs/modules/zsh.md`**

```markdown
# Module: zsh

Zsh shell configuration — sheldon plugin manager, starship prompt, and tracked shell
init files.

## Hooks

| Hook | Action |
|---|---|
| `pre_install` | no-op |
| `install` | Installs `sheldon`, `starship` (+ `zsh` on Linux) |
| `post_install` | Backs up existing `~/.zshrc`/`~/.zshenv`; symlinks platform-specific zshrc; generates starship config |

## Symlinks

| Source | Target | Platform |
|---|---|---|
| `config/zsh/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` | all |
| `config/zsh/zshenv` | `~/.zshenv` | all |
| `config/zsh/zshrc.mac` | `~/.zshrc` | macOS (via post_install) |
| `config/zsh/zshrc.linux` | `~/.zshrc` | Linux (via post_install) |

## Config Files

| File | Purpose |
|---|---|
| `config/zsh/zshenv` | Portable env vars (all shell types); sources `~/.zshenv.local` |
| `config/zsh/zshrc.mac` | macOS interactive shell config; sources `~/.zshrc.local` |
| `config/zsh/zshrc.linux` | Linux interactive shell config; sources `~/.zshrc.local` |

## .local Escape Hatch

Machine-specific content belongs in `~/.zshrc.local` / `~/.zshenv.local`. These files
are sourced at the end of the tracked files if they exist, but are never committed.

Examples of machine-local content:
- NVM initialisation
- IDE-injected PATH entries (e.g. CodeBuddy)
- API keys (e.g. `GEMINI_API_KEY`)

## Migration

On first run, `post_install` backs up any existing regular-file `~/.zshrc` / `~/.zshenv`
to `~/.dotfiles-backup/<timestamp>/`. The user should then copy machine-specific lines
from the backup into `~/.zshrc.local` / `~/.zshenv.local`.

## starship

`post_install` generates `~/.config/starship.toml` from the upstream
`catppuccin-powerline` preset. The preset is used unmodified, so it is not tracked.
Running `install.sh` again will regenerate the file (idempotent).
```

- [ ] **Step 3: Commit**

```bash
git add docs/modules/nvim.md docs/modules/zsh.md
git commit -m "docs(modules): update nvim and zsh docs to reflect new interface"
```

---

## Self-Review

### Spec coverage

| Design requirement | Task that implements it |
|---|---|
| `core::pkg_install` multi-arg | Task 1 |
| `install.sh` new execution order | Task 2 |
| `install.sh` explicit module list (rust before nvim) | Task 2 |
| `git`/`tmux`/`ghostty` new interface | Task 3 |
| `rust` module | Task 4 |
| `zsh` module + `zshrc.mac`/`zshrc.linux`/`zshenv` | Task 5 |
| `nvim` module rewrite | Task 6 |
| Docs updated | Task 7 |

### Potential issues

1. **`detect::os` vs `DOTFILES_OS`**: `detect.sh` exports `DOTFILES_OS` at source time. Inside module hooks, `DOTFILES_OS` is available as an env var — `detect::os` can also be called, it's idempotent. Both usages in the plan are consistent.

2. **`_nvim::installed_minor` parsing**: `nvim --version` outputs `NVIM v0.10.3`. The grep `[0-9]+\.[0-9]+` captures `0.10`, then `##*.` extracts `10`. Correct.

3. **`source` in `post_install` of rust module**: shellcheck needs `# shellcheck source=/dev/null` — already included in the code above.

4. **`zshenv` sourcing `~/.cargo/env`**: On a machine that has never run the rust module, `~/.cargo/env` won't exist. The line `. "${HOME}/.cargo/env"` will fail with `set -e`. Fix: guard with `[[ -f ... ]] &&` in `zshenv`.
