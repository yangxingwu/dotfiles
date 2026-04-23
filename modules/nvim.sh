#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor with LazyVim configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor with LazyVim configuration (yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"

LINKS=()

_NVIM_SRC_REPO="https://github.com/neovim/neovim.git"
_NVIM_BUILD_DIR="/tmp/neovim-build-$$"
_NVIM_MIN_MAJOR=0
_NVIM_MIN_MINOR=9
_NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
_NVIM_BRANCH="LazyVimV2"
_NVIM_TARGET="${HOME}/.config/nvim"

install() {
  # 1. LazyVim runtime dependencies
  case "${DOTFILES_OS}" in
  mac) core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
  linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli has no pkg-manager package — install via cargo
  if core::check_installed cargo; then
    cargo install --locked tree-sitter-cli
  else
    core::log WARN "cargo not found — skipping tree-sitter-cli (run rust module first)"
  fi

  # 2. Neovim itself — version check, prompt on miss
  if core::check_installed nvim &&
    core::require_version nvim "${_NVIM_MIN_MAJOR}" "${_NVIM_MIN_MINOR}"; then
    core::log INFO "Neovim >= ${_NVIM_MIN_MAJOR}.${_NVIM_MIN_MINOR} already installed — skipping"
  else
    local choice
    printf '\nNeovim not found (or too old — LazyVim requires >= 0.9)\n'
    printf 'Install options:\n'
    printf '  1) Package manager (brew/apt)\n'
    printf '  2) Build from source (latest stable tag)\n'
    printf 'Choice [1]: '
    read -r choice
    choice="${choice:-1}"
    case "${choice}" in
    1) _nvim::install_pkg ;;
    2) _nvim::install_src ;;
    *) core::log WARN "Unknown choice '${choice}' — skipping Neovim install" ;;
    esac
  fi

  # 3. Clone config repo to ~/.config/nvim
  if [[ -d "${_NVIM_TARGET}/.git" ]]; then
    core::log INFO "Neovim config already cloned — skipping"
    return 0
  fi

  if [[ -L "${_NVIM_TARGET}" ]]; then
    rm "${_NVIM_TARGET}"
    core::log INFO "Removed stale symlink at ${_NVIM_TARGET}"
  elif [[ -d "${_NVIM_TARGET}" ]]; then
    core::backup "${_NVIM_TARGET}"
  fi

  git clone --branch "${_NVIM_BRANCH}" "${_NVIM_REPO}" "${_NVIM_TARGET}"
  core::log INFO "Cloned neovim config to ${_NVIM_TARGET}"
}

uninstall() {
  if [[ -d "${_NVIM_TARGET}/.git" ]]; then
    rm -rf "${_NVIM_TARGET}"
    core::log INFO "Removed ${_NVIM_TARGET}"
  fi
}

# Install Neovim from the system package manager.
_nvim::install_pkg() {
  core::pkg_install neovim
}

# Build and install Neovim from source at the latest stable tag.
_nvim::install_src() {
  # Ensure the build directory is cleaned up on both success and failure.
  trap 'rm -rf "${_NVIM_BUILD_DIR}"' RETURN

  # Remove brew-managed neovim on macOS to avoid PATH conflicts with the source build.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    if core::check_installed brew && brew list neovim &>/dev/null; then
      brew uninstall neovim
    fi
  fi

  case "${DOTFILES_OS}" in
  mac) core::pkg_install ninja cmake gettext curl ;;
  linux) core::pkg_install ninja-build gettext cmake curl build-essential ;;
  esac

  git clone --depth 1 "${_NVIM_SRC_REPO}" "${_NVIM_BUILD_DIR}"

  local latest_tag
  latest_tag="$(cd "${_NVIM_BUILD_DIR}" && git tag --sort=-v:refname |
    { grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true; } | head -1)"
  if [[ -z "${latest_tag}" ]]; then
    core::log ERROR "No stable release tag found in ${_NVIM_SRC_REPO}"
    return 1
  fi
  (cd "${_NVIM_BUILD_DIR}" && git checkout "${latest_tag}")
  (cd "${_NVIM_BUILD_DIR}" && make CMAKE_BUILD_TYPE=RelWithDebInfo)
  (cd "${_NVIM_BUILD_DIR}" && sudo make install)

  core::log INFO "Neovim built and installed from source (${latest_tag})"
}
