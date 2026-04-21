#!/usr/bin/env bash
# modules/nvim.sh — Neovim editor configuration (LazyVim)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="nvim"
MODULE_DESC="Neovim editor (config managed separately at yangxingwu/neovim-lua-config)"
MODULE_PLATFORM="all"

# Config is maintained in a separate repo: git@github.com:yangxingwu/neovim-lua-config.git
# This module only installs the neovim package; no symlinks are managed here.
LINKS=()

DEPS_MAC=("neovim")
DEPS_LINUX=("neovim")

pre_install() { :; }

post_install() { :; }
