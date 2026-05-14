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

# Install LazyVim requirements.
# https://www.lazyvim.org/ — Requirements section.
_nvim::install_deps() {
  # rg and fd are provided by the cli-tools module (runs before nvim).
  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing nvim dependencies" core::pkg_install node shfmt shellcheck
    ;;
  linux)
    core::run_cmd "Installing nvim dependencies" core::pkg_install nodejs npm shfmt shellcheck
    ;;
  esac

  # lazygit and tree-sitter-cli are not in apt/dnf.
  # golang and rust modules run before nvim, so go and cargo are on PATH.
  core::run_cmd "Installing lazygit" go install github.com/jesseduffield/lazygit@latest
  core::summary "    ✓ lazygit installed via go"
  core::run_cmd "Installing tree-sitter-cli" cargo install --locked tree-sitter-cli
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

  core::run_cmd "Cloning neovim source" git clone https://github.com/neovim/neovim.git "${src_dir}"

  pushd "${src_dir}" >/dev/null
  core::run_cmd "Checking out stable branch" git checkout stable
  core::run_cmd "Building neovim" make CMAKE_BUILD_TYPE=RelWithDebInfo
  core::run_cmd "Installing neovim" sudo make install
  popd >/dev/null
}

# Install Neovim. macOS uses brew; Linux offers package manager or source build.
_nvim::install_nvim() {
  if core::check_installed nvim; then
    core::log INFO "Neovim already installed: $(nvim --version | head -1)"
    core::summary "    ✓ $(nvim --version | head -1) already installed"
    return 0
  fi

  case "${DOTFILES_OS}" in
  mac)
    core::run_cmd "Installing neovim via brew" core::pkg_install neovim
    ;;
  linux)
    local pkg_version
    case "${DOTFILES_PKG_MANAGER}" in
    apt) pkg_version="$(apt-cache show neovim 2>/dev/null | awk '/^Version:/{print $2; exit}')" ;;
    dnf) pkg_version="$(dnf info neovim 2>/dev/null | awk '/^Version/{print $NF; exit}')" ;;
    esac

    # Non-interactive (CI, pipe): default to package manager install.
    if [[ ! -t 0 ]]; then
      core::run_cmd "Installing neovim via package manager" core::pkg_install neovim
      return
    fi

    local choice
    while :; do
      printf '\nNeovim not found. Install options:\n' >&2
      printf '  1) Package manager — %s\n' "${pkg_version:-version unknown}" >&2
      printf '  2) Build from source (latest stable)\n' >&2
      printf 'Choice [1]: ' >&2
      read -r choice
      case "${choice:-1}" in
      1)
        core::run_cmd "Installing neovim via package manager" core::pkg_install neovim
        return
        ;;
      2)
        _nvim::install_from_src
        core::summary "    ✓ installed from source"
        return
        ;;
      *) core::log WARN "Invalid choice: ${choice}" ;;
      esac
    done
    ;;
  esac
}

# Clone the LazyVim config repo to ~/.config/nvim.
# https://www.lazyvim.org/installation
# Uses a personal fork instead of the official starter; .git is kept for
# ongoing maintenance of the config repo.
_nvim::clone_config() {
  local repo="https://github.com/yangxingwu/neovim-lua-config.git"
  local branch="LazyVimV2"

  # Back up existing nvim dirs per LazyVim installation guide.
  # https://www.lazyvim.org/installation
  mv ~/.config/nvim{,.bak} 2>/dev/null || true
  mv ~/.local/share/nvim{,.bak} 2>/dev/null || true
  mv ~/.local/state/nvim{,.bak} 2>/dev/null || true
  mv ~/.cache/nvim{,.bak} 2>/dev/null || true

  core::run_cmd "Cloning neovim config" git clone --branch "${branch}" "${repo}" ~/.config/nvim
  core::summary "    ✓ config → ~/.config/nvim (cloned)"
}

install() {
  _nvim::install_deps
  _nvim::install_nvim
  _nvim::clone_config
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
