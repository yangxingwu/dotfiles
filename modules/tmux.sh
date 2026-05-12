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
  core::run_cmd "Installing tmux" core::pkg_install tmux

  # Manual installation per oh-my-tmux README.md
  # (section: "Manual installation `~/.config/tmux`")
  local clone_dir="${HOME}/.local/share/tmux/oh-my-tmux"
  local config_dir="${HOME}/.config/tmux"

  core::run_cmd "Cloning oh-my-tmux" git clone --single-branch https://github.com/gpakosz/.tmux.git "${clone_dir}"
  mkdir -p "${config_dir}"
  ln -s "${clone_dir}/.tmux.conf" "${config_dir}/tmux.conf"
  cp "${clone_dir}/.tmux.conf.local" "${config_dir}/tmux.conf.local"

  core::log INFO "oh-my-tmux installed"
  core::summary "    ✓ oh-my-tmux cloned to ~/.local/share/tmux/oh-my-tmux"
  core::summary "    ✓ config → ~/.config/tmux/tmux.conf (symlink)"
  core::summary "    ✓ config → ~/.config/tmux/tmux.conf.local (copied)"
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
