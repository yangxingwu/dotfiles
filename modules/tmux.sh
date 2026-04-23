#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux configuration (oh-my-tmux base + local overrides)"
MODULE_PLATFORM="all"

# tmux.conf.local is our local override; oh-my-tmux sources it automatically.
# tmux.conf and the upstream clone are created by oh-my-tmux's install.sh.
LINKS=(
  "config/tmux/tmux.conf.local:${HOME}/.config/tmux/tmux.conf.local"
)

readonly _TMUX_INSTALL_URL="https://github.com/gpakosz/.tmux/raw/refs/heads/master/install.sh"
readonly _TMUX_CLONE_DIR="${HOME}/.config/tmux/.tmux"

install() {
  core::pkg_install tmux

  if [[ -d "${_TMUX_CLONE_DIR}/.git" ]]; then
    core::log INFO "oh-my-tmux already present — skipping"
    return 0
  fi

  # Ensure ~/.config/tmux exists so the installer picks the XDG path,
  # not the home-directory fallback.
  mkdir -p "${HOME}/.config/tmux"

  # Official one-liner — clones to ~/.config/tmux/.tmux, creates tmux.conf
  # symlink, and cp's a starter tmux.conf.local.
  curl -fsSL "${_TMUX_INSTALL_URL}" | bash
  core::log INFO "oh-my-tmux installed"

  # Remove upstream's starter tmux.conf.local only if it is a real file
  # (not already our symlink from a prior run), so LINKS can take over
  # without a spurious conflict prompt.
  if [[ -f "${HOME}/.config/tmux/tmux.conf.local" ]] &&
    [[ ! -L "${HOME}/.config/tmux/tmux.conf.local" ]]; then
    rm "${HOME}/.config/tmux/tmux.conf.local"
  fi
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
