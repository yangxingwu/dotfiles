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
  core::pkg_install tmux || return 1

  # Manual installation per oh-my-tmux README.md
  # (section: "Manual installation `~/.config/tmux`")
  local clone_dir="${HOME}/.local/share/tmux/oh-my-tmux"
  local config_dir="${HOME}/.config/tmux"

  if [[ -d "${clone_dir}" ]]; then
    core::run_cmd "Updating oh-my-tmux" git -C "${clone_dir}" pull --quiet || return 1
  else
    core::run_cmd "Cloning oh-my-tmux" git clone --single-branch https://github.com/gpakosz/.tmux.git "${clone_dir}" || return 1
  fi

  mkdir -p "${config_dir}"
  ln -sf "${clone_dir}/.tmux.conf" "${config_dir}/tmux.conf"
  core::log INFO "Linked tmux.conf → ${clone_dir}/.tmux.conf"

  if [[ ! -f "${config_dir}/tmux.conf.local" ]]; then
    cp "${clone_dir}/.tmux.conf.local" "${config_dir}/tmux.conf.local"
    core::log INFO "Copied tmux.conf.local template"
    core::summary "    ✓ config → ~/.config/tmux/tmux.conf.local (copied)"
  else
    core::log INFO "tmux.conf.local already exists — skipping (user customizations preserved)"
    core::summary "    ✓ config → ~/.config/tmux/tmux.conf.local (kept existing)"
  fi

  core::summary "    ✓ oh-my-tmux → ~/.local/share/tmux/oh-my-tmux"
  core::summary "    ✓ config → ~/.config/tmux/tmux.conf (symlink)"
}

# Reverse of install: remove clone, unlink symlink, remove local config.
uninstall() {
  rm -rf "${HOME}/.local/share/tmux/oh-my-tmux"
  [[ -L "${HOME}/.config/tmux/tmux.conf" ]] && unlink "${HOME}/.config/tmux/tmux.conf"
  rm -f "${HOME}/.config/tmux/tmux.conf.local"
  core::summary "    ✓ removed oh-my-tmux clone"
  core::summary "    ✓ unlinked ~/.config/tmux/tmux.conf"
  core::summary "    ✓ removed ~/.config/tmux/tmux.conf.local"
}
