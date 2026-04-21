#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor configuration (LazyVim)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor configuration (LazyVim)"
MODULE_PLATFORM="all"

LINKS=(
  "config/nvim:${HOME}/.config/nvim"
)

DEPS_MAC=("neovim")
DEPS_LINUX=("neovim")

pre_install() { :; }

post_install() { :; }
