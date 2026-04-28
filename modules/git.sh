#!/usr/bin/env bash
# modules/git.sh — Git configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration"
MODULE_PLATFORM="all"

# git is installed by bootstrap::dev_tools — only config is needed here.
install() {
  git config --global user.name "yangxingwu"
  git config --global user.email "xingwu.yang@gmail.com"
  core::log INFO "Wrote git global config"
}

uninstall() {
  git config --global --unset user.name 2>/dev/null || true
  git config --global --unset user.email 2>/dev/null || true
  core::log INFO "Removed git global config"
}
