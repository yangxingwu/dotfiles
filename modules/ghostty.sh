#!/usr/bin/env bash
# modules/ghostty.sh — Ghostty terminal emulator
# https://ghostty.org
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ghostty"
MODULE_DESC="Ghostty terminal emulator"
MODULE_PLATFORM="mac"

_GHOSTTY_CONFIG="${HOME}/.config/ghostty/config"

install() {
  core::pkg_install ghostty

  mkdir -p "$(dirname "${_GHOSTTY_CONFIG}")"
  cat >"${_GHOSTTY_CONFIG}" <<'CONF'
theme = Catppuccin Mocha
font-family = "Hack Nerd Font Mono"
font-size = "15"
macos-option-as-alt = true
CONF
  core::log INFO "Wrote Ghostty config"
  core::summary "    ✓ installed via brew"
  core::summary "    ✓ config → ~/.config/ghostty/config"
}

uninstall() {
  rm -f "${_GHOSTTY_CONFIG}"
  core::summary "    ✓ removed ~/.config/ghostty/config"
}
