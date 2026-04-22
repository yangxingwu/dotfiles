#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux configuration (oh-my-tmux base + local overrides)"
MODULE_PLATFORM="all"

# oh-my-tmux is cloned by post_install; only the local override file is symlinked.
LINKS=(
  "config/tmux/tmux.conf.local:${HOME}/.config/tmux/tmux.conf.local"
)

readonly _TMUX_REPO="https://github.com/gpakosz/.tmux.git"
readonly _TMUX_CLONE_DIR="${HOME}/.local/share/tmux/oh-my-tmux"
readonly _TMUX_LINK="${HOME}/.config/tmux/tmux.conf"

pre_install() { :; }

install() {
  core::pkg_install tmux
}

post_install() {
  # Clone oh-my-tmux if not already present.
  if [[ ! -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      core::log DRY "Would clone ${_TMUX_REPO} → ${_TMUX_CLONE_DIR}"
    else
      git clone --depth 1 "${_TMUX_REPO}" "${_TMUX_CLONE_DIR}"
      core::log INFO "Cloned oh-my-tmux → ${_TMUX_CLONE_DIR}"
    fi
  else
    core::log INFO "oh-my-tmux already present: ${_TMUX_CLONE_DIR}"
  fi

  # Symlink ~/.config/tmux/tmux.conf → oh-my-tmux's .tmux.conf.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would symlink: ${_TMUX_LINK} → ${_TMUX_CLONE_DIR}/.tmux.conf"
    return 0
  fi

  if [[ -L "${_TMUX_LINK}" ]] \
    && [[ "$(readlink "${_TMUX_LINK}")" == "${_TMUX_CLONE_DIR}/.tmux.conf" ]]; then
    core::log INFO "Already linked: ${_TMUX_LINK}"
    return 0
  fi

  mkdir -p "$(dirname "${_TMUX_LINK}")"
  ln -sf "${_TMUX_CLONE_DIR}/.tmux.conf" "${_TMUX_LINK}"
  core::log INFO "Linked: ${_TMUX_LINK} → ${_TMUX_CLONE_DIR}/.tmux.conf"
}
