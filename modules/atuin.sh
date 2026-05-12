#!/usr/bin/env bash
# modules/atuin.sh — Atuin shell history (replaces history-substring-search)
# https://github.com/atuinsh/atuin
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="atuin"
MODULE_DESC="Atuin shell history with fuzzy search"
MODULE_PLATFORM="all"

_ATUIN_CONFIG="${HOME}/.config/atuin/config.toml"

install() {
  # Install via cargo (same pattern as sheldon).
  if ! core::check_installed atuin; then
    if ! core::check_installed cargo; then
      core::log ERROR "cargo not found — install the rust module first"
      return 1
    fi
    cargo install atuin --locked
    core::log INFO "atuin installed via cargo"
    core::summary "    ✓ installed via cargo"
  else
    core::summary "    ✓ atuin already installed"
  fi

  # Write config (always overwrite — this file is fully managed by dotfiles).
  mkdir -p "$(dirname "${_ATUIN_CONFIG}")"
  cat >"${_ATUIN_CONFIG}" <<'CONFIG'
## Atuin configuration
## See: https://docs.atuin.sh/configuration/config/

# Disable cloud sync — history stays local only.
auto_sync = false
CONFIG
  core::log INFO "Wrote atuin config → ~/.config/atuin/config.toml"
  core::summary "    ✓ config → ~/.config/atuin/config.toml"

  # Content is single-quoted: written literally to .zshrc, expanded by zsh at login.
  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "atuin" \
    'eval "$(atuin init zsh)"'
  core::summary "    ✓ config → ~/.zshrc (atuin init)"
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "atuin"
  core::summary "    ✓ removed atuin block from ~/.zshrc"

  rm -f "${_ATUIN_CONFIG}"
  core::summary "    ✓ removed ~/.config/atuin/config.toml"
}
