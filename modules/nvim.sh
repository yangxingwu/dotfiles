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
  case "${DOTFILES_OS}" in
  mac) core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
  linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli is not in any package manager — install via cargo.
  if ! core::check_installed cargo; then
    core::log ERROR "cargo not found — install the rust module first"
    return 1
  fi
  cargo install --locked tree-sitter-cli
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

  git clone https://github.com/neovim/neovim.git "${src_dir}"

  pushd "${src_dir}" >/dev/null
  git checkout stable
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  popd >/dev/null

  core::log INFO "Neovim built and installed from source (stable)"
}

# Install Neovim. macOS uses brew; Linux offers package manager or source build.
_nvim::install_nvim() {
  if core::check_installed nvim; then
    core::log INFO "Neovim already installed: $(nvim --version | head -1)"
    return 0
  fi

  case "${DOTFILES_OS}" in
  mac)
    core::pkg_install neovim
    ;;
  linux)
    local pkg_version
    case "${DOTFILES_PKG_MANAGER}" in
    apt) pkg_version="$(apt-cache show neovim 2>/dev/null | awk '/^Version:/{print $2; exit}')" ;;
    dnf) pkg_version="$(dnf info neovim 2>/dev/null | awk '/^Version/{print $NF; exit}')" ;;
    esac

    local choice
    while :; do
      printf '\nNeovim not found. Install options:\n' >&2
      printf '  1) Package manager — %s\n' "${pkg_version:-version unknown}" >&2
      printf '  2) Build from source (latest stable)\n' >&2
      printf 'Choice [1]: ' >&2
      read -r choice
      case "${choice:-1}" in
      1) core::pkg_install neovim; return ;;
      2) _nvim::install_from_src; return ;;
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
  local repo="git@github.com:yangxingwu/neovim-lua-config.git"
  local branch="LazyVimV2"

  # Back up existing nvim dirs per LazyVim installation guide.
  # https://www.lazyvim.org/installation
  mv ~/.config/nvim{,.bak} 2>/dev/null || true
  mv ~/.local/share/nvim{,.bak} 2>/dev/null || true
  mv ~/.local/state/nvim{,.bak} 2>/dev/null || true
  mv ~/.cache/nvim{,.bak} 2>/dev/null || true

  git clone --branch "${branch}" "${repo}" ~/.config/nvim
  core::log INFO "Cloned neovim config to ~/.config/nvim"
}

install() {
  _nvim::install_deps
  _nvim::install_nvim
  _nvim::clone_config
}

uninstall() {
  # If neovim was built from source, uninstall via make.
  local src_dir="${HOME}/.local/src/neovim"
  if [[ -d "${src_dir}/build" ]]; then
    pushd "${src_dir}" >/dev/null
    sudo make uninstall
    popd >/dev/null
    rm -rf "${src_dir}"
    core::log INFO "Uninstalled source-built Neovim"
  fi

  rm -rf "${HOME}/.config/nvim"
}
