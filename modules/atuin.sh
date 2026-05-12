#!/usr/bin/env bash
# modules/atuin.sh — Atuin shell history (replaces history-substring-search)
# https://github.com/atuinsh/atuin
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
# shellcheck disable=SC2088  # tildes in log strings are intentional (display only)
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

  # Write config (disable cloud sync).
  mkdir -p "$(dirname "${_ATUIN_CONFIG}")"
  if [[ ! -f "${_ATUIN_CONFIG}" ]]; then
    cat >"${_ATUIN_CONFIG}" <<'CONFIG'
## Atuin configuration
## See: https://docs.atuin.sh/configuration/config/

# Disable cloud sync — history stays local only.
auto_sync = false
CONFIG
    core::log INFO "Wrote atuin config (sync disabled)"
    core::summary "    ✓ config → ~/.config/atuin/config.toml"
  else
    core::log INFO "~/.config/atuin/config.toml already exists — skipping"
    core::summary "    ✓ config already exists (not overwritten)"
  fi

  # Add init to .zshrc via managed block.
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
