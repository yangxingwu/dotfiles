#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor configuration (cloned from yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"

# Config lives in a separate repo; post_install clones it and symlinks ~/.config/nvim.
LINKS=()

DEPS_MAC=("neovim")
DEPS_LINUX=("neovim")

readonly _NVIM_REPO="git@github.com:yangxingwu/neovim-lua-config.git"
readonly _NVIM_BRANCH="lazyvimV2"
readonly _NVIM_CLONE_DIR="${HOME}/.local/share/nvim-config"
readonly _NVIM_LINK="${HOME}/.config/nvim"

pre_install() { :; }

post_install() {
  # Clone the config repo if it hasn't been cloned yet.
  if [[ ! -d "${_NVIM_CLONE_DIR}/.git" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would clone ${_NVIM_REPO} (branch ${_NVIM_BRANCH}) → ${_NVIM_CLONE_DIR}"
    else
      git clone --branch "${_NVIM_BRANCH}" "${_NVIM_REPO}" "${_NVIM_CLONE_DIR}"
      core::log INFO "Cloned nvim config → ${_NVIM_CLONE_DIR}"
    fi
  else
    core::log INFO "nvim config repo already present: ${_NVIM_CLONE_DIR}"
  fi

  # Create the symlink ~/.config/nvim → clone dir.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would symlink: ${_NVIM_LINK} → ${_NVIM_CLONE_DIR}"
    return 0
  fi

  # Already correctly linked — nothing to do.
  if [[ -L "${_NVIM_LINK}" ]] \
    && [[ "$(readlink "${_NVIM_LINK}")" == "${_NVIM_CLONE_DIR}" ]]; then
    core::log INFO "Already linked: ${_NVIM_LINK}"
    return 0
  fi

  mkdir -p "$(dirname "${_NVIM_LINK}")"
  ln -sf "${_NVIM_CLONE_DIR}" "${_NVIM_LINK}"
  core::log INFO "Linked: ${_NVIM_LINK} → ${_NVIM_CLONE_DIR}"
}
