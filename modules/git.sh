#!/usr/bin/env bash
# modules/git.sh — Git configuration and global hooks
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration and global hooks"
MODULE_PLATFORM="all"

LINKS=(
  "config/git/gitconfig:${HOME}/.gitconfig"
  "config/git/git-hooks:${HOME}/.git-hooks"
)

install() {
  core::pkg_install git
}

uninstall() { :; }
