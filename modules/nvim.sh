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
MODULE_DEPS=("rust" "golang" "git" "cli-tools")

# Install LazyVim requirements.
# https://www.lazyvim.org/ — Requirements section.
_nvim::install_deps() {
  # rg and fd are provided by the cli-tools module (runs before nvim).
  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing nvim dependencies" core::pkg_install node shfmt shellcheck || return 1
    ;;
  linux)
    core::run_cmd "Installing nvim dependencies" core::pkg_install nodejs npm shfmt shellcheck || return 1
    ;;
  esac

  # lazygit is provided by the git module (runs before nvim).
  # tree-sitter-cli is not in apt/dnf; rust module ensures cargo is on PATH.
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli || return 1
  core::summary "    ✓ tree-sitter-cli installed via cargo"
}

# Build and install Neovim from source (Linux only).
# https://github.com/neovim/neovim/blob/master/BUILD.md
# Source is kept at ~/.local/src/neovim for future uninstall.
_nvim::install_from_src() {
  local src_dir="${HOME}/.local/src/neovim"

  if [[ -d "${src_dir}" ]]; then
    core::log ERROR "Source directory already exists: ${src_dir}"
    core::log ERROR "Run ./uninstall.sh first to clean up the previous build"
    return 1
  fi

  core::run_cmd "Cloning neovim source" git clone https://github.com/neovim/neovim.git "${src_dir}" || return 1

  pushd "${src_dir}" >/dev/null
  core::run_cmd "Checking out stable branch" git checkout stable || return 1
  core::run_cmd "Building neovim" make CMAKE_BUILD_TYPE=RelWithDebInfo || return 1
  core::run_cmd "Installing neovim" sudo make install || return 1
  popd >/dev/null
}

# Install Neovim. macOS uses brew; Linux checks repo version and falls back
# to source build if too old for LazyVim (requires >= 0.8.0).
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

  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing neovim via brew" core::pkg_install neovim || return 1
    ;;
  linux)
    local pkg_version=""
    case "${DOTFILES_PKG_MANAGER}" in
    apt) pkg_version="$(apt-cache show neovim 2>/dev/null | awk '/^Version:/{print $2; exit}')" ;;
    dnf) pkg_version="$(dnf info neovim 2>/dev/null | awk '/^Version/{print $NF; exit}')" ;;
    esac

    local pkg_semver
    pkg_semver="$(printf '%s' "${pkg_version}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"

    if [[ -n "${pkg_semver}" ]] && core::version_ge "${pkg_semver}" "${min_version}"; then
      core::run_cmd "Installing neovim via package manager" core::pkg_install neovim || return 1
    else
      core::log INFO "Repo neovim (${pkg_version:-unknown}) < ${min_version}, building from source"
      _nvim::install_from_src
    fi
    ;;
  esac
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
    local current_remote
    current_remote="$(git -C "${nvim_dir}" remote get-url origin 2>/dev/null)"
    if [[ "${current_remote}" == "${repo}" ]]; then
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
  local src_dir="${HOME}/.local/src/neovim"
  if [[ -d "${src_dir}/build" ]]; then
    pushd "${src_dir}" >/dev/null
    sudo make uninstall
    popd >/dev/null
    rm -rf "${src_dir}"
    core::log INFO "Uninstalled source-built Neovim"
    core::summary "    ✓ uninstalled source-built neovim"
  fi

  rm -rf "${HOME}/.config/nvim"
  core::summary "    ✓ removed ~/.config/nvim"
}
