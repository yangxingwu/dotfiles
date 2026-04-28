#!/usr/bin/env bash
# modules/git.sh — Git configuration
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="git"
MODULE_DESC="Git configuration"
MODULE_PLATFORM="all"

install() {
  core::pkg_install git
  git config --global core.quotepath false
  git config --global user.name "yangxingwu"
  git config --global user.email "xingwu.yang@gmail.com"
  core::log INFO "Wrote git global config"
}

uninstall() { :; }
