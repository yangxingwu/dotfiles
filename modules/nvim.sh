#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor with LazyVim configuration
# https://github.com/neovim/neovim
# https://www.lazyvim.org
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor with LazyVim configuration (yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust" "golang" "git" "cli-tools" "python")

# Install LazyVim requirements.
# https://www.lazyvim.org/ — Requirements section.
_nvim::install_deps() {
  # rg and fd are provided by the cli-tools module (runs before nvim).
  case "${DOTFILES_OS}" in
  mac)
    core::pkg_install node shfmt shellcheck || return 1
    ;;
  linux)
    core::pkg_install nodejs npm shfmt shellcheck || return 1
    ;;
  esac

  # lua 5.1 + luarocks: managed by lazy.nvim's built-in hererocks support.
  # lazy.nvim auto-installs an isolated lua 5.1 + luarocks environment to
  # ~/.local/share/nvim/lazy-rocks/hererocks/ (requires python3 on PATH).

  # lazygit is provided by the git module (runs before nvim).
  # tree-sitter-cli is not in apt/dnf; rust module ensures cargo is on PATH.
  if core::check_installed tree-sitter; then
    core::log INFO "tree-sitter-cli already installed"
    core::summary "    ✓ tree-sitter-cli already installed"
  else
    core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli || return 1
    core::summary "    ✓ tree-sitter-cli installed via cargo"
  fi

  # Python provider (`:help provider-python`).
  if [[ "${DOTFILES_PKG_MANAGER}" == "dnf" ]]; then
    # Fedora's neovim RPM sets g:python3_host_prog=/usr/bin/python3 in system
    # config, bypassing pipx's pynvim-python auto-detection. Use the distro
    # package (PEP 668 blocks pip --user on Fedora 38+).
    core::pkg_install python3-pynvim || return 1
  else
    # pynvim 0.6.0+ installed via pipx is auto-detected by neovim.
    if command -v pynvim-python >/dev/null 2>&1; then
      core::log INFO "pynvim already installed"
      core::summary "    ✓ pynvim already installed"
    else
      core::run_cmd "Installing pynvim" pipx install pynvim || return 1
      core::summary "    ✓ pynvim installed via pipx"
    fi
  fi

  # Node.js provider (`:help provider-nodejs`).
  if npm list -g neovim >/dev/null 2>&1; then
    core::log INFO "neovim npm package already installed"
    core::summary "    ✓ neovim npm package already installed"
  elif [[ "${DOTFILES_OS}" == "mac" ]]; then
    # brew's npm global prefix is user-writable (/opt/homebrew/lib/node_modules).
    core::run_cmd "Installing neovim npm package" npm install -g neovim || return 1
  else
    # System npm global prefix (/usr/lib/node_modules) requires root.
    core::run_cmd "Installing neovim npm package" sudo npm install -g neovim || return 1
  fi
}

# Install Neovim. Requires >= 0.8.0 for LazyVim.
# See: https://www.lazyvim.org/ — Requirements section.
_nvim::install_nvim() {
  local min_version="0.8.0"

  # Already installed — check version is sufficient.
  if core::check_installed nvim; then
    local current
    current="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    if core::version_ge "${current}" "${min_version}"; then
      core::log INFO "Neovim already installed: NVIM v${current}"
      core::summary "    ✓ NVIM v${current} already installed"
      return 0
    fi
    core::log WARN "Neovim ${current} too old (need >= ${min_version}), removing and reinstalling"
    core::pkg_remove neovim
    # Fall through to fresh install below
  fi

  # Ubuntu 22.04 ships neovim 0.6.1 which is too old for LazyVim (needs
  # >= 0.8.0). Check the repo version first; if insufficient, add the
  # neovim-ppa/unstable PPA which tracks latest stable releases (the name
  # "unstable" is misleading — it provides release builds, not nightly).
  # See: https://launchpad.net/~neovim-ppa/+archive/ubuntu/unstable
  # On Ubuntu 24.04+ the default repo version should be sufficient and
  # the PPA path will not be triggered.
  if [[ "${DOTFILES_PKG_MANAGER}" == "apt" ]]; then
    local pkg_version
    pkg_version="$(apt-cache show neovim 2>/dev/null | awk '/^Version:/{print $2; exit}')"

    local pkg_semver=""
    if [[ "${pkg_version}" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
      pkg_semver="${BASH_REMATCH[0]}"
    fi

    if [[ -z "${pkg_semver}" ]] || ! core::version_ge "${pkg_semver}" "${min_version}"; then
      core::run_cmd "Installing software-properties-common" sudo apt-get install -y software-properties-common || return 1
      core::run_cmd "Adding neovim PPA" sudo add-apt-repository -y ppa:neovim-ppa/unstable || return 1
    fi
  fi

  core::pkg_install neovim || return 1
}

# Clone or update the LazyVim config repo to ~/.config/nvim.
# Idempotent: if already cloned with correct remote, pulls latest.
# Otherwise backs up existing dirs (timestamped) and clones fresh.
_nvim::clone_config() {
  local repo="https://github.com/yangxingwu/neovim-lua-config.git"
  local branch="LazyVimV2"
  local nvim_dir="${HOME}/.config/nvim"

  # Already cloned with correct remote — pull latest (idempotent).
  if [[ -d "${nvim_dir}/.git" ]]; then
    local current_remote repo_path
    current_remote="$(git -C "${nvim_dir}" remote get-url origin 2>/dev/null)"
    repo_path="${repo#*github.com/}"
    if [[ "${current_remote}" == *"${repo_path}"* ]]; then
      core::run_cmd "Updating neovim config" git -C "${nvim_dir}" pull --quiet || return 1
      core::summary "    ✓ config updated: ~/.config/nvim"
      return 0
    fi
  fi

  # Back up existing nvim directories (timestamped, never overwrites previous backups).
  # All four directories form a set — restore them together using the same timestamp.
  # To restore:
  #   rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
  #   mv ~/.config/nvim.bak.<timestamp> ~/.config/nvim
  #   mv ~/.local/share/nvim.bak.<timestamp> ~/.local/share/nvim
  #   mv ~/.local/state/nvim.bak.<timestamp> ~/.local/state/nvim
  #   mv ~/.cache/nvim.bak.<timestamp> ~/.cache/nvim
  core::backup "${HOME}/.config/nvim"
  core::backup "${HOME}/.local/share/nvim"
  core::backup "${HOME}/.local/state/nvim"
  core::backup "${HOME}/.cache/nvim"

  core::run_cmd "Cloning neovim config" git clone --branch "${branch}" "${repo}" "${nvim_dir}" || return 1
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
}

# Pre-install plugins and treesitter parsers in headless mode.
# This makes the first interactive nvim launch fast (no waiting for downloads).
_nvim::headless_init() {
  # Install all plugins declared in lazy.nvim config (includes extras from lazyvim.json).
  # The "!" makes Lazy wait until sync completes before proceeding.
  # See: https://lazy.folke.io/usage
  #
  # IMPORTANT: lazyvim.json must be committed to the nvim config repo (not gitignored).
  # This file declares which LazyVim extras are enabled (lang.python, lang.go, etc.).
  # Without it, Lazy! sync only installs base plugins — extras and their associated
  # Mason LSP servers won't be configured. The LazyVim starter template does NOT
  # gitignore this file by default; committing it is the intended workflow.
  # See: https://github.com/LazyVim/starter/blob/main/.gitignore
  core::run_cmd "Installing nvim plugins (headless)" nvim --headless "+Lazy! sync" +qa || return 1

  # Compile treesitter parsers declared in ensure_installed.
  # See: https://github.com/nvim-treesitter/nvim-treesitter#commands
  core::run_cmd "Compiling treesitter parsers" nvim --headless "+TSUpdate" +qa || return 1

  # NOTE: Mason LSP servers are NOT installed here.
  # LazyVim uses mason-lspconfig which triggers async installation during normal
  # nvim startup (in the config function via pkg:install()). There is no official
  # synchronous headless command in the Mason/LazyVim ecosystem.
  # Mason auto-installs missing servers on first real nvim launch (~10-20s background).
  # This is acceptable because:
  #   - lazyvim.json (committed to nvim config repo) declares which extras are
  #     enabled, so mason-lspconfig knows what to install on first launch
  #   - Lazy! sync already downloaded mason-lspconfig itself
  #   - The user gets a fully functional editor immediately (LSP installs in background)
  core::summary "    ✓ plugins and treesitter parsers installed (headless)"
}

install() {
  _nvim::install_deps || return 1
  _nvim::install_nvim || return 1
  _nvim::clone_config || return 1
  _nvim::headless_init || return 1
}

uninstall() {
  rm -rf "${HOME}/.config/nvim"
  core::summary "    ✓ removed ~/.config/nvim"
}
