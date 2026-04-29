#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer with oh-my-tmux
# https://github.com/gpakosz/.tmux
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux configuration (oh-my-tmux)"
MODULE_PLATFORM="all"

install() {
  core::pkg_install tmux

  # Official oh-my-tmux installer (see install.sh in the repo):
  #   1. Clones the repo to ~/.local/share/tmux/oh-my-tmux
  #   2. Creates symlink ~/.config/tmux/tmux.conf → the clone's .tmux.conf
  #   3. Copies a starter tmux.conf.local to ~/.config/tmux/
  # Download then execute (not pipe) to avoid the interactive "STOP" prompt.
  local installer="/tmp/oh-my-tmux-install.sh"
  curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" -o "${installer}"
  bash "${installer}"
  rm -f "${installer}"
  core::log INFO "oh-my-tmux installed"
  core::summary "    ✓ installed via ${DOTFILES_PKG_MANAGER}"
  core::summary "    ✓ oh-my-tmux installed"
}

# Reverse of install: remove clone, unlink symlink, remove local config.
uninstall() {
  rm -rf "${HOME}/.local/share/tmux/oh-my-tmux"
  unlink "${HOME}/.config/tmux/tmux.conf"
  rm -f "${HOME}/.config/tmux/tmux.conf.local"
  core::summary "    ✓ removed oh-my-tmux clone"
  core::summary "    ✓ unlinked ~/.config/tmux/tmux.conf"
  core::summary "    ✓ removed ~/.config/tmux/tmux.conf.local"
}
