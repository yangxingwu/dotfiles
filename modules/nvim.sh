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
readonly _NVIM_BRANCH="LazyVimV2"
readonly _NVIM_CLONE_DIR_DEFAULT="${HOME}/.local/share/nvim-config"
readonly _NVIM_LINK="${HOME}/.config/nvim"

pre_install() { :; }

post_install() {
  local clone_dir

  # In dry-run mode skip the interactive prompt and use the default path.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    clone_dir="${_NVIM_CLONE_DIR_DEFAULT}"
    core::log DRY "Would clone ${_NVIM_REPO} (branch ${_NVIM_BRANCH}) → ${clone_dir}"
    core::log DRY "Would symlink: ${_NVIM_LINK} → ${clone_dir}"
    return 0
  fi

  # Prompt user for the clone destination; default shown in brackets.
  printf '\nWhere should the nvim config repo be cloned?\n'
  printf '[%s]: ' "${_NVIM_CLONE_DIR_DEFAULT}"
  read -r clone_dir
  # Use default if user pressed Enter without typing anything.
  clone_dir="${clone_dir:-${_NVIM_CLONE_DIR_DEFAULT}}"

  # Clone the config repo if it hasn't been cloned yet.
  if [[ ! -d "${clone_dir}/.git" ]]; then
    git clone --branch "${_NVIM_BRANCH}" "${_NVIM_REPO}" "${clone_dir}"
    core::log INFO "Cloned nvim config → ${clone_dir}"
  else
    core::log INFO "nvim config repo already present: ${clone_dir}"
  fi

  # Already correctly linked — nothing to do.
  if [[ -L "${_NVIM_LINK}" ]] \
    && [[ "$(readlink "${_NVIM_LINK}")" == "${clone_dir}" ]]; then
    core::log INFO "Already linked: ${_NVIM_LINK}"
    return 0
  fi

  mkdir -p "$(dirname "${_NVIM_LINK}")"
  ln -sf "${clone_dir}" "${_NVIM_LINK}"
  core::log INFO "Linked: ${_NVIM_LINK} → ${clone_dir}"
}
