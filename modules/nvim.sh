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

readonly _NVIM_SRC_REPO="https://github.com/neovim/neovim.git"
readonly _NVIM_BUILD_DIR="/tmp/neovim-build-$$"
readonly _NVIM_MIN_MINOR=9
readonly _NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
readonly _NVIM_BRANCH="LazyVimV2"
readonly _NVIM_TARGET="${HOME}/.config/nvim"

# Install all LazyVim runtime dependencies.
pre_install() {
  case "${DOTFILES_OS}" in
    mac) core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
    linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli has no pkg-manager package — install via cargo
  if command -v cargo &>/dev/null; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would run: cargo install --locked tree-sitter-cli"
    else
      cargo install --locked tree-sitter-cli
    fi
  else
    core::log WARN "cargo not found — skipping tree-sitter-cli (run rust module first)"
  fi
}

# Install Neovim itself, with a version check and a pkg/source prompt when needed.
install() {
  local version minor

  # Skip if a sufficiently new Neovim is already present.
  if command -v nvim &>/dev/null; then
    version="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+')"
    minor="${version#*.}"
    if [[ -n "${minor}" ]] && (( minor >= _NVIM_MIN_MINOR )); then
      core::log INFO "Neovim ${version} already installed — skipping"
      return 0
    fi
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Neovim not found (or too old — LazyVim requires >= 0.9)"
    core::log DRY "Would offer: 1) Package manager (brew/apt)  2) Build from source (latest stable tag)"
    return 0
  fi

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
}

# Install Neovim from the system package manager.
_nvim::install_pkg() {
  case "${DOTFILES_OS}" in
    mac) core::pkg_install neovim ;;
    linux) core::pkg_install neovim ;;
  esac
}

# Build and install Neovim from source at the latest stable tag.
_nvim::install_src() {
  # Remove brew-managed neovim on macOS to avoid PATH conflicts with the source build.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    if brew list neovim &>/dev/null 2>&1; then
      brew uninstall neovim
    fi
  fi

  # Install build dependencies.
  case "${DOTFILES_OS}" in
    mac) core::pkg_install ninja cmake gettext curl ;;
    linux) core::pkg_install ninja-build gettext cmake curl build-essential ;;
  esac

  git clone --depth 1 "${_NVIM_SRC_REPO}" "${_NVIM_BUILD_DIR}"

  local latest_tag
  latest_tag="$(cd "${_NVIM_BUILD_DIR}" && git tag --sort=-v:refname | grep -E '^v[0-9]' | head -1)"
  (cd "${_NVIM_BUILD_DIR}" && git checkout "${latest_tag}")
  (cd "${_NVIM_BUILD_DIR}" && make CMAKE_BUILD_TYPE=RelWithDebInfo)
  (cd "${_NVIM_BUILD_DIR}" && sudo make install)

  rm -rf "${_NVIM_BUILD_DIR}"
  core::log INFO "Neovim built and installed from source (${latest_tag})"
}

# Clone the neovim config repo directly to ~/.config/nvim.
post_install() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would clone ${_NVIM_REPO} (branch ${_NVIM_BRANCH}) → ${_NVIM_TARGET}"
    return 0
  fi

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
