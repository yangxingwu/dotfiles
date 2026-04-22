#!/usr/bin/env bash
# modules/ghostty.sh — Ghostty terminal emulator configuration
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="ghostty"
MODULE_DESC="Ghostty terminal emulator configuration"
MODULE_PLATFORM="mac"

LINKS=(
  "config/ghostty/config:${HOME}/.config/ghostty/config"
)

pre_install() { :; }

install() { :; }

post_install() { :; }
