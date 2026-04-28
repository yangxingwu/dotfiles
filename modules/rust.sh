#!/usr/bin/env bash
# modules/rust.sh — Rust toolchain via rustup
# Platform: all
# shellcheck disable=SC2034,SC2016  # module interface vars + intentional literal shell expansion in zprofile block
set -euo pipefail
IFS=$'\n\t'

MODULE_NAME="rust"
MODULE_DESC="Rust toolchain via rustup"
MODULE_PLATFORM="all"

# Installs the Rust stable toolchain via the official rustup script.
# Idempotent: skips if rustup is already present. After install (or skip),
# sources ~/.cargo/env so later modules (nvim → tree-sitter-cli) can see cargo,
# and writes a "rust" block to ~/.zprofile so future shells pick up cargo too.
install() {
  if core::check_installed rustup; then
    core::log INFO "rustup already installed — skipping"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    core::log INFO "rustup installed"
  fi

  if [[ ! -f "${HOME}/.cargo/env" ]]; then
    core::log ERROR "${HOME}/.cargo/env not found — rustup install may have failed"
    return 1
  fi

  # Activate cargo for the rest of this install run.
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"

  # Persist for future login shells.
  core::ensure_block "${HOME}/.zprofile" "rust" \
    '. "${HOME}/.cargo/env"'
}

uninstall() {
  core::remove_block "${HOME}/.zprofile" "rust"
}
