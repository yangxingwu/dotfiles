#!/usr/bin/env bash
# modules/rust.sh — Rust toolchain via rustup
# Platform: all
# shellcheck disable=SC2034  # module interface vars are read by the installer when sourced
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

LINKS=()

pre_install() { :; }

# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present.
install() {
  if command -v rustup &>/dev/null; then
    core::log INFO "rustup already installed — skipping"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would install rustup (stable toolchain)"
    return 0
  fi

  # --no-modify-path: ~/.cargo/env is already sourced via config/zsh/zshenv
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path
  core::log INFO "rustup installed"
}

post_install() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    core::log DRY "Would source ${HOME}/.cargo/env"
    return 0
  fi

  # Make cargo available for the rest of the current install session
  # (e.g. nvim module's tree-sitter-cli step) without requiring a new shell.
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
    core::log INFO "Sourced ~/.cargo/env — rustc $(rustc --version)"
  else
    core::log WARN "${HOME}/.cargo/env not found — cargo may not be on PATH"
  fi
}
