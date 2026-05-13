#!/usr/bin/env bash
# modules/fzf.sh — fzf fuzzy finder with zsh key bindings
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with zsh key bindings"
MODULE_PLATFORM="all"

# Installs fzf and writes the zsh integration block to ~/.zshrc.
# fzf must be installed before sheldon (sheldon's fzf-tab plugin needs the binary).
install() {
  core::run_cmd "Installing fzf" core::pkg_install fzf
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "fzf" 'eval "$(fzf --zsh)"'
  core::summary "    ✓ config → ~/.zshrc (fzf --zsh)"
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
  core::summary "    ✓ removed block from ~/.zshrc"
}
