#!/usr/bin/env bash
# modules/zoxide.sh — zoxide smarter cd command
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zoxide"
MODULE_DESC="zoxide smarter cd command"
MODULE_PLATFORM="all"

# Installs zoxide and writes the zsh init block to ~/.zshrc.
# `eval "$(zoxide init zsh)"` defines the `z` and `zi` shell functions.
install() {
  core::pkg_install zoxide || return 1
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "zoxide" 'eval "$(zoxide init zsh)"'
  core::summary "    ✓ config → ~/.zshrc (zoxide init zsh)"
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "zoxide"
  core::summary "    ✓ removed block from ~/.zshrc"
}
