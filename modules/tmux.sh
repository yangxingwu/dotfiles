#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux configuration (oh-my-tmux)"
MODULE_PLATFORM="all"

_TMUX_INSTALL_URL="https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh"
_TMUX_CLONE_DIR="${HOME}/.config/tmux/.tmux"

install() {
  core::pkg_install tmux

  if [[ -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    core::log INFO "oh-my-tmux already present — skipping"
    return 0
  fi

  # Ensure ~/.config/tmux exists so the installer picks the XDG path,
  # not the home-directory fallback.
  mkdir -p "${HOME}/.config/tmux"

  curl -fsSL "${_TMUX_INSTALL_URL}" | bash
  core::log INFO "oh-my-tmux installed"
}

uninstall() {
  if [[ -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    rm -rf "${_TMUX_CLONE_DIR}"
    core::log INFO "Removed ${_TMUX_CLONE_DIR}"
  fi
  if [[ -L "${HOME}/.config/tmux/tmux.conf" ]]; then
    rm "${HOME}/.config/tmux/tmux.conf"
    core::log INFO "Removed ${HOME}/.config/tmux/tmux.conf"
  fi
}
