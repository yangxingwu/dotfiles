#!/usr/bin/env bash
# lib/modules.sh — Canonical module list for install.sh and uninstall.sh.
# Single source of truth: add/remove/reorder modules here.
# Order matters — see inline comments for dependency constraints.
set -euo pipefail
IFS=$'\n\t'

DOTFILES_MODULES=(
  font-hack-nerd-font
  git
  rust             # before nvim: cargo is required for tree-sitter-cli
  golang
  fzf              # before zoxide: zi interactive mode uses fzf
                   # before sheldon: sheldon's fzf-tab plugin requires the fzf binary
  zoxide
  sheldon
  starship
  ghostty          # after font/sheldon/zoxide/starship: config assumes these are installed
  nvim             # after rust: builds tree-sitter-cli via cargo
  tmux
)
