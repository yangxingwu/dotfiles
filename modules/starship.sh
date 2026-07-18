#!/usr/bin/env bash
# modules/starship.sh — Starship prompt (catppuccin theme)
# https://github.com/starship/starship
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="starship"
MODULE_DESC="Starship prompt (catppuccin theme)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")

_STARSHIP_CONFIG="${HOME}/.config/starship.toml"
# Official catppuccin/starship config. Uses macchiato flavor by default; the
# foreground color difference vs mocha is negligible (<5% hex shift per channel)
# and the terminal background is set by Ghostty (mocha), so we use upstream as-is
# with no patching to keep sync trivial.
_STARSHIP_THEME_URL="https://raw.githubusercontent.com/catppuccin/starship/main/starship.toml"

# Install starship via cargo (avoids official curl installer's /usr/local/bin
# assumption which fails on Apple Silicon Macs where that directory doesn't exist).
# Fetch the official catppuccin/starship config and write the zsh init block.
install() {
  if ! core::check_installed starship; then
    core::run_cmd "Installing starship" cargo install --locked starship || return 1
    core::summary "    ✓ installed via cargo"
  else
    core::log INFO "starship already installed"
    core::summary "    ✓ starship already installed"
  fi

  mkdir -p "$(dirname "${_STARSHIP_CONFIG}")"
  core::run_cmd "Fetching catppuccin starship theme" \
    curl -fsSL "${_STARSHIP_THEME_URL}" -o "${_STARSHIP_CONFIG}" || return 1
  core::log INFO "Fetched starship.toml from catppuccin/starship (macchiato)"

  # shellcheck disable=SC2016
  core::ensure_block "${HOME}/.zshrc" "starship" 'eval "$(starship init zsh)"'
  core::summary "    ✓ config → ~/.config/starship.toml (catppuccin macchiato)"
  core::summary "    ✓ config → ~/.zshrc (starship init zsh)"
}

uninstall() {
  rm -f "${_STARSHIP_CONFIG}"
  core::remove_block "${HOME}/.zshrc" "starship"
  core::summary "    ✓ removed ~/.config/starship.toml"
  core::summary "    ✓ removed block from ~/.zshrc"
}
