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
#
# Both functions return 1 on detection failure. Under strict mode this
# aborts the caller — the intended behaviour, because no downstream step
# (bootstrap::dev_tools, modules) can proceed on an unknown platform or
# unknown package manager. Callers that want to tolerate "none" (e.g.
# uninstall.sh, which only needs DOTFILES_OS) should simply not call
# detect::pkg_manager.
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
# DOTFILES_PKG_MANAGER=brew before calling detect::pkg_manager.
detect::pkg_manager() {
  case "${DOTFILES_OS}" in
  mac)
    if command -v brew >/dev/null 2>&1; then
      export DOTFILES_PKG_MANAGER="brew"
    else
      printf 'error: Homebrew not found on macOS\n' >&2
      return 1
    fi
    ;;
  linux)
    if command -v apt-get >/dev/null 2>&1; then
      export DOTFILES_PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
      export DOTFILES_PKG_MANAGER="dnf"
    else
      printf 'error: no supported package manager found on Linux (supported: apt, dnf)\n' >&2
      return 1
    fi
    ;;
  *)
    printf 'error: detect::pkg_manager called with unknown DOTFILES_OS=%s\n' "${DOTFILES_OS:-<unset>}" >&2
    return 1
    ;;
  esac
}
