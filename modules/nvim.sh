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

# Install LazyVim runtime dependencies.
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

# Build and install Neovim from source at the latest stable tag.
_nvim::install_from_src() {
  local build_dir="/tmp/neovim-build-$$"
  local src_repo="https://github.com/neovim/neovim.git"
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

  git clone "${src_repo}" "${build_dir}"

  local latest_tag
  latest_tag="$(cd "${build_dir}" && git tag --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
  if [[ -z "${latest_tag}" ]]; then
    core::log ERROR "No stable release tag found in ${src_repo}"
    return 1
  fi

  pushd "${build_dir}" >/dev/null
  git checkout "${latest_tag}"
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  sudo make install
  popd >/dev/null

  core::log INFO "Neovim built and installed from source (${latest_tag})"
}

# Prompt the user to install Neovim via package manager or from source.
# Loops until a valid choice is made.
_nvim::install_nvim() {
  if core::check_installed nvim; then
    core::log INFO "Neovim already installed: $(nvim --version | head -1)"
    return 0
  fi

  local choice
  while :; do
    printf '\nNeovim not found. Install options:\n' >&2
    printf '  1) Package manager (brew/apt)\n' >&2
    printf '  2) Build from source (latest stable tag)\n' >&2
    printf 'Choice [1]: ' >&2
    read -r choice
    case "${choice:-1}" in
    1) core::pkg_install neovim; return ;;
    2) _nvim::install_from_src; return ;;
    *) core::log WARN "Invalid choice: ${choice}" ;;
    esac
  done
}

# Clone the LazyVim config repo to ~/.config/nvim.
# Backs up any existing non-git directory; removes stale symlinks.
_nvim::clone_config() {
  local repo="git@github.com:yangxingwu/neovim-lua-config.git"
  local branch="LazyVimV2"
  local target="${HOME}/.config/nvim"

  if [[ -d "${target}/.git" ]]; then
    core::log INFO "Neovim config already cloned — skipping"
    return 0
  fi
  if [[ -L "${target}" ]]; then
    rm "${target}"
    core::log INFO "Removed stale symlink at ${target}"
  elif [[ -d "${target}" ]]; then
    local timestamp backup_path
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_path="${HOME}/.dotfiles-backup/${timestamp}/.config/nvim"
    mkdir -p "$(dirname "${backup_path}")"
    mv "${target}" "${backup_path}"
    core::log INFO "Backed up: ${target} → ${backup_path}"
  fi

  git clone --branch "${branch}" "${repo}" "${target}"
  core::log INFO "Cloned neovim config to ${target}"
}

install() {
  _nvim::install_deps
  _nvim::install_nvim
  _nvim::clone_config
}

uninstall() {
  rm -rf "${HOME}/.config/nvim"
}
