#!/usr/bin/env bash
# modules/tmux.sh — tmux terminal multiplexer configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="tmux"
MODULE_DESC="tmux terminal multiplexer configuration"
MODULE_PLATFORM="all"

LINKS=(
  "config/tmux/tmux.conf:${HOME}/.config/tmux/tmux.conf"
  "config/tmux/tmux.conf.local:${HOME}/.config/tmux/tmux.conf.local"
)

DEPS_MAC=("tmux")
DEPS_LINUX=("tmux")

pre_install() { :; }

post_install() { :; }
