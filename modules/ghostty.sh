#!/usr/bin/env bash
# modules/ghostty.sh — Ghostty terminal emulator configuration
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ghostty"
MODULE_DESC="Ghostty terminal emulator configuration"
MODULE_PLATFORM="mac"

_GHOSTTY_CONFIG="${HOME}/.config/ghostty/config"

install() {
  mkdir -p "$(dirname "${_GHOSTTY_CONFIG}")"
  cat >"${_GHOSTTY_CONFIG}" <<'CONF'
theme = Catppuccin Mocha
font-family = "Hack Nerd Font Mono"
font-size = "15"
macos-option-as-alt = true
CONF
  core::log INFO "Wrote Ghostty config"
}

uninstall() {
  if [[ -f "${_GHOSTTY_CONFIG}" ]]; then
    rm "${_GHOSTTY_CONFIG}"
    core::log INFO "Removed ${_GHOSTTY_CONFIG}"
  fi
}
