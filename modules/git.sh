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

pre_install() { :; }

install() {
  core::pkg_install git
}

post_install() {
  # Point git at a shared hooks directory so all repos on this machine
  # pick up the hooks without needing per-repo configuration.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would run: git config --global core.hooksPath ${HOME}/.git-hooks"
    return 0
  fi
  git config --global core.hooksPath "${HOME}/.git-hooks"
  core::log INFO "Set global git hooks path: ${HOME}/.git-hooks"
}
