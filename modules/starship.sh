#!/usr/bin/env bash
# modules/starship.sh — Starship prompt (catppuccin-powerline preset)
# https://github.com/starship/starship
# Platform: all
# shellcheck disable=SC2034,SC2016  # module interface vars + intentional literal shell expansion in zsh init block
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="starship"
MODULE_DESC="Starship prompt (catppuccin-powerline preset)"
MODULE_PLATFORM="all"

_STARSHIP_PRESET="catppuccin-powerline"
_STARSHIP_CONFIG="${HOME}/.config/starship.toml"

# Install starship via the official installer (works on both macOS and Linux).
# Generate starship.toml from the preset and write the zsh init block.
install() {
  if ! core::check_installed starship; then
    curl -sS https://starship.rs/install.sh | sh
    core::log INFO "starship installed"
    core::summary "    ✓ installed via curl (official installer)"
  else
    core::summary "    ✓ starship already installed"
  fi

  mkdir -p "$(dirname "${_STARSHIP_CONFIG}")"
  starship preset "${_STARSHIP_PRESET}" --output "${_STARSHIP_CONFIG}"
  core::log INFO "Generated starship.toml from preset ${_STARSHIP_PRESET}"

  core::ensure_block "${HOME}/.zshrc" "starship" 'eval "$(starship init zsh)"'
  core::summary "    ✓ config → ~/.config/starship.toml (${_STARSHIP_PRESET})"
  core::summary "    ✓ config → ~/.zshrc (starship init zsh)"
}

uninstall() {
  rm -f "${_STARSHIP_CONFIG}"
  core::remove_block "${HOME}/.zshrc" "starship"
  core::summary "    ✓ removed ~/.config/starship.toml"
  core::summary "    ✓ removed block from ~/.zshrc"
}
