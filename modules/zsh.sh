#!/usr/bin/env bash
# modules/zsh.sh — Zsh configuration (sheldon plugin manager, starship prompt)
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zsh"
MODULE_DESC="Zsh shell configuration (sheldon plugins, starship prompt)"
MODULE_PLATFORM="all"

# NOTE: .zshrc is managed separately; this module only links plugin/prompt configs.
LINKS=(
  "config/zsh/sheldon/plugins.toml:${HOME}/.config/sheldon/plugins.toml"
  "config/zsh/starship.toml:${HOME}/.config/starship.toml"
)

DEPS_MAC=("sheldon" "starship")
DEPS_LINUX=("zsh" "sheldon" "starship")

pre_install() { :; }

post_install() { :; }
