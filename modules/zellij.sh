#!/usr/bin/env bash
# modules/zellij.sh — Zellij terminal multiplexer (catppuccin theme)
# https://github.com/zellij-org/zellij
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="zellij"
MODULE_DESC="Zellij terminal multiplexer (catppuccin theme)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")

_ZELLIJ_CONFIG_DIR="${HOME}/.config/zellij"
_ZELLIJ_CONFIG="${_ZELLIJ_CONFIG_DIR}/config.kdl"

# Install zellij via cargo and write minimal config with catppuccin-mocha theme.
install() {
  if ! core::check_installed cargo; then
    core::log ERROR "cargo not found — install the rust module first"
    return 1
  fi

  if ! core::check_installed zellij; then
    core::run_cmd "Installing zellij" cargo install --locked zellij || return 1
    core::summary "    ✓ installed via cargo"
  else
    core::log INFO "zellij already installed"
    core::summary "    ✓ zellij already installed"
  fi

  mkdir -p "${_ZELLIJ_CONFIG_DIR}"

  # Only set the theme — all other Zellij defaults (mouse_mode, copy_on_select,
  # pane_frames, simplified_ui) are already what we want out of the box.
  cat >"${_ZELLIJ_CONFIG}" <<'EOF'
// Zellij configuration — managed by dotfiles
// Only the theme needs overriding; everything else uses Zellij's excellent defaults.
// Docs: https://zellij.dev/documentation/options

// Catppuccin Mocha theme (built-in, consistent with other dotfiles modules)
theme "catppuccin-mocha"
EOF

  core::log INFO "Wrote zellij config with catppuccin-mocha theme"
  core::summary "    ✓ config → ~/.config/zellij/config.kdl (catppuccin-mocha)"
}

uninstall() {
  rm -rf "${_ZELLIJ_CONFIG_DIR}"
  core::summary "    ✓ removed ~/.config/zellij/"
}
