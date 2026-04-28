#!/usr/bin/env bash
# modules/starship.sh — Starship prompt (catppuccin-powerline preset)
# Platform: all
# shellcheck disable=SC2034,SC2016  # module interface vars + intentional literal shell expansion in zsh init block
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="starship"
MODULE_DESC="Starship prompt (catppuccin-powerline preset)"
MODULE_PLATFORM="all"

_STARSHIP_PRESET="catppuccin-powerline"

# Installs starship, generates ~/.config/starship.toml from the preset if it
# doesn't exist yet, and writes the zsh init block. Does NOT regenerate an
# existing config — users who've tweaked their prompt keep their tweaks.
install() {
  core::pkg_install starship

  local config="${HOME}/.config/starship.toml"
  if [[ ! -f "${config}" ]]; then
    mkdir -p "$(dirname "${config}")"
    starship preset "${_STARSHIP_PRESET}" --output "${config}"
    core::log INFO "Generated starship.toml from preset ${_STARSHIP_PRESET}"
  fi

  core::ensure_block "${HOME}/.zshrc" "starship" 'eval "$(starship init zsh)"'
}

uninstall() {
  core::remove_block "${HOME}/.zshrc" "starship"
}
