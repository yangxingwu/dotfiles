#!/usr/bin/env bash
# modules/homebrew.sh — Homebrew shell environment (.zprofile block)
# Platform: mac
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="homebrew"
MODULE_DESC="Homebrew shell environment"
MODULE_PLATFORM="mac"

install() {
  local brew_prefix
  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_prefix=/opt/homebrew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_prefix=/usr/local
  else
    core::log ERROR "brew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
    return 1
  fi

  # Activate for the rest of this install run.
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  # Persist for future login shells.
  core::ensure_block "${HOME}/.zprofile" "homebrew" \
    "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
  core::summary "    ✓ config → ~/.zprofile (brew shellenv)"
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "homebrew"
  core::summary "    ✓ removed homebrew block from ~/.zprofile"
}
