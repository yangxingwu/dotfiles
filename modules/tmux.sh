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

  # Official oh-my-tmux installer handles everything: creates dirs, clones
  # the repo, sets up tmux.conf symlink, and copies starter tmux.conf.local.
  curl -fsSL "https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh#$(date +%s)" | bash
  core::log INFO "oh-my-tmux installed"
}

uninstall() {
  rm -rf "${HOME}/.local/share/tmux/oh-my-tmux"
  rm -f "${HOME}/.config/tmux/tmux.conf"
}
