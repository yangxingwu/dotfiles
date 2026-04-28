#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor with LazyVim configuration
# https://github.com/neovim/neovim
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor with LazyVim configuration (yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"

_NVIM_SRC_REPO="https://github.com/neovim/neovim.git"
_NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
_NVIM_BRANCH="LazyVimV2"
_NVIM_TARGET="${HOME}/.config/nvim"

install() {
  # 1. LazyVim runtime dependencies
  case "${DOTFILES_OS}" in
  mac) core::pkg_install ripgrep fd lazygit node shfmt shellcheck ;;
  linux) core::pkg_install ripgrep fd-find lazygit nodejs npm shfmt shellcheck ;;
  esac

  # tree-sitter-cli is not in any package manager — install via cargo.
  if core::check_installed cargo; then
    cargo install --locked tree-sitter-cli
  else
    core::log WARN "cargo not found — skipping tree-sitter-cli (run rust module first)"
  fi

  # 2. Neovim itself
  if ! core::check_installed nvim; then
    local choice
    printf '\nNeovim not found. Install options:\n' >&2
    printf '  1) Package manager (brew/apt)\n' >&2
    printf '  2) Build from source (latest stable tag)\n' >&2
    printf 'Choice [1]: ' >&2
    read -r choice
    case "${choice:-1}" in
    1) core::pkg_install neovim ;;
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
    local timestamp backup_path
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_path="${HOME}/.dotfiles-backup/${timestamp}/.config/nvim"
    mkdir -p "$(dirname "${backup_path}")"
    mv "${_NVIM_TARGET}" "${backup_path}"
    core::log INFO "Backed up: ${_NVIM_TARGET} → ${backup_path}"
  fi
  git clone --branch "${_NVIM_BRANCH}" "${_NVIM_REPO}" "${_NVIM_TARGET}"
  core::log INFO "Cloned neovim config to ${_NVIM_TARGET}"
}

uninstall() {
  rm -rf "${_NVIM_TARGET}"
}

# Build and install Neovim from source at the latest stable tag.
_nvim::install_src() {
  local build_dir="/tmp/neovim-build-$$"
  trap 'rm -rf "${build_dir}"' RETURN

  # Remove brew-managed neovim on macOS to avoid PATH conflicts.
  if [[ "${DOTFILES_OS}" == "mac" ]]; then
    if brew list neovim >/dev/null 2>&1; then
      brew uninstall neovim
    fi
  fi

  # Build deps (cmake/ninja/gettext already installed by bootstrap::dev_tools,
  # but curl may be missing on minimal Linux installs).
  case "${DOTFILES_OS}" in
  linux) core::pkg_install curl ;;
  esac

  git clone "${_NVIM_SRC_REPO}" "${build_dir}"

  local latest_tag
  latest_tag="$(cd "${build_dir}" && git tag --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
  if [[ -z "${latest_tag}" ]]; then
    core::log ERROR "No stable release tag found in ${_NVIM_SRC_REPO}"
    return 1
  fi

  pushd "${build_dir}" >/dev/null
  git checkout "${latest_tag}"
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  popd >/dev/null

  core::log INFO "Neovim built and installed from source (${latest_tag})"
}
