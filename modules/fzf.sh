#!/usr/bin/env bash
# modules/fzf.sh — fzf fuzzy finder with zsh key bindings
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
# shellcheck disable=SC2016  # single quotes on the block body are intentional — written literally to ~/.zshrc
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="fzf"
MODULE_DESC="fzf fuzzy finder with zsh key bindings"
MODULE_PLATFORM="all"

LINKS=()

# Installs the fzf package and writes the zsh integration block to ~/.zshrc.
# The `eval "$(fzf --zsh)"` line enables Ctrl+R (history search) and Ctrl+T
# (file search) key bindings. It must run after `sheldon source` when both
# are present (sheldon's fzf-tab plugin integrates with fzf) — install order
# in _MODULES puts fzf before sheldon so the fzf binary is on PATH when
# sheldon loads, but the init block order is determined by module run order,
# which places the fzf block before the sheldon block in ~/.zshrc. Both
# orders work: fzf's --zsh emits a self-contained init that doesn't depend
# on sheldon, and sheldon's fzf-tab loads later, picking up fzf already set.
install() {
  core::pkg_install fzf
  core::ensure_block "${HOME}/.zshrc" "fzf" 'eval "$(fzf --zsh)"'
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "fzf"
}
