#!/usr/bin/env bash
# modules/cli-tools.sh — Modern CLI replacements
# Platform: all
#
# Installed tools:
#   bat       — cat replacement with syntax highlighting (Rust)
#   eza       — ls replacement with git integration (Rust)
#   ripgrep   — grep replacement, fast (Rust)
#   fd-find   — find replacement, user-friendly syntax (Rust)
#   jq        — JSON processor (C; installed via package manager)
#   tealdeer  — tldr client, concise command examples (Rust)
#
# Optional tools NOT installed by this module (install manually if desired):
#   dust      — du replacement, tree visualization — cargo install du-dust
#   duf       — df replacement, colored table output — available in brew/apt/dnf
#   hyperfine — command benchmarking — cargo install hyperfine
#   yazi      — terminal file manager — cargo install yazi-fm yazi-cli
#   btop      — htop replacement, system monitor — available in brew/apt/dnf
#   tokei     — code line counter — cargo install tokei
#   procs     — ps replacement — cargo install procs
#   bandwhich — network bandwidth monitor — cargo install bandwhich
#   bottom    — system monitor TUI — cargo install bottom
#
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="cli-tools"
MODULE_DESC="Modern CLI replacements (bat, eza, rg, fd, jq, tldr)"
MODULE_PLATFORM="all"
MODULE_DEPS=("rust")

_CLI_BAT_THEME="Catppuccin Mocha"
# Parallel arrays: crate name → binary name. Used by install (cargo install)
# and uninstall (retained-binaries notice).
_CLI_CARGO_CRATES=("bat" "eza" "ripgrep" "fd-find" "tealdeer")
_CLI_CARGO_BINARIES=("bat" "eza" "rg" "fd" "tldr")
# Tools installed via package manager (not cargo).
_CLI_PKG_TOOLS=("jq")

# Install Rust-based CLI tools via cargo.
_cli::install_cargo_tools() {
  local i

  for i in "${!_CLI_CARGO_CRATES[@]}"; do
    if core::check_installed "${_CLI_CARGO_BINARIES[${i}]}"; then
      core::log INFO "Already installed: ${_CLI_CARGO_BINARIES[${i}]}"
      core::summary "    ✓ ${_CLI_CARGO_BINARIES[${i}]} already installed"
    else
      core::run_cmd "Installing ${_CLI_CARGO_CRATES[${i}]}" cargo install "${_CLI_CARGO_CRATES[${i}]}" || return 1
      core::summary "    ✓ ${_CLI_CARGO_BINARIES[${i}]} installed via cargo"
    fi
  done
}

# Install tools that are not available via cargo.
_cli::install_pkg_tools() {
  core::run_cmd "Installing ${_CLI_PKG_TOOLS[*]}" core::pkg_install "${_CLI_PKG_TOOLS[@]}" || return 1
}

# Write bat config file with catppuccin-mocha theme (built-in since bat 0.25+).
_cli::configure_bat() {
  local config_dir
  config_dir="$(bat --config-dir)"
  local config_file="${config_dir}/config"

  mkdir -p "${config_dir}"
  printf '%s\n' "--theme=\"${_CLI_BAT_THEME}\"" >"${config_file}"
  core::log INFO "Wrote bat config: ${config_file}"
  core::summary "    ✓ bat config → ${config_file} (${_CLI_BAT_THEME})"
}

# Populate tealdeer page cache for offline usage.
_cli::update_tealdeer_cache() {
  if tldr --update >/dev/null 2>&1; then
    core::log INFO "Updated tealdeer page cache"
    core::summary "    ✓ tealdeer cache updated"
  else
    core::log WARN "Failed to update tealdeer cache (network issue?) — skipping"
    core::summary "    — tealdeer cache update skipped (network)"
  fi
}

install() {
  _cli::install_cargo_tools || return 1
  _cli::install_pkg_tools || return 1
  _cli::configure_bat || return 1
  _cli::update_tealdeer_cache || return 1
}

uninstall() {
  local config_dir
  config_dir="$(bat --config-dir 2>/dev/null)" || config_dir="${HOME}/.config/bat"

  rm -f "${config_dir}/config"
  core::log INFO "Removed bat config"
  core::summary "    ✓ removed bat config"

  # Intentionally NOT removed: binaries installed by this module.
  # Other tools may depend on them; remove manually if needed.
  local retained
  retained="$(printf '%s, ' "${_CLI_CARGO_BINARIES[@]}" "${_CLI_PKG_TOOLS[@]}")"
  retained="${retained%, }"
  core::log INFO "Retained binaries: ${retained}"
  core::summary "    — retained binaries: ${retained}"
}
