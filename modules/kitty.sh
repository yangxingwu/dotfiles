#!/usr/bin/env bash
# modules/kitty.sh — kitty terminal emulator configuration
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="kitty"
MODULE_DESC="kitty terminal emulator configuration"
MODULE_PLATFORM="mac"

LINKS=(
  "config/kitty:${HOME}/.config/kitty"
)

DEPS_MAC=()
DEPS_LINUX=()

pre_install() { :; }

post_install() { :; }
