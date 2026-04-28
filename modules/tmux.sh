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

  # oh-my-tmux official one-liner: clones to ~/.config/tmux/.tmux,
  # creates tmux.conf symlink, and copies a starter tmux.conf.local.
  mkdir -p "${HOME}/.config/tmux"
  curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash
  core::log INFO "oh-my-tmux installed"
}

uninstall() {
  rm -rf "${HOME}/.config/tmux/.tmux"
  rm -f "${HOME}/.config/tmux/tmux.conf"
}
