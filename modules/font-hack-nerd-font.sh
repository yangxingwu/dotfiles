#!/usr/bin/env bash
# modules/font-hack-nerd-font.sh — Hack Nerd Font installation (Homebrew cask)
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="font-hack-nerd-font"
MODULE_DESC="Hack Nerd Font (patched with Nerd Font icons)"
MODULE_PLATFORM="mac"

# Hack Nerd Font is a Homebrew cask — core::pkg_install handles cask detection
# transparently (brew list --cask / brew install).
install() {
  core::pkg_install font-hack-nerd-font || return 1
}

uninstall() {
  core::summary "    — no-op (font not managed by uninstall)"
}
