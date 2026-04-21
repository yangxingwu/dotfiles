#!/usr/bin/env bash
# lib/detect.sh — Runtime environment detection.
# Detects OS and package manager; exports DOTFILES_OS and DOTFILES_PKG_MANAGER.
# Safe to source multiple times (idempotent variable exports).
set -euo pipefail
IFS=$'\n\t'

detect::os() {
  case "$(uname -s)" in
    Darwin) DOTFILES_OS="mac" ;;
    Linux)  DOTFILES_OS="linux" ;;
    *)
      printf 'error: unsupported OS: %s\n' "$(uname -s)" >&2
      return 1
      ;;
  esac
  export DOTFILES_OS
}

detect::pkg_manager() {
  if command -v brew &>/dev/null; then
    DOTFILES_PKG_MANAGER="brew"
  elif command -v apt-get &>/dev/null; then
    DOTFILES_PKG_MANAGER="apt"
  elif command -v dnf &>/dev/null; then
    DOTFILES_PKG_MANAGER="dnf"
  elif command -v pacman &>/dev/null; then
    DOTFILES_PKG_MANAGER="pacman"
  else
    DOTFILES_PKG_MANAGER="unknown"
    printf 'warn: no supported package manager found\n' >&2
  fi
  export DOTFILES_PKG_MANAGER
}

[[ -n "${DOTFILES_OS:-}" ]] || detect::os
[[ -n "${DOTFILES_PKG_MANAGER:-}" ]] || detect::pkg_manager
export DOTFILES_OS DOTFILES_PKG_MANAGER
