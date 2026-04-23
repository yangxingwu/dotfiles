#!/usr/bin/env bash
# lib/detect.sh — Runtime environment detection.
# Defines detect::os and detect::pkg_manager; callers decide when to invoke
# them (install.sh orchestrates this alongside bootstrap steps). Sourcing
# this file has zero side effects — it only defines functions.
#
# Override knobs:
#   DOTFILES_OS=<mac|linux>
#   DOTFILES_PKG_MANAGER=<brew|apt|dnf>
# Set either variable before calling detect::* to skip detection (e.g.
# linuxbrew users who want brew on Linux: DOTFILES_PKG_MANAGER=brew).
set -euo pipefail
IFS=$'\n\t'

detect::os() {
  case "$(uname -s)" in
  Darwin) export DOTFILES_OS="mac" ;;
  Linux) export DOTFILES_OS="linux" ;;
  *)
    printf 'error: unsupported OS: %s\n' "$(uname -s)" >&2
    return 1
    ;;
  esac
}

# Must be called after detect::os — dispatches by ${DOTFILES_OS} so that a
# Linux machine with linuxbrew installed does not accidentally pick brew over
# the system package manager. Users who want that can set
# DOTFILES_PKG_MANAGER=brew before sourcing.
detect::pkg_manager() {
  case "${DOTFILES_OS}" in
  mac)
    if command -v brew &>/dev/null; then
      export DOTFILES_PKG_MANAGER="brew"
    else
      export DOTFILES_PKG_MANAGER="unknown"
      printf 'warn: Homebrew not found on macOS\n' >&2
    fi
    ;;
  linux)
    if command -v apt-get &>/dev/null; then
      export DOTFILES_PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
      export DOTFILES_PKG_MANAGER="dnf"
    else
      export DOTFILES_PKG_MANAGER="unknown"
      printf 'warn: no supported package manager found on Linux (supported: apt, dnf)\n' >&2
    fi
    ;;
  *)
    export DOTFILES_PKG_MANAGER="unknown"
    ;;
  esac
}
